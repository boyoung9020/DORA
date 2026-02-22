"""Sprint schemas (Pydantic)."""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel

from app.models.sprint import SprintStatus


class SprintCreate(BaseModel):
    project_id: str
    name: str
    goal: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None


class SprintUpdate(BaseModel):
    name: Optional[str] = None
    goal: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    status: Optional[SprintStatus] = None
    task_ids: Optional[List[str]] = None


class SprintResponse(BaseModel):
    id: str
    project_id: str
    name: str
    goal: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    status: SprintStatus
    task_ids: List[str] = []
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
