"""
댓글 관련 Pydantic 스키마
"""
from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class CommentBase(BaseModel):
    """댓글 기본 스키마"""
    content: str


class CommentCreate(CommentBase):
    """댓글 생성 요청 스키마"""
    task_id: str


class CommentUpdate(BaseModel):
    """댓글 수정 요청 스키마"""
    content: str


class CommentResponse(CommentBase):
    """댓글 응답 스키마"""
    id: str
    task_id: str
    user_id: str
    username: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

