"""SQLAlchemy model for site details (server/DB/service info per project site)."""

import uuid
from sqlalchemy import Column, String, Text, DateTime, JSON
from sqlalchemy.sql import func
from app.database import Base


class SiteDetail(Base):
    __tablename__ = "site_details"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))

    # project_ids: 이 사이트가 연결된 프로젝트 ID 목록 (같은 이름 = 같은 사이트, 여러 프로젝트 공유)
    project_ids = Column(JSON, nullable=False, default=list)

    # 사이트 기본 정보
    name = Column(String, nullable=False)
    description = Column(Text, nullable=False, default="")

    # JSON 배열로 저장되는 정보들
    # servers: ip, username, password, gpu, mount, note (+ camelCase from 클라이언트)
    servers = Column(JSON, nullable=False, default=list)
    # databases: name, type, user, password, ip, port, note
    databases = Column(JSON, nullable=False, default=list)
    # services: name, version, serverIp/server_ip, workers, gpuUsage/gpu_usage, note
    services = Column(JSON, nullable=False, default=list)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
