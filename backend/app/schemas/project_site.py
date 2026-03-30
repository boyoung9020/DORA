"""Project site schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class ProjectSiteCreate(BaseModel):
    project_id: str
    name: str


class ProjectSiteResponse(BaseModel):
    id: str
    project_id: str
    name: str
    created_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

