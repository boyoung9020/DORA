"""AI summary response schema."""

from datetime import datetime

from pydantic import BaseModel


class AISummaryResponse(BaseModel):
    summary: str
    generated_at: datetime
