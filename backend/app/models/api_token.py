"""
API 토큰 모델 (외부 서비스 연동용)
"""
from sqlalchemy import Column, String, DateTime
from sqlalchemy.sql import func
from app.database import Base


class ApiToken(Base):
    __tablename__ = "api_tokens"

    id = Column(String, primary_key=True, index=True)
    user_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)           # 토큰 이름 (사용자 지정)
    token_hash = Column(String, nullable=False, unique=True)  # SHA-256 해시
    token_prefix = Column(String, nullable=False)   # 앞 8자리 (목록 표시용)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self):
        return f"<ApiToken(id={self.id}, user_id={self.user_id}, name={self.name})>"
