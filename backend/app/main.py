"""FastAPI application entrypoint."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.database import Base, engine
from app.routers import (
    ai,
    auth,
    chat,
    checklists,
    comments,
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
app.include_router(websocket.router, prefix="/api", tags=["WebSocket"])


@app.get("/")
async def root():
    """Root endpoint."""
    return {"message": "SYNC API Server", "status": "running"}


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "sync-api"}
