"""
프로젝트 관리 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import uuid
from app.database import get_db
from app.models.project import Project
from app.models.user import User
from app.schemas.project import ProjectCreate, ProjectUpdate, ProjectResponse
from app.utils.dependencies import get_current_user, get_current_admin_or_pm_user

router = APIRouter()


@router.get("/", response_model=List[ProjectResponse])
async def get_all_projects(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """모든 프로젝트 목록 가져오기"""
    projects = db.query(Project).all()
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

