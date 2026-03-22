"""Database bootstrap script."""

import uuid

from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from app.database import Base, SessionLocal, engine
from app.models.comment_reaction import CommentReaction  # noqa: F401
from app.models.message_reaction import MessageReaction  # noqa: F401
from app.models.sprint import Sprint  # noqa: F401
from app.models.user import User
from app.utils.security import get_password_hash

# Create tables for new environments.
Base.metadata.create_all(bind=engine)


def run_migrations():
    """Add missing columns/indexes for existing environments."""
    inspector = inspect(engine)

    with engine.connect() as conn:
        if "tasks" in inspector.get_table_names():
            columns = [col["name"] for col in inspector.get_columns("tasks")]
            if "display_order" not in columns:
                conn.execute(
                    text(
                        "ALTER TABLE tasks "
                        "ADD COLUMN display_order INTEGER DEFAULT 0 NOT NULL"
                    )
                )
                conn.commit()
                print("[migration] added tasks.display_order")
            if "sprint_id" not in columns:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN sprint_id VARCHAR"))
                conn.commit()
                print("[migration] added tasks.sprint_id")
            conn.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_tasks_sprint_id "
                    "ON tasks(sprint_id)"
                )
            )
            conn.commit()
            if "parent_task_id" not in columns:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN parent_task_id VARCHAR"))
                conn.commit()
                print("[migration] added tasks.parent_task_id")
            conn.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_tasks_parent_task_id "
                    "ON tasks(parent_task_id)"
                )
            )
            conn.commit()

        if "projects" in inspector.get_table_names():
            columns = [col["name"] for col in inspector.get_columns("projects")]
            if "workspace_id" not in columns:
                conn.execute(text("ALTER TABLE projects ADD COLUMN workspace_id VARCHAR"))
                conn.commit()
                print("[migration] added projects.workspace_id")
            if "creator_id" not in columns:
                conn.execute(text("ALTER TABLE projects ADD COLUMN creator_id VARCHAR"))
                conn.commit()
                print("[migration] added projects.creator_id")

        if "chat_rooms" in inspector.get_table_names():
            columns = [col["name"] for col in inspector.get_columns("chat_rooms")]
            if "workspace_id" not in columns:
                conn.execute(text("ALTER TABLE chat_rooms ADD COLUMN workspace_id VARCHAR"))
                conn.commit()
                print("[migration] added chat_rooms.workspace_id")
            conn.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS "
                    "ix_chat_rooms_workspace_id ON chat_rooms(workspace_id)"
                )
            )
            conn.commit()

        try:
            conn.execute(
                text(
                    "UPDATE users "
                    "SET is_approved = TRUE "
                    "WHERE is_approved = FALSE AND is_admin = FALSE"
                )
            )
            conn.commit()
        except Exception:
            # Keep startup resilient for old/non-standard schemas.
            pass


run_migrations()


def init_db():
    """Create default admin user if missing."""
    db: Session = SessionLocal()
    try:
        admin = db.query(User).filter(User.is_admin.is_(True)).first()
        if not admin:
            admin_user = User(
                id=str(uuid.uuid4()),
                username="admin",
                email="admin@sync.com",
                password_hash=get_password_hash("admin123"),
                is_admin=True,
                is_approved=True,
                is_pm=True,
            )
            db.add(admin_user)
            db.commit()
            print("[init_db] created default admin (admin/admin123)")
        else:
            print("[init_db] admin already exists")
    except Exception as e:
        print(f"[init_db] failed: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    init_db()
