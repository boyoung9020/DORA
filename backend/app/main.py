"""
FastAPI 메인 애플리케이션
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from app.database import engine, Base
from app.routers import auth, users, projects, tasks, comments, uploads

# 데이터베이스 테이블 생성
Base.metadata.create_all(bind=engine)

# comments 테이블에 image_urls 컬럼이 없으면 추가
def ensure_image_urls_column():
    """comments 테이블에 image_urls 컬럼이 있는지 확인하고 없으면 추가"""
    try:
        conn = engine.connect()
        try:
            # 컬럼이 이미 존재하는지 확인
            result = conn.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='comments' AND column_name='image_urls'
            """))
            
            if result.fetchone() is None:
                # image_urls 컬럼 추가
                conn.execute(text("""
                    ALTER TABLE comments 
                    ADD COLUMN image_urls VARCHAR[] DEFAULT '{}' NOT NULL
                """))
                conn.commit()
                print("✅ comments 테이블에 image_urls 컬럼이 추가되었습니다.")
            else:
                print("✅ comments 테이블에 image_urls 컬럼이 이미 존재합니다.")
        finally:
            conn.close()
    except Exception as e:
        print(f"⚠️ image_urls 컬럼 확인 중 오류 (무시됨): {e}")

# 서버 시작 시 컬럼 확인
ensure_image_urls_column()

# FastAPI 앱 생성
app = FastAPI(
    title="DORA Project Manager API",
    description="프로젝트 관리 시스템 백엔드 API",
    version="1.0.0"
)

# CORS 설정 (Flutter 앱에서 접근 가능하도록)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 프로덕션에서는 특정 도메인만 허용하세요
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(auth.router, prefix="/api/auth", tags=["인증"])
app.include_router(users.router, prefix="/api/users", tags=["사용자"])
app.include_router(projects.router, prefix="/api/projects", tags=["프로젝트"])
app.include_router(tasks.router, prefix="/api/tasks", tags=["태스크"])
app.include_router(comments.router, prefix="/api/comments", tags=["댓글"])
app.include_router(uploads.router, prefix="/api/uploads", tags=["업로드"])


@app.get("/")
async def root():
    """헬스 체크 엔드포인트"""
    return {"message": "DORA API Server", "status": "running"}


@app.get("/health")
async def health_check():
    """상세 헬스 체크"""
    return {"status": "healthy", "service": "dora-api"}

