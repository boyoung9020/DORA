"""
워크스페이스 모델 (SQLAlchemy)
"""
from sqlalchemy import Column, String, DateTime, UniqueConstraint, ForeignKey
from sqlalchemy.sql import func
from app.database import Base


class Workspace(Base):
    """워크스페이스 테이블 모델"""
    __tablename__ = "workspaces"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    owner_id = Column(String, ForeignKey("users.id"), nullable=False)
    invite_token = Column(String, unique=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self):
        return f"<Workspace(id={self.id}, name={self.name})>"


class WorkspaceMember(Base):
    """워크스페이스 멤버 테이블 모델"""
    __tablename__ = "workspace_members"

    id = Column(String, primary_key=True, index=True)
    workspace_id = Column(String, ForeignKey("workspaces.id"), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    role = Column(String, default="member", nullable=False)  # "owner" | "member"
    joined_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("workspace_id", "user_id", name="uq_workspace_member"),
    )

    def __repr__(self):
        return f"<WorkspaceMember(workspace_id={self.workspace_id}, user_id={self.user_id}, role={self.role})>"
