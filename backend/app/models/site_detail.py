"""SQLAlchemy model for site details (server/DB/service info per project site)."""

import uuid
from sqlalchemy import Column, String, Text, DateTime, JSON
from sqlalchemy.sql import func
from app.database import Base


class SiteDetail(Base):
    __tablename__ = "site_details"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, nullable=False, index=True)

    # 사이트 기본 정보
    name = Column(String, nullable=False)
    description = Column(Text, nullable=False, default="")

    # JSON 배열로 저장되는 정보들
    # servers: [{"ip": "...", "username": "...", "note": "..."}]
    servers = Column(JSON, nullable=False, default=list)
    # databases: [{"name": "...", "type": "...", "note": "..."}]
    databases = Column(JSON, nullable=False, default=list)
    # services: [{"name": "...", "version": "...", "note": "..."}]
    services = Column(JSON, nullable=False, default=list)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
