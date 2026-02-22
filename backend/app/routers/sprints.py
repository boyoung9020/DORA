"""Sprint API router."""

import asyncio
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.project import Project
from app.models.sprint import Sprint, SprintStatus
from app.models.task import Task
from app.models.user import User
from app.routers.websocket import manager
from app.schemas.sprint import SprintCreate, SprintResponse, SprintUpdate
from app.utils.dependencies import get_current_user

router = APIRouter()


def _is_project_member(project: Project, user: User) -> bool:
    if user.is_admin or user.is_pm:
        return True
    return user.id in (project.team_member_ids or [])


def _safe_unique_ids(values: Optional[List[str]]) -> List[str]:
    if not values:
        return []
    return list(dict.fromkeys(values))


async def _broadcast_sprint_event(db: Session, sprint: Sprint, event_type: str, actor_id: str):
    project = db.query(Project).filter(Project.id == sprint.project_id).first()
    target_users = list(project.team_member_ids) if project and project.team_member_ids else []
    asyncio.create_task(
        manager.send_to_users(
            {
                "type": event_type,
                "data": {
                    "sprint_id": sprint.id,
                    "project_id": sprint.project_id,
                    "status": sprint.status.value,
                },
            },
            target_users,
            exclude_user_id=actor_id,
        )
    )


def _sync_task_links(db: Session, sprint: Sprint, desired_task_ids: List[str]):
    desired_set = set(_safe_unique_ids(desired_task_ids))
    current_set = set(sprint.task_ids or [])

    to_add = desired_set - current_set
    to_remove = current_set - desired_set

    if to_add:
        tasks_to_add = (
            db.query(Task)
            .filter(Task.id.in_(list(to_add)), Task.project_id == sprint.project_id)
            .all()
        )
        for task in tasks_to_add:
            task.sprint_id = sprint.id

    if to_remove:
        tasks_to_remove = (
            db.query(Task)
            .filter(Task.id.in_(list(to_remove)), Task.sprint_id == sprint.id)
            .all()
        )
        for task in tasks_to_remove:
            task.sprint_id = None

    sprint.task_ids = list(desired_set)


@router.get("/", response_model=List[SprintResponse])
async def get_sprints(
    project_id: Optional[str] = Query(None, description="project id"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Sprint)
    if project_id:
        query = query.filter(Sprint.project_id == project_id)

    sprints = query.order_by(Sprint.created_at.desc()).all()
    if current_user.is_admin or current_user.is_pm:
        return sprints

    visible_project_ids = {
        p.id
        for p in db.query(Project).filter(Project.team_member_ids.any(current_user.id)).all()
    }
    return [s for s in sprints if s.project_id in visible_project_ids]


@router.post("/", response_model=SprintResponse, status_code=status.HTTP_201_CREATED)
async def create_sprint(
    sprint_data: SprintCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == sprint_data.project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="프로젝트를 찾을 수 없습니다")
    if not _is_project_member(project, current_user):
        raise HTTPException(status_code=403, detail="스프린트를 생성할 권한이 없습니다")

    sprint = Sprint(
        id=str(uuid.uuid4()),
        project_id=sprint_data.project_id,
        name=sprint_data.name,
        goal=sprint_data.goal,
        start_date=sprint_data.start_date,
        end_date=sprint_data.end_date,
        status=SprintStatus.PLANNING,
        task_ids=[],
    )
    db.add(sprint)
    db.commit()
    db.refresh(sprint)

    await _broadcast_sprint_event(db, sprint, "sprint_created", current_user.id)
    return sprint


@router.patch("/{sprint_id}", response_model=SprintResponse)
async def update_sprint(
    sprint_id: str,
    sprint_data: SprintUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sprint = db.query(Sprint).filter(Sprint.id == sprint_id).first()
    if not sprint:
        raise HTTPException(status_code=404, detail="스프린트를 찾을 수 없습니다")

    project = db.query(Project).filter(Project.id == sprint.project_id).first()
    if not project or not _is_project_member(project, current_user):
        raise HTTPException(status_code=403, detail="스프린트를 수정할 권한이 없습니다")

    if sprint_data.name is not None:
        sprint.name = sprint_data.name
    if sprint_data.goal is not None:
        sprint.goal = sprint_data.goal
    if sprint_data.start_date is not None:
        sprint.start_date = sprint_data.start_date
    if sprint_data.end_date is not None:
        sprint.end_date = sprint_data.end_date
    if sprint_data.status is not None:
        sprint.status = sprint_data.status
    if sprint_data.task_ids is not None:
        _sync_task_links(db, sprint, sprint_data.task_ids)

    db.commit()
    db.refresh(sprint)

    await _broadcast_sprint_event(db, sprint, "sprint_updated", current_user.id)
    return sprint


@router.delete("/{sprint_id}")
async def delete_sprint(
    sprint_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sprint = db.query(Sprint).filter(Sprint.id == sprint_id).first()
    if not sprint:
        raise HTTPException(status_code=404, detail="스프린트를 찾을 수 없습니다")

    project = db.query(Project).filter(Project.id == sprint.project_id).first()
    if not project or not _is_project_member(project, current_user):
        raise HTTPException(status_code=403, detail="스프린트를 삭제할 권한이 없습니다")

    db.query(Task).filter(Task.sprint_id == sprint.id).update({"sprint_id": None})
    db.delete(sprint)
    db.commit()
    return {"message": "스프린트가 삭제되었습니다"}


@router.post("/{sprint_id}/tasks/{task_id}", response_model=SprintResponse)
async def add_task_to_sprint(
    sprint_id: str,
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sprint = db.query(Sprint).filter(Sprint.id == sprint_id).first()
    if not sprint:
        raise HTTPException(status_code=404, detail="스프린트를 찾을 수 없습니다")

    project = db.query(Project).filter(Project.id == sprint.project_id).first()
    if not project or not _is_project_member(project, current_user):
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    task = db.query(Task).filter(Task.id == task_id, Task.project_id == sprint.project_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="태스크를 찾을 수 없습니다")

    task_ids = _safe_unique_ids(sprint.task_ids)
    if task_id not in task_ids:
        task_ids.append(task_id)
    _sync_task_links(db, sprint, task_ids)
    db.commit()
    db.refresh(sprint)

    await _broadcast_sprint_event(db, sprint, "sprint_updated", current_user.id)
    return sprint


@router.delete("/{sprint_id}/tasks/{task_id}", response_model=SprintResponse)
async def remove_task_from_sprint(
    sprint_id: str,
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sprint = db.query(Sprint).filter(Sprint.id == sprint_id).first()
    if not sprint:
        raise HTTPException(status_code=404, detail="스프린트를 찾을 수 없습니다")

    project = db.query(Project).filter(Project.id == sprint.project_id).first()
    if not project or not _is_project_member(project, current_user):
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    task_ids = [tid for tid in (sprint.task_ids or []) if tid != task_id]
    _sync_task_links(db, sprint, task_ids)
    db.commit()
    db.refresh(sprint)

    await _broadcast_sprint_event(db, sprint, "sprint_updated", current_user.id)
    return sprint
