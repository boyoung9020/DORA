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
from app.schemas.project import ProjectCreate, ProjectUpdate, ProjectResponse
from app.utils.dependencies import get_current_user, get_current_admin_or_pm_user
from app.utils.notifications import notify_project_member_added
from app.routers.websocket import manager

router = APIRouter()


@router.get("/", response_model=List[ProjectResponse])
async def get_all_projects(
    skip: int = Query(0, ge=0, description="건너뛸 항목 수"),
    limit: int = Query(100, ge=1, le=500, description="최대 항목 수"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로젝트 목록 가져오기 (관리자/PM: 전체, 일반유저: 본인 소속만)"""
    if current_user.is_admin or current_user.is_pm:
        query = db.query(Project)
    else:
        query = db.query(Project).filter(
            Project.team_member_ids.any(current_user.id)
        )
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
    # 일반 유저는 소속 프로젝트만 조회 가능
    if not current_user.is_admin and not current_user.is_pm:
        if current_user.id not in (project.team_member_ids or []):
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
    """새 프로젝트 생성"""
    new_project = Project(
        id=str(uuid.uuid4()),
        name=project_data.name,
        description=project_data.description,
        color=project_data.color,
        team_member_ids=[]
    )
    
    db.add(new_project)
    db.commit()
    db.refresh(new_project)
    
    # 모든 클라이언트에게 프로젝트 생성 이벤트 브로드캐스트
    asyncio.create_task(manager.broadcast({
        "type": "project_created",
        "data": {
            "project_id": new_project.id,
            "project_name": new_project.name,
        }
    }, exclude_user_id=current_user.id))
    
    return new_project


@router.patch("/{project_id}", response_model=ProjectResponse)
async def update_project(
    project_id: str,
    project_data: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로젝트 정보 수정"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )
    
    # team_member_ids 업데이트는 관리자 또는 PM 권한 필요
    if project_data.team_member_ids is not None:
        if not current_user.is_admin and not current_user.is_pm:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="팀원 할당은 관리자 또는 PM 권한이 필요합니다"
            )
        project.team_member_ids = project_data.team_member_ids
    
    # 업데이트할 필드만 변경
    if project_data.name is not None:
        project.name = project_data.name
    if project_data.description is not None:
        project.description = project_data.description
    if project_data.color is not None:
        project.color = project_data.color
    
    db.commit()
    db.refresh(project)
    
    # 모든 클라이언트에게 프로젝트 업데이트 이벤트 브로드캐스트
    asyncio.create_task(manager.broadcast({
        "type": "project_updated",
        "data": {
            "project_id": project.id,
        }
    }, exclude_user_id=current_user.id))
    
    return project


@router.delete("/{project_id}")
async def delete_project(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로젝트 삭제"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )
    
    db.delete(project)
    db.commit()
    return {"message": "프로젝트가 삭제되었습니다"}


@router.post("/{project_id}/members/{user_id}")
async def add_team_member(
    project_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_or_pm_user)
):
    """프로젝트에 팀원 추가 (관리자 또는 PM 권한 필요)"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )
    
    if user_id not in project.team_member_ids:
        project.team_member_ids = list(project.team_member_ids) + [user_id]
        db.commit()
        db.refresh(project)
        
        # 알림 생성
        notify_project_member_added(db, project, user_id, current_user)
        
        # 프로젝트 팀원에게만 이벤트 전송 (타겟 전송)
        asyncio.create_task(manager.send_to_users({
            "type": "team_member_added",
            "data": {
                "project_id": project.id,
                "user_id": user_id,
            }
        }, project.team_member_ids, exclude_user_id=current_user.id))
    
    return project


@router.delete("/{project_id}/members/{user_id}")
async def remove_team_member(
    project_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_or_pm_user)
):
    """프로젝트에서 팀원 제거 (관리자 또는 PM 권한 필요)"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="프로젝트를 찾을 수 없습니다"
        )
    
    if user_id in project.team_member_ids:
        project.team_member_ids = [id for id in project.team_member_ids if id != user_id]
        db.commit()
        db.refresh(project)
    
    return project

