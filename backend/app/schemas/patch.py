"""Patch history schemas."""

from datetime import date, datetime
from typing import Any, List, Optional

from pydantic import BaseModel


class PatchCreate(BaseModel):
    project_id: str
    site: str
    patch_date: date
    version: str = ""
    content: str
    assignee: Optional[str] = None
    git_tag: Optional[str] = None


class PatchUpdate(BaseModel):
    site: Optional[str] = None
    patch_date: Optional[date] = None
    version: Optional[str] = None
    content: Optional[str] = None
    steps: Optional[List[Any]] = None
    test_items: Optional[List[Any]] = None
    status: Optional[str] = None
    notes: Optional[str] = None
    note_image_urls: Optional[List[str]] = None
    assignee: Optional[str] = None


class PatchResponse(BaseModel):
    id: str
    project_id: str
    site: str
    patch_date: date
    version: str
    content: str
    steps: List[Any] = []
    test_items: List[Any] = []
    status: str = "pending"
    notes: str = ""
    note_image_urls: List[str] = []
    assignee: Optional[str] = None
    git_tag: Optional[str] = None
    created_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
