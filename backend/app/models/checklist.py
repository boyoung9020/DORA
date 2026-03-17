"""
체크리스트 모델 (SQLAlchemy)
"""
from sqlalchemy import Column, String, Boolean, Integer, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Checklist(Base):
    """체크리스트 테이블 모델"""
    __tablename__ = "checklists"

    id = Column(String, primary_key=True, index=True)
    task_id = Column(String, nullable=False, index=True)
    title = Column(String, nullable=False, default="Checklist")
    created_by = Column(String, nullable=False)  # user_id
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=True)

    def __repr__(self):
        return f"<Checklist(id={self.id}, task_id={self.task_id})>"


class ChecklistItem(Base):
    """체크리스트 항목 테이블 모델"""
    __tablename__ = "checklist_items"

    id = Column(String, primary_key=True, index=True)
    checklist_id = Column(String, nullable=False, index=True)
    task_id = Column(String, nullable=False, index=True)  # 빠른 조회용 비정규화
    content = Column(String, nullable=False)
    is_checked = Column(Boolean, default=False, nullable=False)
    assignee_id = Column(String, nullable=True)
    due_date = Column(DateTime(timezone=True), nullable=True)
    display_order = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=True)

    def __repr__(self):
        return f"<ChecklistItem(id={self.id}, checklist_id={self.checklist_id})>"
