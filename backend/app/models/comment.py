"""
댓글 모델 (SQLAlchemy)
"""
from sqlalchemy import Column, String, DateTime, ARRAY
from sqlalchemy.sql import func
from app.database import Base


class Comment(Base):
    """댓글 테이블 모델"""
    __tablename__ = "comments"
    
    id = Column(String, primary_key=True, index=True)
    task_id = Column(String, nullable=False, index=True)
    user_id = Column(String, nullable=False, index=True)
    username = Column(String, nullable=False)
    content = Column(String, nullable=False)
    image_urls = Column(ARRAY(String), default=[], nullable=False)  # 이미지 URL 배열
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=True)
    
    def __repr__(self):
        return f"<Comment(id={self.id}, task_id={self.task_id}, user_id={self.user_id})>"

