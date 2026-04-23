"""
회의록 관련 Pydantic 스키마
"""
from pydantic import BaseModel
from datetime import datetime, date
from typing import Optional, List


class MeetingMinutesBase(BaseModel):
    """회의록 기본 스키마"""
    title: str
    content: str = ""
    category: str = ""
    meeting_date: date
    attendee_ids: List[str] = []


class MeetingMinutesCreate(MeetingMinutesBase):
    """회의록 생성 요청 스키마"""
    workspace_id: str


class MeetingMinutesUpdate(BaseModel):
    """회의록 수정 요청 스키마"""
    title: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    meeting_date: Optional[date] = None
    attendee_ids: Optional[List[str]] = None


class MeetingMinutesResponse(MeetingMinutesBase):
    """회의록 응답 스키마"""
    id: str
    workspace_id: str
    creator_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
