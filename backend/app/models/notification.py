"""
알림 모델 (SQLAlchemy)
"""
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Enum as SQLEnum
from sqlalchemy.sql import func
from app.database import Base
import enum


class NotificationType(str, enum.Enum):
    """알림 타입 열거형"""
    PROJECT_MEMBER_ADDED = "projectMemberAdded"      # 프로젝트 팀원으로 추가됨
    TASK_ASSIGNED = "taskAssigned"                    # 작업 할당자로 임명됨
    TASK_OPTION_CHANGED = "taskOptionChanged"        # 작업 옵션 변경 (중요도, 상태, 날짜)
    TASK_COMMENT_ADDED = "taskCommentAdded"           # 작업에 코멘트 추가됨
    TASK_MENTIONED = "taskMentioned"                  # 댓글에서 멘션됨


class Notification(Base):
    """알림 테이블 모델"""
    __tablename__ = "notifications"
    
    id = Column(String, primary_key=True, index=True)
    type = Column(SQLEnum(NotificationType), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    project_id = Column(String, ForeignKey("projects.id", ondelete="CASCADE"), nullable=True, index=True)
    task_id = Column(String, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=True, index=True)
    comment_id = Column(String, ForeignKey("comments.id", ondelete="CASCADE"), nullable=True, index=True)
    title = Column(String, nullable=False)  # 알림 제목
    message = Column(String, nullable=False)  # 알림 메시지
    is_read = Column(Boolean, default=False, nullable=False, index=True)  # 읽음 여부
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)
    
    def __repr__(self):
        return f"<Notification(id={self.id}, type={self.type}, user_id={self.user_id}, is_read={self.is_read})>"

