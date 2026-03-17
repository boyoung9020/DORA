"""
체크리스트 관련 Pydantic 스키마
"""
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List


class ChecklistItemCreate(BaseModel):
    """체크리스트 항목 생성 요청 스키마"""
    checklist_id: str
    content: str


class ChecklistItemUpdate(BaseModel):
    """체크리스트 항목 수정 요청 스키마"""
    content: Optional[str] = None
    is_checked: Optional[bool] = None
    assignee_id: Optional[str] = None
    due_date: Optional[datetime] = None
    display_order: Optional[int] = None


class ChecklistItemResponse(BaseModel):
    """체크리스트 항목 응답 스키마"""
    id: str
    checklist_id: str
    task_id: str
    content: str
    is_checked: bool
    assignee_id: Optional[str] = None
    due_date: Optional[datetime] = None
    display_order: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ChecklistCreate(BaseModel):
    """체크리스트 생성 요청 스키마"""
    task_id: str
    title: str = "Checklist"


class ChecklistUpdate(BaseModel):
    """체크리스트 수정 요청 스키마"""
    title: str


class ChecklistResponse(BaseModel):
    """체크리스트 응답 스키마 (항목 포함)"""
    id: str
    task_id: str
    title: str
    created_by: str
    items: List[ChecklistItemResponse] = []
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
