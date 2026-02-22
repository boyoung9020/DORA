"""
FastAPI 硫붿씤 ?좏뵆由ъ??댁뀡
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from app.database import engine, Base
from app.routers import auth, users, projects, tasks, comments, uploads, notifications, websocket, chat, workspaces

# ?곗씠?곕쿋?댁뒪 ?뚯씠釉??앹꽦
Base.metadata.create_all(bind=engine)

# comments ?뚯씠釉붿뿉 image_urls 而щ읆???놁쑝硫?異붽?
def ensure_image_urls_column():
    """comments ?뚯씠釉붿뿉 image_urls 而щ읆???덈뒗吏 ?뺤씤?섍퀬 ?놁쑝硫?異붽?"""
    try:
        conn = engine.connect()
        try:
            # 而щ읆???대? 議댁옱?섎뒗吏 ?뺤씤
            result = conn.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='comments' AND column_name='image_urls'
            """))
            
            if result.fetchone() is None:
                # image_urls 而щ읆 異붽?
                conn.execute(text("""
                    ALTER TABLE comments 
                    ADD COLUMN image_urls VARCHAR[] DEFAULT '{}' NOT NULL
                """))
                conn.commit()
                print("??comments ?뚯씠釉붿뿉 image_urls 而щ읆??異붽??섏뿀?듬땲??")
            else:
                print("??comments ?뚯씠釉붿뿉 image_urls 而щ읆???대? 議댁옱?⑸땲??")
        finally:
            conn.close()
    except Exception as e:
        print(f"?좑툘 image_urls 而щ읆 ?뺤씤 以??ㅻ쪟 (臾댁떆??: {e}")

# ?쒕쾭 ?쒖옉 ??而щ읆 ?뺤씤
ensure_image_urls_column()

# FastAPI ???앹꽦
app = FastAPI(
    title="SYNC Project Manager API",
    description="?꾨줈?앺듃 愿由??쒖뒪??諛깆뿏??API",
    version="1.0.0"
)

# CORS ?ㅼ젙 (Flutter ?깆뿉???묎렐 媛?ν븯?꾨줉)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ?꾨줈?뺤뀡?먯꽌???뱀젙 ?꾨찓?몃쭔 ?덉슜?섏꽭??
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ?쇱슦???깅줉
app.include_router(auth.router, prefix="/api/auth", tags=["?몄쬆"])
app.include_router(users.router, prefix="/api/users", tags=["?ъ슜??])
app.include_router(projects.router, prefix="/api/projects", tags=["?꾨줈?앺듃"])
app.include_router(tasks.router, prefix="/api/tasks", tags=["?쒖뒪??])
app.include_router(comments.router, prefix="/api/comments", tags=["?볤?"])
app.include_router(uploads.router, prefix="/api/uploads", tags=["?낅줈??])
app.include_router(notifications.router, prefix="/api/notifications", tags=["?뚮┝"])
app.include_router(chat.router, prefix="/api/chat", tags=["梨꾪똿"])
app.include_router(workspaces.router, prefix="/api/workspaces", tags=["?뚰겕?ㅽ럹?댁뒪"])
app.include_router(websocket.router, prefix="/api", tags=["WebSocket"])


@app.get("/")
async def root():
    """?ъ뒪 泥댄겕 ?붾뱶?ъ씤??""
    return {"message": "SYNC API Server", "status": "running"}


@app.get("/health")
async def health_check():
    """?곸꽭 ?ъ뒪 泥댄겕"""
    return {"status": "healthy", "service": "sync-api"}

