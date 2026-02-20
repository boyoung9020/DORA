"""
워크스페이스 관련 Pydantic 스키마
"""
from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class WorkspaceCreate(BaseModel):
    """워크스페이스 생성 요청 스키마"""
    name: str
    description: Optional[str] = None


class WorkspaceResponse(BaseModel):
    """워크스페이스 응답 스키마"""
    id: str
    name: str
    description: Optional[str] = None
    owner_id: str
    invite_token: str
    member_count: int = 0
    created_at: datetime

    class Config:
        from_attributes = True


class WorkspaceMemberResponse(BaseModel):
    """워크스페이스 멤버 응답 스키마"""
    user_id: str
    username: str
    profile_image_url: Optional[str] = None
    role: str
    joined_at: datetime

    class Config:
        from_attributes = True


class JoinByTokenRequest(BaseModel):
    """초대 토큰으로 워크스페이스 참여 요청 스키마"""
    invite_token: str
