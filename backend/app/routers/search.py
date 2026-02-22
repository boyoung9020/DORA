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


@router.get("/", response_model=SearchResponse)
async def search(
    q: str = Query(..., min_length=1),
    workspace_id: Optional[str] = Query(None),
    project_id: Optional[str] = Query(None),
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
    tasks = task_query.order_by(Task.updated_at.desc()).limit(20).all()

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
        .limit(20)
        .all()
    )

    # include comments on searched tasks for context if no direct match is enough
    if len(comments) < 20 and task_ids:
        more_comments = (
            db.query(Comment)
            .filter(Comment.task_id.in_(task_ids))
            .order_by(Comment.created_at.desc())
            .limit(20 - len(comments))
            .all()
        )
        existing_ids = {c.id for c in comments}
        comments.extend([c for c in more_comments if c.id not in existing_ids])

    return SearchResponse(query=q, tasks=tasks, comments=comments)
