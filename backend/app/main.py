"""FastAPI application entrypoint."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.database import Base, engine
from app.routers import (
    ai,
    auth,
    chat,
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
