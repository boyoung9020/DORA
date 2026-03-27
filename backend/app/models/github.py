"""GitHub 연동 모델 (SQLAlchemy)"""
from sqlalchemy import Column, String, DateTime
from sqlalchemy.sql import func
from app.database import Base


class ProjectGitHub(Base):
    """프로젝트-GitHub 레포지토리 연동 테이블"""
    __tablename__ = "project_github"

    id = Column(String, primary_key=True, index=True)
    project_id = Column(String, nullable=False, unique=True, index=True)
    repo_owner = Column(String, nullable=False)
    repo_name = Column(String, nullable=False)
    access_token = Column(String, nullable=True)  # GitHub PAT (nullable for public repos)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    def __repr__(self):
        return f"<ProjectGitHub(project_id={self.project_id}, repo={self.repo_owner}/{self.repo_name})>"
