"""User-level GitHub token storage (SQLAlchemy).

Project GitHub 연결은 레포(owner/name)만 저장하고,
실제 GitHub API 호출은 현재 사용자 토큰을 사용합니다.
"""

from sqlalchemy import Column, String, DateTime
from sqlalchemy.sql import func

from app.database import Base


class UserGitHubToken(Base):
    __tablename__ = "user_github_tokens"

    id = Column(String, primary_key=True, index=True)
    user_id = Column(String, nullable=False, unique=True, index=True)
    access_token = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

