"""
request-issue 앱 연동 API 라우터
외부 앱에서 Sync에 태스크(이슈)를 등록하기 위한 엔드포인트
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid

from app.database import get_db
from app.models.task import Task, TaskStatus, TaskPriority
from app.models.user import User
from app.models.project import Project
from app.utils.dependencies import get_current_user
from pydantic import BaseModel

router = APIRouter()


# ── 스키마 ────────────────────────────────────────────────────────────────────

class IssueCreate(BaseModel):
    title: str
    project_id: str
    description: Optional[str] = ""
    priority: Optional[str] = None          # "p0" | "p1" | "p2" | "p3"
    status: Optional[str] = None            # "backlog" | "ready" | "inProgress" | "inReview" | "done"
    assigned_member_ids: Optional[List[str]] = []


# ── 엔드포인트 ────────────────────────────────────────────────────────────────

@router.get("/auth/verify")
async def verify_token(current_user: User = Depends(get_current_user)):
    """토큰 유효성 검증"""
    return {"valid": True, "user": current_user.username}


@router.get("/fields")
async def get_fields(_: User = Depends(get_current_user)):
    """태스크 생성에 사용 가능한 필드 목록 반환"""
    return {
        "fields": [
            {"id": "title", "name": "제목", "required": True, "type": "text"},
            {"id": "project_id", "name": "프로젝트 ID", "required": True, "type": "text"},
            {"id": "description", "name": "설명", "required": False, "type": "text"},
            {
                "id": "priority",
                "name": "우선순위",
                "required": False,
                "type": "select",
                "options": ["p0", "p1", "p2", "p3"],
            },
            {
                "id": "status",
                "name": "상태",
                "required": False,
                "type": "select",
                "options": ["backlog", "ready", "inProgress", "inReview", "done"],
            },
            {"id": "assigned_member_ids", "name": "담당자", "required": False, "type": "multi-select"},
        ]
    }


@router.post("/issues", status_code=status.HTTP_201_CREATED)
async def create_issue(
    issue: IssueCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """태스크(이슈) 1건 등록"""
    # 프로젝트 존재 + 접근 권한 검증
    project = db.query(Project).filter(Project.id == issue.project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="프로젝트를 찾을 수 없습니다")
    if not current_user.is_admin and current_user.id != project.creator_id and current_user.id not in (project.team_member_ids or []):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="이 프로젝트에 접근 권한이 없습니다")

    # priority 파싱
    priority = TaskPriority.P2
    if issue.priority:
        try:
            priority = TaskPriority(issue.priority)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"유효하지 않은 priority: {issue.priority}")

    # status 파싱
    task_status = TaskStatus.BACKLOG
    if issue.status:
        try:
            task_status = TaskStatus(issue.status)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"유효하지 않은 status: {issue.status}")

    try:
        new_task = Task(
            id=str(uuid.uuid4()),
            title=issue.title,
            description=issue.description or "",
            status=task_status,
            project_id=issue.project_id,
            priority=priority,
            assigned_member_ids=issue.assigned_member_ids or [],
            creator_id=current_user.id,
            comment_ids=[],
            detail_image_urls=[],
            document_links=[],
            site_tags=[],
            status_history=[],
            assignment_history=[],
            priority_history=[],
        )
        db.add(new_task)
        db.commit()
        db.refresh(new_task)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="태스크 생성에 실패했습니다")

    return {"id": new_task.id, "title": new_task.title, "url": ""}


@router.get("/members")
async def get_members(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """승인된 멤버 목록 반환"""
    users = db.query(User).filter(User.is_approved == True).all()
    return {"members": [{"id": u.id, "name": u.username} for u in users]}
