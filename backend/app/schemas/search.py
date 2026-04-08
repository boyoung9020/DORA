"""Search response schemas."""

from typing import List

from pydantic import BaseModel

from app.schemas.comment import CommentResponse
from app.schemas.task import TaskResponse


class SearchResponse(BaseModel):
    query: str
    tasks: List[TaskResponse]
    comments: List[CommentResponse]
    task_total: int = 0
    has_more: bool = False
