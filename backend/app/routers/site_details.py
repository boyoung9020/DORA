"""Router for site detail management (server/DB/service info per project site)."""

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.site_detail import SiteDetail
from app.models.user import User
from app.models.project import Project
from app.schemas.site_detail import SiteDetailCreate, SiteDetailResponse, SiteDetailUpdate
from app.utils.dependencies import get_current_user

router = APIRouter()


def _can_access_project(project: Project, current_user: User) -> bool:
    """유저가 해당 프로젝트에 접근 가능한지 확인 (관리자 OR 팀원 OR 생성자)."""
    if current_user.is_admin:
        return True
    if project.creator_id == current_user.id:
        return True
    return current_user.id in (project.team_member_ids or [])


def _get_project_or_403(db: Session, project_id: str, current_user: User) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="프로젝트를 찾을 수 없습니다.")
    if not _can_access_project(project, current_user):
        raise HTTPException(status_code=403, detail="접근 권한이 없습니다.")
    return project


def _accessible_project_ids(db: Session, current_user: User) -> List[str]:
    """현재 유저가 접근 가능한 모든 프로젝트 ID 반환."""
    all_projects = db.query(Project).all()
    return [
        p.id for p in all_projects
        if _can_access_project(p, current_user)
    ]


@router.get("/", response_model=List[SiteDetailResponse])
async def list_site_details(
    project_id: Optional[str] = Query(None, description="프로젝트 ID (미입력 시 전체)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if project_id:
        _get_project_or_403(db, project_id, current_user)
        sites = (
            db.query(SiteDetail)
            .filter(SiteDetail.project_id == project_id)
            .order_by(SiteDetail.name.asc(), SiteDetail.created_at.asc())
            .all()
        )
    else:
        project_ids = _accessible_project_ids(db, current_user)
        sites = (
            db.query(SiteDetail)
            .filter(SiteDetail.project_id.in_(project_ids))
            .order_by(SiteDetail.name.asc(), SiteDetail.created_at.asc())
            .all()
        )
    return sites


@router.post("/", response_model=SiteDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_site_detail(
    body: SiteDetailCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_project_or_403(db, body.project_id, current_user)
    site = SiteDetail(
        id=str(uuid.uuid4()),
        project_id=body.project_id,
        name=body.name,
        description=body.description,
        servers=body.servers,
        databases=body.databases,
        services=body.services,
    )
    db.add(site)
    db.commit()
    db.refresh(site)
    return site


@router.patch("/{site_id}", response_model=SiteDetailResponse)
async def update_site_detail(
    site_id: str,
    body: SiteDetailUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    site = db.query(SiteDetail).filter(SiteDetail.id == site_id).first()
    if not site:
        raise HTTPException(status_code=404, detail="사이트를 찾을 수 없습니다.")
    _get_project_or_403(db, site.project_id, current_user)

    if body.name is not None:
        site.name = body.name
    if body.description is not None:
        site.description = body.description
    if body.servers is not None:
        site.servers = body.servers
    if body.databases is not None:
        site.databases = body.databases
    if body.services is not None:
        site.services = body.services

    db.commit()
    db.refresh(site)
    return site


@router.delete("/{site_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_site_detail(
    site_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    site = db.query(SiteDetail).filter(SiteDetail.id == site_id).first()
    if not site:
        raise HTTPException(status_code=404, detail="사이트를 찾을 수 없습니다.")
    _get_project_or_403(db, site.project_id, current_user)
    db.delete(site)
    db.commit()
