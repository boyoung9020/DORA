"""Global search API router."""

from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.comment import Comment
from app.models.project import Project
from app.models.task import Task
from app.models.user import User
from app.schemas.search import SearchResponse
from app.utils.dependencies import get_current_user

router = APIRouter()


TASK_SORT_COLUMNS = {
    "updated_at": Task.updated_at,
    "created_at": Task.created_at,
    "title": Task.title,
}


@router.get("/", response_model=SearchResponse)
async def search(
    q: str = Query(..., min_length=1),
    workspace_id: Optional[str] = Query(None),
    project_id: Optional[str] = Query(None),
    task_status: Optional[str] = Query(None, description="태스크 상태 필터 (예: backlog, in_progress)"),
    task_priority: Optional[str] = Query(None, description="태스크 우선순위 필터 (예: high, medium)"),
    sort_by: Optional[str] = Query("updated_at", description="정렬 기준 (updated_at, created_at, title)"),
    sort_order: Optional[str] = Query("desc", description="정렬 방향 (asc, desc)"),
    skip: int = Query(0, ge=0, description="건너뛸 항목 수"),
    limit: int = Query(30, ge=1, le=100, description="가져올 항목 수"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    like_query = f"%{q}%"

    task_query = db.query(Task).join(Project, Project.id == Task.project_id)
    if project_id:
        task_query = task_query.filter(Task.project_id == project_id)
    if workspace_id:
        task_query = task_query.filter(Project.workspace_id == workspace_id)

    if not current_user.is_admin and not current_user.is_pm:
        task_query = task_query.filter(Project.team_member_ids.any(current_user.id))

    task_query = task_query.filter(
        or_(
            Task.title.ilike(like_query),
            Task.description.ilike(like_query),
            Task.detail.ilike(like_query),
        )
    )

    # 상태/우선순위 필터
    if task_status:
        task_query = task_query.filter(Task.status == task_status)
    if task_priority:
        task_query = task_query.filter(Task.priority == task_priority)

    # 정렬
    sort_col = TASK_SORT_COLUMNS.get(sort_by, Task.updated_at)
    if sort_order == "asc":
        task_query = task_query.order_by(sort_col.asc())
    else:
        task_query = task_query.order_by(sort_col.desc())

    task_total = task_query.count()
    tasks = task_query.offset(skip).limit(limit).all()

    task_ids = [t.id for t in tasks]
    comment_query = db.query(Comment).join(Task, Task.id == Comment.task_id).join(
        Project, Project.id == Task.project_id
    )
    if project_id:
        comment_query = comment_query.filter(Task.project_id == project_id)
    if workspace_id:
        comment_query = comment_query.filter(Project.workspace_id == workspace_id)

    if not current_user.is_admin and not current_user.is_pm:
        comment_query = comment_query.filter(Project.team_member_ids.any(current_user.id))

    comments = (
        comment_query.filter(Comment.content.ilike(like_query))
        .order_by(Comment.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    # include comments on searched tasks for context if no direct match is enough
    if len(comments) < limit and task_ids:
        more_comments = (
            db.query(Comment)
            .filter(Comment.task_id.in_(task_ids))
            .order_by(Comment.created_at.desc())
            .limit(limit - len(comments))
            .all()
        )
        existing_ids = {c.id for c in comments}
        comments.extend([c for c in more_comments if c.id not in existing_ids])

    return SearchResponse(
        query=q,
        tasks=tasks,
        comments=comments,
        task_total=task_total,
        has_more=task_total > (skip + limit),
    )
