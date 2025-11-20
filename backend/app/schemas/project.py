"""
프로젝트 관련 Pydantic 스키마
"""
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List


class ProjectBase(BaseModel):
    """프로젝트 기본 스키마"""
    name: str
    description: Optional[str] = None
    color: int = 0xFF2196F3  # 기본 파란색


class ProjectCreate(ProjectBase):
    """프로젝트 생성 요청 스키마"""
    pass


class ProjectUpdate(BaseModel):
    """프로젝트 수정 요청 스키마"""
    name: Optional[str] = None
    description: Optional[str] = None
    color: Optional[int] = None
    team_member_ids: Optional[List[str]] = None


class ProjectResponse(ProjectBase):
    """프로젝트 응답 스키마"""
    id: str
    team_member_ids: List[str]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

