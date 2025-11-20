"""
태스크 모델 (SQLAlchemy)
"""
from sqlalchemy import Column, String, DateTime, Integer, Enum as SQLEnum, ARRAY, JSON
from sqlalchemy.sql import func
from app.database import Base
import enum


class TaskStatus(str, enum.Enum):
    """태스크 상태 열거형"""
    BACKLOG = "backlog"
    READY = "ready"
    IN_PROGRESS = "inProgress"
    IN_REVIEW = "inReview"
    DONE = "done"


class TaskPriority(str, enum.Enum):
    """태스크 중요도 열거형"""
    P0 = "p0"
    P1 = "p1"
    P2 = "p2"
    P3 = "p3"


class Task(Base):
    """태스크 테이블 모델"""
    __tablename__ = "tasks"
    
    id = Column(String, primary_key=True, index=True)
    title = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True, default="")
    status = Column(SQLEnum(TaskStatus), nullable=False, default=TaskStatus.BACKLOG, index=True)
    project_id = Column(String, nullable=False, index=True)
    start_date = Column(DateTime(timezone=True), nullable=True)
    end_date = Column(DateTime(timezone=True), nullable=True)
    detail = Column(String, nullable=True, default="")
    assigned_member_ids = Column(ARRAY(String), default=[], nullable=False)
    comment_ids = Column(ARRAY(String), default=[], nullable=False)
    priority = Column(SQLEnum(TaskPriority), nullable=False, default=TaskPriority.P2)
    
    # 히스토리 데이터는 JSON으로 저장
    status_history = Column(JSON, default=[], nullable=False)
    assignment_history = Column(JSON, default=[], nullable=False)
    priority_history = Column(JSON, default=[], nullable=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<Task(id={self.id}, title={self.title}, status={self.status})>"

