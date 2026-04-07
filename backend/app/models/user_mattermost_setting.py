"""사용자별 Mattermost 웹훅 설정 (SQLAlchemy)."""

from sqlalchemy import Boolean, Column, String, DateTime
from sqlalchemy.sql import func

from app.database import Base


class UserMattermostSetting(Base):
    __tablename__ = "user_mattermost_settings"

    id = Column(String, primary_key=True, index=True)
    user_id = Column(String, nullable=False, unique=True, index=True)
    webhook_url = Column(String, nullable=True)
    is_enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
