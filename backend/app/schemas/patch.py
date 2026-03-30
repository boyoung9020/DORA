"""Patch history schemas."""

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class PatchCreate(BaseModel):
    project_id: str
    site: str
    patch_date: date
    version: str = ""
    content: str


class PatchResponse(BaseModel):
    id: str
    project_id: str
    site: str
    patch_date: date
    version: str
    content: str
    created_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

