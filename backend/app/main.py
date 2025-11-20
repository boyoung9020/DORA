"""
FastAPI 메인 애플리케이션
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.routers import auth, users, projects, tasks, comments

# 데이터베이스 테이블 생성
Base.metadata.create_all(bind=engine)

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


@app.get("/")
async def root():
    """헬스 체크 엔드포인트"""
    return {"message": "DORA API Server", "status": "running"}


@app.get("/health")
async def health_check():
    """상세 헬스 체크"""
    return {"status": "healthy", "service": "dora-api"}

