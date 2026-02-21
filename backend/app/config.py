"""Application settings."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database
    DB_HOST: str = "postgres"
    DB_PORT: int = 5432
    DB_USER: str = "admin"
    DB_PASSWORD: str = "admin123"
    DB_NAME: str = "dora_db"

    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24

    # Social auth
    GOOGLE_CLIENT_ID: str = ""
    KAKAO_REST_API_KEY: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
