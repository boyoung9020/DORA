"""Patch history model (SQLAlchemy)."""

from sqlalchemy import Column, String, Date, DateTime, Text, JSON
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.sql import func

from app.database import Base


class ProjectPatch(Base):
    __tablename__ = "project_patches"

    id = Column(String, primary_key=True, index=True)
    project_id = Column(String, nullable=False, index=True)

    # 고객사명(사이트)
    site = Column(String, nullable=False, index=True)

    patch_date = Column(Date, nullable=False, index=True)
    version = Column(String, nullable=False, default="")
    content = Column(Text, nullable=False, default="")

    # 패치 순서 체크리스트: [{"text": "...", "checked": false}, ...]
    steps = Column(JSON, nullable=False, default=list)
    # 테스트 리스트 체크리스트: [{"text": "...", "checked": false}, ...]
    test_items = Column(JSON, nullable=False, default=list)
    # 상태: pending | in_progress | done
    status = Column(String, nullable=False, default="pending", index=True)
    # 특이사항 메모
    notes = Column(Text, nullable=False, default="")
    # 특이사항 이미지 URL 배열
    note_image_urls = Column(ARRAY(String), default=[], nullable=False)

    # 연결된 GitHub 태그 (선택)
    git_tag = Column(String, nullable=True, default=None)

    created_by = Column(String, nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

