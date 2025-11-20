"""
애플리케이션 설정
환경 변수에서 설정값을 읽어옵니다
"""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """애플리케이션 설정 클래스"""
    
    # 데이터베이스 설정
    DB_HOST: str = "postgres"  # Docker Compose에서 postgres 서비스 이름
    DB_PORT: int = 5432
    DB_USER: str = "admin"  # docker-compose.yml과 일치
    DB_PASSWORD: str = "admin123"  # docker-compose.yml과 일치
    DB_NAME: str = "dora_db"
    
    # JWT 토큰 설정
    SECRET_KEY: str = "your-secret-key-change-in-production"  # 프로덕션에서는 반드시 변경!
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24시간
    
    class Config:
        env_file = ".env"  # .env 파일에서 환경 변수 읽기
        case_sensitive = True


# 전역 설정 인스턴스
settings = Settings()

