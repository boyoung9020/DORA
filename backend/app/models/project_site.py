"""Project-level site registry (SQLAlchemy).

Same project 내 모든 작업 다이얼로그에서 공용으로 선택 가능한 '사이트(고객사명)' 목록.
"""

from sqlalchemy import Column, String, DateTime
from sqlalchemy.sql import func

from app.database import Base


class ProjectSite(Base):
    __tablename__ = "project_sites"

    id = Column(String, primary_key=True, index=True)
    project_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    created_by = Column(String, nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

