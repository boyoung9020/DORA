"""AI summary response schema."""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


class AISummaryResponse(BaseModel):
    summary: str
    generated_at: datetime


class AIExportRequest(BaseModel):
    title: str
    project_ids: Optional[List[str]] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    format: str = "docs"  # "docs" or "md"


class AIExportResponse(BaseModel):
    report: str
    generated_at: datetime
