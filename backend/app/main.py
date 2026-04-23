"""FastAPI application entrypoint."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from copy import deepcopy

from sqlalchemy import func, text

from app.database import Base, engine
from app.routers import (
    ai,
    api_tokens,
    auth,
    chat,
    checklists,
    comments,
    github,
    meeting_minutes,
    user_github_tokens,
    user_mattermost_settings,
    patches,
    project_sites,
    request_issue,
    site_details,
    notifications,
    projects,
    search,
    sprints,
    tasks,
    uploads,
    users,
    websocket,
    workspaces,
)

# Create all tables for fresh environments.
Base.metadata.create_all(bind=engine)


def ensure_image_urls_column() -> None:
    """Add comments.image_urls column if missing."""
    try:
        conn = engine.connect()
        try:
            result = conn.execute(
                text(
                    """
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_name='comments' AND column_name='image_urls'
                    """
                )
            )
            if result.fetchone() is None:
                conn.execute(
                    text(
                        """
                        ALTER TABLE comments
                        ADD COLUMN image_urls VARCHAR[] DEFAULT '{}' NOT NULL
                        """
                    )
                )
                conn.commit()
                print("[main] added comments.image_urls column")
            else:
                print("[main] comments.image_urls column already exists")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure comments.image_urls: {e}")


ensure_image_urls_column()


def ensure_tasks_site_tags_column() -> None:
    """Add tasks.site_tags column if missing."""
    try:
        conn = engine.connect()
        try:
            result = conn.execute(
                text(
                    """
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_name='tasks' AND column_name='site_tags'
                    """
                )
            )
            if result.fetchone() is None:
                conn.execute(
                    text(
                        """
                        ALTER TABLE tasks
                        ADD COLUMN site_tags VARCHAR[] DEFAULT '{}' NOT NULL
                        """
                    )
                )
                conn.commit()
                print("[main] added tasks.site_tags column")
            else:
                print("[main] tasks.site_tags column already exists")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure tasks.site_tags: {e}")


ensure_tasks_site_tags_column()


def ensure_notification_cascades() -> None:
    """notifications 테이블 FK에 ON DELETE CASCADE 적용 (기존 DB 마이그레이션)."""
    fk_targets = [
        ("notifications_user_id_fkey", "user_id", "users", "id"),
        ("notifications_project_id_fkey", "project_id", "projects", "id"),
        ("notifications_task_id_fkey", "task_id", "tasks", "id"),
        ("notifications_comment_id_fkey", "comment_id", "comments", "id"),
    ]
    try:
        conn = engine.connect()
        try:
            for constraint_name, col, ref_table, ref_col in fk_targets:
                # 이미 CASCADE인지 확인
                result = conn.execute(text("""
                    SELECT rc.delete_rule
                    FROM information_schema.referential_constraints rc
                    JOIN information_schema.key_column_usage kcu
                      ON kcu.constraint_name = rc.constraint_name
                    WHERE kcu.table_name = 'notifications'
                      AND kcu.column_name = :col
                """), {"col": col})
                row = result.fetchone()
                if row and row[0] == "CASCADE":
                    continue
                # CASCADE 아니면 재생성
                conn.execute(text(f"ALTER TABLE notifications DROP CONSTRAINT IF EXISTS {constraint_name}"))
                nullable = "NOT NULL" if col == "user_id" else ""
                conn.execute(text(
                    f"ALTER TABLE notifications ADD CONSTRAINT {constraint_name} "
                    f"FOREIGN KEY ({col}) REFERENCES {ref_table}({ref_col}) ON DELETE CASCADE"
                ))
            conn.commit()
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure notification cascades: {e}")


ensure_notification_cascades()


def ensure_checklist_tables() -> None:
    """checklists, checklist_items 테이블이 없으면 생성 (기존 DB 마이그레이션)."""
    try:
        conn = engine.connect()
        try:
            # checklists 테이블
            result = conn.execute(text("SELECT to_regclass('public.checklists')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE checklists (
                        id VARCHAR PRIMARY KEY,
                        task_id VARCHAR NOT NULL,
                        title VARCHAR NOT NULL DEFAULT 'Checklist',
                        created_by VARCHAR NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_checklists_task_id ON checklists(task_id)"))
                conn.execute(text("CREATE INDEX ix_checklists_id ON checklists(id)"))
                print("[main] created checklists table")

            # checklist_items 테이블
            result = conn.execute(text("SELECT to_regclass('public.checklist_items')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE checklist_items (
                        id VARCHAR PRIMARY KEY,
                        checklist_id VARCHAR NOT NULL,
                        task_id VARCHAR NOT NULL,
                        content VARCHAR NOT NULL,
                        is_checked BOOLEAN NOT NULL DEFAULT FALSE,
                        assignee_id VARCHAR,
                        due_date TIMESTAMPTZ,
                        display_order INTEGER NOT NULL DEFAULT 0,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_checklist_items_checklist_id ON checklist_items(checklist_id)"))
                conn.execute(text("CREATE INDEX ix_checklist_items_id ON checklist_items(id)"))
                print("[main] created checklist_items table")

            conn.commit()
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure checklist tables: {e}")


ensure_checklist_tables()


def ensure_project_github_table() -> None:
    """project_github 테이블이 없으면 생성 (GitHub 연동)."""
    try:
        conn = engine.connect()
        try:
            result = conn.execute(text("SELECT to_regclass('public.project_github')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE project_github (
                        id VARCHAR PRIMARY KEY,
                        project_id VARCHAR NOT NULL UNIQUE,
                        repo_owner VARCHAR NOT NULL,
                        repo_name VARCHAR NOT NULL,
                        access_token VARCHAR,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_project_github_project_id ON project_github(project_id)"))
                conn.execute(text("CREATE INDEX ix_project_github_id ON project_github(id)"))
                conn.commit()
                print("[main] created project_github table")
            else:
                print("[main] project_github table already exists")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure project_github table: {e}")


ensure_project_github_table()


def ensure_user_github_tokens_table() -> None:
    """user_github_tokens 테이블이 없으면 생성 (계정 단위 GitHub PAT)."""
    try:
        conn = engine.connect()
        try:
            result = conn.execute(text("SELECT to_regclass('public.user_github_tokens')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE user_github_tokens (
                        id VARCHAR PRIMARY KEY,
                        user_id VARCHAR NOT NULL UNIQUE,
                        access_token VARCHAR NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_user_github_tokens_user_id ON user_github_tokens(user_id)"))
                conn.execute(text("CREATE INDEX ix_user_github_tokens_id ON user_github_tokens(id)"))
                conn.commit()
                print("[main] created user_github_tokens table")
            else:
                print("[main] user_github_tokens table already exists")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure user_github_tokens table: {e}")


ensure_user_github_tokens_table()


def ensure_user_mattermost_settings_table() -> None:
    """user_mattermost_settings 테이블이 없으면 생성, 있으면 컬럼 추가."""
    try:
        conn = engine.connect()
        try:
            result = conn.execute(text("SELECT to_regclass('public.user_mattermost_settings')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE user_mattermost_settings (
                        id VARCHAR PRIMARY KEY,
                        user_id VARCHAR NOT NULL UNIQUE,
                        mattermost_username VARCHAR,
                        webhook_url VARCHAR,
                        is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_user_mattermost_settings_user_id ON user_mattermost_settings(user_id)"))
                conn.commit()
                print("[main] created user_mattermost_settings table")
            else:
                # mattermost_username 컬럼 추가 (신규 DM 방식)
                conn.execute(text("""
                    ALTER TABLE user_mattermost_settings
                    ADD COLUMN IF NOT EXISTS mattermost_username VARCHAR
                """))
                # webhook_url NOT NULL → NULL 허용으로 완화
                conn.execute(text("""
                    ALTER TABLE user_mattermost_settings
                    ALTER COLUMN webhook_url DROP NOT NULL
                """))
                conn.commit()
                print("[main] user_mattermost_settings table migrated (mattermost_username added)")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure user_mattermost_settings table: {e}")


ensure_user_mattermost_settings_table()


def ensure_project_patches_table() -> None:
    """project_patches 테이블이 없으면 생성 (패치 내역)."""
    try:
        conn = engine.connect()
        try:
            result = conn.execute(text("SELECT to_regclass('public.project_patches')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE project_patches (
                        id VARCHAR PRIMARY KEY,
                        project_id VARCHAR NOT NULL,
                        site VARCHAR NOT NULL,
                        patch_date DATE NOT NULL,
                        version VARCHAR NOT NULL DEFAULT '',
                        content TEXT NOT NULL DEFAULT '',
                        created_by VARCHAR,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_project_patches_project_id ON project_patches(project_id)"))
                conn.execute(text("CREATE INDEX ix_project_patches_site ON project_patches(site)"))
                conn.execute(text("CREATE INDEX ix_project_patches_patch_date ON project_patches(patch_date)"))
                conn.execute(text("CREATE INDEX ix_project_patches_id ON project_patches(id)"))
                conn.commit()
                print("[main] created project_patches table")
            else:
                print("[main] project_patches table already exists")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure project_patches table: {e}")


ensure_project_patches_table()


def ensure_project_sites_table() -> None:
    """project_sites 테이블이 없으면 생성 (프로젝트 공용 사이트 목록)."""
    try:
        conn = engine.connect()
        try:
            result = conn.execute(text("SELECT to_regclass('public.project_sites')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE project_sites (
                        id VARCHAR PRIMARY KEY,
                        project_id VARCHAR NOT NULL,
                        name VARCHAR NOT NULL,
                        created_by VARCHAR,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_project_sites_project_id ON project_sites(project_id)"))
                conn.execute(text("CREATE INDEX ix_project_sites_name ON project_sites(name)"))
                conn.execute(text("CREATE INDEX ix_project_sites_id ON project_sites(id)"))
                conn.commit()
                print("[main] created project_sites table")
            else:
                print("[main] project_sites table already exists")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure project_sites table: {e}")


ensure_project_sites_table()


def ensure_project_is_global_column() -> None:
    """Add projects.is_global column if missing."""
    try:
        conn = engine.connect()
        try:
            result = conn.execute(
                text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name='projects' AND column_name='is_global'"
                )
            )
            if result.fetchone() is None:
                conn.execute(
                    text(
                        "ALTER TABLE projects ADD COLUMN is_global BOOLEAN NOT NULL DEFAULT FALSE"
                    )
                )
                conn.commit()
                print("[main] added projects.is_global column")
            else:
                print("[main] projects.is_global column already exists")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure projects.is_global: {e}")


ensure_project_is_global_column()


app = FastAPI(
    title="SYNC Project Manager API",
    description="SYNC project management backend API",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["Auth"])
app.include_router(ai.router, prefix="/api/ai", tags=["AI"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(projects.router, prefix="/api/projects", tags=["Projects"])
app.include_router(tasks.router, prefix="/api/tasks", tags=["Tasks"])
app.include_router(comments.router, prefix="/api/comments", tags=["Comments"])
app.include_router(checklists.router, prefix="/api/checklists", tags=["Checklists"])
app.include_router(uploads.router, prefix="/api/uploads", tags=["Uploads"])
app.include_router(notifications.router, prefix="/api/notifications", tags=["Notifications"])
app.include_router(chat.router, prefix="/api/chat", tags=["Chat"])
app.include_router(workspaces.router, prefix="/api/workspaces", tags=["Workspaces"])
app.include_router(sprints.router, prefix="/api/sprints", tags=["Sprints"])
app.include_router(search.router, prefix="/api/search", tags=["Search"])
app.include_router(github.router, prefix="/api/github", tags=["GitHub"])
app.include_router(user_github_tokens.router, prefix="/api/github-token", tags=["GitHubToken"])
app.include_router(user_mattermost_settings.router, prefix="/api/mattermost-setting", tags=["MattermostSetting"])
app.include_router(patches.router, prefix="/api/patches", tags=["Patches"])
app.include_router(project_sites.router, prefix="/api/project-sites", tags=["ProjectSites"])
app.include_router(site_details.router, prefix="/api/site-details", tags=["SiteDetails"])
app.include_router(api_tokens.router, prefix="/api/tokens", tags=["ApiTokens"])
app.include_router(meeting_minutes.router, prefix="/api/meeting-minutes", tags=["MeetingMinutes"])
app.include_router(request_issue.router, prefix="/api/ri", tags=["RequestIssue"])
app.include_router(websocket.router, prefix="/api", tags=["WebSocket"])


def ensure_patch_checklist_columns() -> None:
    """Add project_patches.steps, test_items, status columns if missing."""
    migrations = [
        ("steps", "ALTER TABLE project_patches ADD COLUMN steps JSONB DEFAULT '[]'::jsonb NOT NULL"),
        ("test_items", "ALTER TABLE project_patches ADD COLUMN test_items JSONB DEFAULT '[]'::jsonb NOT NULL"),
        ("status", "ALTER TABLE project_patches ADD COLUMN status VARCHAR DEFAULT 'pending' NOT NULL"),
        ("notes", "ALTER TABLE project_patches ADD COLUMN notes TEXT DEFAULT '' NOT NULL"),
        ("note_image_urls", "ALTER TABLE project_patches ADD COLUMN note_image_urls VARCHAR[] DEFAULT '{}' NOT NULL"),
    ]
    try:
        conn = engine.connect()
        try:
            for col, sql in migrations:
                result = conn.execute(
                    text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name='project_patches' AND column_name=:col"
                    ),
                    {"col": col},
                )
                if result.fetchone() is None:
                    conn.execute(text(sql))
                    conn.commit()
                    print(f"[main] added project_patches.{col} column")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure patch checklist columns: {e}")


ensure_patch_checklist_columns()


def ensure_tasks_display_id_column() -> None:
    """Add tasks.display_id as SERIAL-equivalent (auto-incremented integer)."""
    try:
        conn = engine.connect()
        try:
            # 컬럼 존재 여부 확인
            result = conn.execute(text(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_name='tasks' AND column_name='display_id'"
            ))
            if result.fetchone() is None:
                conn.execute(text(
                    "ALTER TABLE tasks ADD COLUMN display_id SERIAL"
                ))
                conn.commit()
                print("[main] tasks.display_id column added (SERIAL)")
            else:
                # 컬럼은 있지만 시퀀스가 없는 경우 (create_all()로 신규 생성된 DB)
                seq_result = conn.execute(text(
                    "SELECT to_regclass('public.tasks_display_id_seq')"
                ))
                if seq_result.scalar() is None:
                    conn.execute(text("CREATE SEQUENCE tasks_display_id_seq"))
                    conn.execute(text(
                        "ALTER TABLE tasks ALTER COLUMN display_id "
                        "SET DEFAULT nextval('tasks_display_id_seq')"
                    ))
                    conn.execute(text(
                        "ALTER SEQUENCE tasks_display_id_seq OWNED BY tasks.display_id"
                    ))
                    conn.commit()
                    print("[main] tasks_display_id_seq sequence created and linked")
                else:
                    print("[main] tasks.display_id column already exists")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to ensure tasks.display_id: {e}")


ensure_tasks_display_id_column()


def ensure_patch_git_tag_column() -> None:
    """project_patches 테이블에 git_tag 컬럼 추가."""
    try:
        with engine.connect() as conn:
            conn.execute(text("""
                ALTER TABLE project_patches
                ADD COLUMN IF NOT EXISTS git_tag VARCHAR;
            """))
            conn.commit()
            print("[main] ensured project_patches.git_tag column")
    except Exception as e:
        print(f"[main] failed to ensure project_patches.git_tag: {e}")


ensure_patch_git_tag_column()


def ensure_patch_assignee_column() -> None:
    """project_patches 테이블에 assignee 컬럼 추가."""
    try:
        with engine.connect() as conn:
            conn.execute(text("""
                ALTER TABLE project_patches
                ADD COLUMN IF NOT EXISTS assignee VARCHAR;
            """))
            conn.commit()
            print("[main] ensured project_patches.assignee column")
    except Exception as e:
        print(f"[main] failed to ensure project_patches.assignee: {e}")


ensure_patch_assignee_column()


def backfill_patch_assignees() -> None:
    """기존 패치 담당자 일괄 설정: 연합뉴스→안성구, 나머지→정보영."""
    try:
        with engine.connect() as conn:
            # assignee가 NULL인 패치만 대상 (이미 설정된 건 건드리지 않음)
            conn.execute(text("""
                UPDATE project_patches
                SET assignee = CASE
                    WHEN site = '연합뉴스' THEN '안성구'
                    ELSE '정보영'
                END
                WHERE assignee IS NULL;
            """))
            conn.commit()
            print("[main] backfilled patch assignees")
    except Exception as e:
        print(f"[main] failed to backfill patch assignees: {e}")


backfill_patch_assignees()


def ensure_comment_file_urls_column() -> None:
    """Add comments.file_urls column if missing."""
    try:
        with engine.connect() as conn:
            conn.execute(text("""
                ALTER TABLE comments
                ADD COLUMN IF NOT EXISTS file_urls VARCHAR[] DEFAULT '{}' NOT NULL;
            """))
            conn.commit()
            print("[main] ensured comments.file_urls column")
    except Exception as e:
        print(f"[main] failed to ensure comments.file_urls: {e}")


ensure_comment_file_urls_column()


def ensure_favorite_project_ids_column() -> None:
    """Add users.favorite_project_ids column if missing."""
    try:
        with engine.connect() as conn:
            conn.execute(text("""
                ALTER TABLE users
                ADD COLUMN IF NOT EXISTS favorite_project_ids VARCHAR[] DEFAULT '{}' NOT NULL;
            """))
            conn.commit()
            print("[main] ensured users.favorite_project_ids column")
    except Exception as e:
        print(f"[main] failed to ensure users.favorite_project_ids: {e}")


ensure_favorite_project_ids_column()


def ensure_notification_type_task_created() -> None:
    """notifications.type enum에 'TASK_CREATED' 값 추가 (기존 DB 마이그레이션).
    SQLAlchemy는 enum NAME(대문자)을 DB에 저장하므로 'TASK_CREATED'가 필요함.
    """
    try:
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT 1 FROM pg_enum
                WHERE enumlabel = 'TASK_CREATED'
                  AND enumtypid = (
                    SELECT oid FROM pg_type WHERE typname = 'notificationtype'
                  )
            """))
            if result.fetchone() is None:
                conn.execute(text("ALTER TYPE notificationtype ADD VALUE 'TASK_CREATED'"))
                conn.commit()
                print("[main] added 'TASK_CREATED' to notificationtype enum")
            else:
                print("[main] notificationtype 'TASK_CREATED' already exists")
    except Exception as e:
        print(f"[main] failed to ensure notificationtype TASK_CREATED: {e}")


ensure_notification_type_task_created()


def ensure_notification_type_new_values() -> None:
    """notifications.type enum에 신규 값 추가 (TASK_DOCUMENT_ADDED, TASK_CHECKLIST_ADDED, TASK_CHECKLIST_ITEM_ADDED)."""
    new_values = [
        "TASK_DOCUMENT_ADDED",
        "TASK_CHECKLIST_ADDED",
        "TASK_CHECKLIST_ITEM_ADDED",
    ]
    try:
        with engine.connect() as conn:
            for val in new_values:
                result = conn.execute(text("""
                    SELECT 1 FROM pg_enum
                    WHERE enumlabel = :val
                      AND enumtypid = (
                        SELECT oid FROM pg_type WHERE typname = 'notificationtype'
                      )
                """), {"val": val})
                if result.fetchone() is None:
                    conn.execute(text(f"ALTER TYPE notificationtype ADD VALUE '{val}'"))
                    conn.commit()
                    print(f"[main] added '{val}' to notificationtype enum")
                else:
                    print(f"[main] notificationtype '{val}' already exists")
    except Exception as e:
        print(f"[main] failed to ensure notificationtype new values: {e}")


ensure_notification_type_new_values()


def migrate_project_sites_to_site_details() -> None:
    """project_sites 테이블의 기존 사이트를 site_details로 마이그레이션."""
    try:
        conn = engine.connect()
        try:
            rows = conn.execute(text(
                "SELECT id, project_id, name FROM project_sites"
            )).fetchall()
            migrated = 0
            for row in rows:
                existing = conn.execute(text(
                    "SELECT id FROM site_details WHERE id = :id"
                ), {"id": row[0]}).fetchone()
                if existing is None:
                    conn.execute(text(
                        """INSERT INTO site_details
                           (id, project_id, name, description, servers, databases, services, created_at, updated_at)
                           VALUES (:id, :project_id, :name, '', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, now(), now())"""
                    ), {"id": row[0], "project_id": row[1], "name": row[2]})
                    migrated += 1
            if migrated > 0:
                conn.commit()
                print(f"[main] migrated {migrated} project_sites → site_details")
            else:
                print("[main] project_sites migration: nothing to migrate")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to migrate project_sites: {e}")


migrate_project_sites_to_site_details()


def migrate_site_details_to_project_ids() -> None:
    """site_details.project_id (단일) → project_ids (JSON 배열) 마이그레이션."""
    try:
        conn = engine.connect()
        try:
            # 1. project_ids 컬럼 추가 (없으면)
            conn.execute(text(
                "ALTER TABLE site_details ADD COLUMN IF NOT EXISTS project_ids JSON DEFAULT '[]'::json"
            ))
            conn.commit()

            # 2. project_id 컬럼이 존재하면 project_ids로 데이터 이관
            col_exists = conn.execute(text(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_name='site_details' AND column_name='project_id'"
            )).fetchone()
            if col_exists:
                # project_ids가 비어있는 행만 이관
                conn.execute(text(
                    """UPDATE site_details
                       SET project_ids = json_build_array(project_id)
                       WHERE project_id IS NOT NULL
                         AND (project_ids IS NULL OR project_ids::text = '[]')"""
                ))
                conn.commit()
                print("[main] migrated site_details.project_id → project_ids")
        finally:
            conn.close()
    except Exception as e:
        print(f"[main] failed to migrate site_details project_ids: {e}")


migrate_site_details_to_project_ids()


def ensure_api_tokens_table() -> None:
    """api_tokens 테이블이 없으면 생성 (외부 서비스 연동용 API 토큰)."""
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT to_regclass('public.api_tokens')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE api_tokens (
                        id VARCHAR PRIMARY KEY,
                        user_id VARCHAR NOT NULL,
                        name VARCHAR NOT NULL,
                        token_hash VARCHAR NOT NULL UNIQUE,
                        token_prefix VARCHAR NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_api_tokens_user_id ON api_tokens(user_id)"))
                conn.execute(text("CREATE INDEX ix_api_tokens_token_hash ON api_tokens(token_hash)"))
                conn.commit()
                print("[main] created api_tokens table")
            else:
                print("[main] api_tokens table already exists")
    except Exception as e:
        print(f"[main] failed to ensure api_tokens table: {e}")


ensure_api_tokens_table()


def ensure_ai_summary_cache_table() -> None:
    """ai_summary_cache 테이블이 없으면 생성 (AI 일별 요약 DB 캐시)."""
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT to_regclass('public.ai_summary_cache')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE ai_summary_cache (
                        id VARCHAR PRIMARY KEY,
                        user_id VARCHAR NOT NULL,
                        workspace_id VARCHAR,
                        summary_scope VARCHAR NOT NULL DEFAULT 'all',
                        summary_date DATE NOT NULL,
                        summary_text TEXT NOT NULL,
                        generated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_ai_summary_cache_user_id ON ai_summary_cache(user_id)"))
                conn.execute(text("CREATE INDEX ix_ai_summary_cache_summary_date ON ai_summary_cache(summary_date)"))
                conn.commit()
                print("[main] created ai_summary_cache table")
            else:
                print("[main] ai_summary_cache table already exists")
    except Exception as e:
        print(f"[main] failed to ensure ai_summary_cache table: {e}")


ensure_ai_summary_cache_table()


def ensure_tasks_observer_ids_column() -> None:
    """Add tasks.observer_ids column if missing."""
    try:
        with engine.connect() as conn:
            conn.execute(text("""
                ALTER TABLE tasks
                ADD COLUMN IF NOT EXISTS observer_ids VARCHAR[] DEFAULT '{}' NOT NULL;
            """))
            conn.commit()
            print("[main] ensured tasks.observer_ids column")
    except Exception as e:
        print(f"[main] failed to ensure tasks.observer_ids: {e}")


ensure_tasks_observer_ids_column()


def seed_mbc_site_details_if_empty() -> None:
    """이름이 MBC인 site_details에 servers/databases/services 중 비어 있는 항목만 기본 인프라로 채웁니다."""
    try:
        from app.database import SessionLocal
        from app.models.site_detail import SiteDetail
        from app.mbc_site_default_data import (
            MBC_DATABASES,
            MBC_SERVERS,
            mbc_services_list,
        )

        db = SessionLocal()
        try:
            sites = (
                db.query(SiteDetail)
                .filter(func.lower(SiteDetail.name) == "mbc")
                .all()
            )
            touched = 0
            for site in sites:
                s, d, v = site.servers or [], site.databases or [], site.services or []
                changed = False
                if len(s) == 0:
                    site.servers = deepcopy(MBC_SERVERS)
                    changed = True
                if len(d) == 0:
                    site.databases = deepcopy(MBC_DATABASES)
                    changed = True
                if len(v) == 0:
                    site.services = mbc_services_list()
                    changed = True
                if changed:
                    touched += 1
                    print(f"[main] filled empty MBC infra fields for site_details id={site.id}")
            if touched:
                db.commit()
            elif sites:
                print("[main] MBC site infra already populated; skip seed")
            else:
                print("[main] no MBC site row; skip MBC infra seed")
        finally:
            db.close()
    except Exception as e:
        print(f"[main] failed MBC site infra seed: {e}")


seed_mbc_site_details_if_empty()


def ensure_workspace_owner_as_observer() -> None:
    """기존 모든 작업에 워크스페이스 오너를 참조자(observer)로 추가."""
    from app.database import SessionLocal
    from app.models.workspace import Workspace
    from app.models.project import Project
    from app.models.task import Task

    try:
        db = SessionLocal()
        try:
            # 이미 실행되었는지 체크 — 임의의 워크스페이스 오너가 이미 참조자인지 확인
            sample_ws = db.query(Workspace).first()
            if not sample_ws:
                return
            sample_project = db.query(Project).filter(
                Project.workspace_id == sample_ws.id
            ).first()
            if sample_project:
                sample_task = db.query(Task).filter(
                    Task.project_id == sample_project.id
                ).first()
                if sample_task and sample_ws.owner_id in (sample_task.observer_ids or []):
                    print("[main] workspace owner already in observers; skip migration")
                    return

            # 워크스페이스별 오너 → 프로젝트 → 태스크 일괄 업데이트
            workspaces = db.query(Workspace).all()
            total_updated = 0
            for ws in workspaces:
                if not ws.owner_id:
                    continue
                projects = db.query(Project).filter(
                    Project.workspace_id == ws.id
                ).all()
                project_ids = [p.id for p in projects]
                if not project_ids:
                    continue

                tasks_list = db.query(Task).filter(
                    Task.project_id.in_(project_ids)
                ).all()
                for t in tasks_list:
                    observers = list(t.observer_ids or [])
                    if ws.owner_id not in observers:
                        observers.append(ws.owner_id)
                        t.observer_ids = observers
                        total_updated += 1

            if total_updated > 0:
                db.commit()
                print(f"[main] added workspace owner as observer to {total_updated} tasks")
            else:
                print("[main] no tasks needed observer update")
        finally:
            db.close()
    except Exception as e:
        print(f"[main] ensure_workspace_owner_as_observer failed: {e}")


ensure_workspace_owner_as_observer()


def ensure_meeting_minutes_table() -> None:
    """meeting_minutes 테이블이 없으면 생성."""
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT to_regclass('public.meeting_minutes')"))
            if result.scalar() is None:
                conn.execute(text("""
                    CREATE TABLE meeting_minutes (
                        id VARCHAR PRIMARY KEY,
                        workspace_id VARCHAR NOT NULL,
                        title VARCHAR NOT NULL,
                        content TEXT NOT NULL DEFAULT '',
                        category VARCHAR DEFAULT '',
                        meeting_date DATE NOT NULL,
                        creator_id VARCHAR NOT NULL,
                        attendee_ids VARCHAR[] DEFAULT '{}' NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """))
                conn.execute(text("CREATE INDEX ix_meeting_minutes_workspace_id ON meeting_minutes(workspace_id)"))
                conn.execute(text("CREATE INDEX ix_meeting_minutes_creator_id ON meeting_minutes(creator_id)"))
                conn.commit()
                print("[main] created meeting_minutes table")
            else:
                print("[main] meeting_minutes table already exists")
    except Exception as e:
        print(f"[main] failed to ensure meeting_minutes table: {e}")


ensure_meeting_minutes_table()


@app.get("/")
async def root():
    """Root endpoint."""
    return {"message": "SYNC API Server", "status": "running"}


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "sync-api"}
