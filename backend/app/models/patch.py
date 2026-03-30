"""Patch history model (SQLAlchemy)."""

from sqlalchemy import Column, String, Date, DateTime, Text
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

    created_by = Column(String, nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

