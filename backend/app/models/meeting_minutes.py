"""
회의록 모델 (SQLAlchemy)
"""
from sqlalchemy import Column, String, DateTime, Text, Date, ARRAY
from sqlalchemy.sql import func
from app.database import Base


class MeetingMinutes(Base):
    """회의록 테이블 모델"""
    __tablename__ = "meeting_minutes"

    id = Column(String, primary_key=True, index=True)
    workspace_id = Column(String, nullable=False, index=True)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False, default="")  # Markdown 본문
    category = Column(String, nullable=True, default="")  # 사용자 자유 입력 카테고리
    meeting_date = Column(Date, nullable=False)  # 회의 날짜
    creator_id = Column(String, nullable=False, index=True)
    attendee_ids = Column(ARRAY(String), default=[], nullable=False)  # 참석자 ID 배열
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    def __repr__(self):
        return f"<MeetingMinutes(id={self.id}, title={self.title})>"
