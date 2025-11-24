"""
알림 스키마 (Pydantic)
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.models.notification import NotificationType


class NotificationBase(BaseModel):
    """알림 기본 스키마"""
    type: NotificationType
    user_id: str
    project_id: Optional[str] = None
    task_id: Optional[str] = None
    comment_id: Optional[str] = None
    title: str
    message: str


class NotificationCreate(NotificationBase):
    """알림 생성 스키마"""
    pass


class NotificationResponse(NotificationBase):
    """알림 응답 스키마"""
    id: str
    is_read: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class NotificationUpdate(BaseModel):
    """알림 업데이트 스키마"""
    is_read: Optional[bool] = None

