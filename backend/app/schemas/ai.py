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
    # 현재 워크스페이스 (AI 요약과 동일하게 범위 제한)
    workspace_id: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    format: str = "docs"  # "docs" or "md"
    # 비어 있지 않으면: 선택한 user_id 중 하나라도 할당된 작업만 (작업 테이블 담당자 필터와 동일 개념)
    assignee_ids: Optional[List[str]] = None
    # assignee_ids가 비어 있을 때만 사용 (하위 호환). mine|others|all
    task_scope: str = "all"


class AIExportResponse(BaseModel):
    report: str
    generated_at: datetime
