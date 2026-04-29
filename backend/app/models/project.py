"""
프로젝트 모델 (SQLAlchemy)
"""
from sqlalchemy import Boolean, Column, String, Integer, BigInteger, DateTime, ARRAY
from sqlalchemy.sql import func
from app.database import Base


class Project(Base):
    """프로젝트 테이블 모델"""
    __tablename__ = "projects"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    color = Column(BigInteger, nullable=False, default=0xFF2196F3)  # Color 값을 BigInteger로 저장 (Flutter Color는 32비트)
    team_member_ids = Column(ARRAY(String), default=[], nullable=False)  # 팀원 ID 배열
    workspace_id = Column(String, nullable=True, index=True)  # 소속 워크스페이스 ID
    creator_id = Column(String, nullable=True, index=True)    # 프로젝트 생성자 = 해당 프로젝트 PM
    is_global = Column(Boolean, nullable=False, default=False)  # 전체 사용자에게 기본 표시 (워크스페이스 무관)
    is_archived = Column(Boolean, nullable=False, default=False, server_default='false')  # 보관 처리: UI 노출만 차단, 데이터는 보존
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    def __repr__(self):
        return f"<Project(id={self.id}, name={self.name})>"

