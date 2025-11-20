"""
프로젝트 모델 (SQLAlchemy)
"""
from sqlalchemy import Column, String, Integer, DateTime, ARRAY
from sqlalchemy.sql import func
from app.database import Base


class Project(Base):
    """프로젝트 테이블 모델"""
    __tablename__ = "projects"
    
    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    color = Column(Integer, nullable=False, default=0xFF2196F3)  # Color 값을 정수로 저장
    team_member_ids = Column(ARRAY(String), default=[], nullable=False)  # 팀원 ID 배열
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<Project(id={self.id}, name={self.name})>"

