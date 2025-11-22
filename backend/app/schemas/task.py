"""
태스크 관련 Pydantic 스키마
"""
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List, Dict, Any
from app.models.task import TaskStatus, TaskPriority


class TaskBase(BaseModel):
    """태스크 기본 스키마"""
    title: str
    description: str = ""
    status: TaskStatus = TaskStatus.BACKLOG
    project_id: str
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    detail: str = ""
    detail_image_urls: List[str] = []  # 상세 내용 이미지 URL 배열
    priority: TaskPriority = TaskPriority.P2
    assigned_member_ids: List[str] = []


class TaskCreate(TaskBase):
    """태스크 생성 요청 스키마"""
    pass


class TaskUpdate(BaseModel):
    """태스크 수정 요청 스키마"""
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[TaskStatus] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    detail: Optional[str] = None
    detail_image_urls: Optional[List[str]] = None  # 상세 내용 이미지 URL 배열
    priority: Optional[TaskPriority] = None
    assigned_member_ids: Optional[List[str]] = None


class TaskResponse(TaskBase):
    """태스크 응답 스키마"""
    id: str
    comment_ids: List[str]
    status_history: List[Dict[str, Any]] = []
    assignment_history: List[Dict[str, Any]] = []
    priority_history: List[Dict[str, Any]] = []
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

