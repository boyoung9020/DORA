"""
데이터베이스 연결 설정
"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.config import settings

# PostgreSQL 연결 문자열 생성
# postgresql://사용자명:비밀번호@호스트:포트/데이터베이스명
DATABASE_URL = (
    f"postgresql://{settings.DB_USER}:{settings.DB_PASSWORD}"
    f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
)

# SQLAlchemy 엔진 생성
# pool_pre_ping=True: 연결이 끊어졌을 때 자동으로 재연결
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,  # 연결 상태 확인 후 사용
    pool_size=10,  # 연결 풀 크기
    max_overflow=20  # 추가 연결 허용 수
)

# 세션 팩토리 생성
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base 클래스 (모든 모델이 상속받을 클래스)
Base = declarative_base()


def get_db():
    """
    데이터베이스 세션 의존성 함수
    FastAPI의 Depends()에서 사용
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

