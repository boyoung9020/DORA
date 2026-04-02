"""
프로젝트 관리 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
import asyncio
from app.database import get_db
from app.models.project import Project
from app.models.user import User
from app.models.workspace import WorkspaceMember
from app.schemas.project import ProjectCreate, ProjectUpdate, ProjectResponse
from app.utils.dependencies import get_current_user
from app.utils.notifications import notify_project_member_added
from app.routers.websocket import manager

router = APIRouter()


def _is_workspace_member(db: Session, workspace_id: str, user_id: str) -> bool:
    if not workspace_id:
        return True  # workspace 미설정 프로젝트는 제한 없음 (기존 데이터 호환)
    return db.query(WorkspaceMember).filter(
        WorkspaceMember.workspace_id == workspace_id,
        WorkspaceMember.user_id == user_id
    ).first() is not None


def _is_project_pm(project: Project, user: User) -> bool:
    """프로젝트 PM 여부: 프로젝트 생성자이거나 시스템 관리자"""
    return project.creator_id == user.id or user.is_admin


@router.get("/", response_model=List[ProjectResponse])
async def get_all_projects(
    skip: int = Query(0, ge=0, description="건너뛸 항목 수"),
    limit: int = Query(100, ge=1, le=500, description="최대 항목 수"),
    workspace_id: Optional[str] = Query(None, description="워크스페이스 ID 필터"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로젝트 목록 가져오기 (관리자: 전체, 일반유저: 본인 소속만)"""
    if current_user.is_admin:
        query = db.query(Project)
    else:
        query = db.query(Project).filter(
            Project.team_member_ids.any(current_user.id)
        )

    if workspace_id:
        query = query.filter(Project.workspace_id == workspace_id)

    projects = query.offset(skip).limit(limit).all()
    return projects


@router.get("/{project_id}", response_model=ProjectResponse)
async def get_project(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """특정 프로젝트 정보 가져오기"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )
    if not current_user.is_admin:
        if current_user.id != project.creator_id and current_user.id not in (project.team_member_ids or []):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="이 프로젝트에 접근 권한이 없습니다"
            )
    return project


@router.post("/", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
async def create_project(
    project_data: ProjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """새 프로젝트 생성 - 워크스페이스 멤버 누구나 가능, 생성자가 PM이 됨"""
    # workspace_id가 있으면 해당 워크스페이스 멤버인지 확인
    if project_data.workspace_id and not _is_workspace_member(db, project_data.workspace_id, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="해당 워크스페이스의 멤버만 프로젝트를 생성할 수 있습니다"
        )

    new_project = Project(
        id=str(uuid.uuid4()),
        name=project_data.name,
        description=project_data.description,
        color=project_data.color,
        team_member_ids=[current_user.id],  # 생성자를 자동으로 팀원에 추가
        workspace_id=project_data.workspace_id,
        creator_id=current_user.id,         # 생성자 = 프로젝트 PM
    )

    db.add(new_project)
    db.commit()
    db.refresh(new_project)

    asyncio.create_task(manager.broadcast({
        "type": "project_created",
        "data": {"project_id": new_project.id, "project_name": new_project.name}
    }, exclude_user_id=current_user.id))

    return new_project


@router.patch("/{project_id}", response_model=ProjectResponse)
async def update_project(
    project_id: str,
    project_data: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로젝트 정보 수정 (프로젝트 PM 또는 관리자만)"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )

    if not _is_project_pm(project, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프로젝트 PM 또는 관리자만 수정할 수 있습니다"
        )

    if project_data.team_member_ids is not None:
        project.team_member_ids = project_data.team_member_ids
    if project_data.name is not None:
        project.name = project_data.name
    if project_data.description is not None:
        project.description = project_data.description
    if project_data.color is not None:
        project.color = project_data.color

    db.commit()
    db.refresh(project)

    asyncio.create_task(manager.broadcast({
        "type": "project_updated",
        "data": {"project_id": project.id}
    }, exclude_user_id=current_user.id))

    return project


@router.delete("/{project_id}")
async def delete_project(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로젝트 삭제 (프로젝트 PM 또는 관리자만)"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )

    if not _is_project_pm(project, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프로젝트 PM 또는 관리자만 삭제할 수 있습니다"
        )

    db.delete(project)
    db.commit()
    return {"message": "프로젝트가 삭제되었습니다"}


@router.post("/{project_id}/members/{user_id}")
async def add_team_member(
    project_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로젝트에 팀원 추가 (프로젝트 PM 또는 관리자만, 같은 워크스페이스 멤버만 초대 가능)"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )

    if not _is_project_pm(project, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프로젝트 PM 또는 관리자만 팀원을 추가할 수 있습니다"
        )

    # 같은 워크스페이스 멤버인지 확인
    if project.workspace_id and not _is_workspace_member(db, project.workspace_id, user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="같은 워크스페이스 멤버만 프로젝트에 초대할 수 있습니다"
        )

    if user_id not in project.team_member_ids:
        project.team_member_ids = list(project.team_member_ids) + [user_id]
        db.commit()
        db.refresh(project)

        notify_project_member_added(db, project, user_id, current_user)

        asyncio.create_task(manager.send_to_users({
            "type": "team_member_added",
            "data": {"project_id": project.id, "user_id": user_id}
        }, project.team_member_ids, exclude_user_id=current_user.id))

    return project


@router.delete("/{project_id}/members/{user_id}")
async def remove_team_member(
    project_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로젝트에서 팀원 제거 (프로젝트 PM 또는 관리자만)"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )

    if not _is_project_pm(project, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프로젝트 PM 또는 관리자만 팀원을 제거할 수 있습니다"
        )

    if user_id in project.team_member_ids:
        project.team_member_ids = [uid for uid in project.team_member_ids if uid != user_id]
        db.commit()
        db.refresh(project)

    return project
