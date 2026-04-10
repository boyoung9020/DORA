"""Router for site detail management (server/DB/service info per project site)."""

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.site_detail import SiteDetail
from app.models.project_site import ProjectSite
from app.models.task import Task
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
    accessible_ids = set(_accessible_project_ids(db, current_user))
    all_sites = (
        db.query(SiteDetail)
        .order_by(SiteDetail.name.asc(), SiteDetail.created_at.asc())
        .all()
    )
    # 접근 가능한 프로젝트와 연결된 사이트만 반환
    if project_id:
        _get_project_or_403(db, project_id, current_user)
        sites = [s for s in all_sites if project_id in (s.project_ids or [])]
    else:
        sites = [s for s in all_sites if any(pid in accessible_ids for pid in (s.project_ids or []))]
    return sites


@router.post("/", response_model=SiteDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_site_detail(
    body: SiteDetailCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_project_or_403(db, body.project_id, current_user)

    # 같은 이름의 사이트가 이미 존재하면 project_id만 연결
    existing = db.query(SiteDetail).filter(SiteDetail.name == body.name).first()
    if existing:
        ids: list = list(existing.project_ids or [])
        if body.project_id not in ids:
            ids.append(body.project_id)
            existing.project_ids = ids
            db.commit()
            db.refresh(existing)
        return existing

    site = SiteDetail(
        id=str(uuid.uuid4()),
        project_ids=[body.project_id],
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
    # 연결된 프로젝트 중 하나라도 접근 가능하면 편집 허용
    accessible_ids = set(_accessible_project_ids(db, current_user))
    if not any(pid in accessible_ids for pid in (site.project_ids or [])):
        raise HTTPException(status_code=403, detail="접근 권한이 없습니다.")

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
    if body.project_ids is not None:
        site.project_ids = body.project_ids

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
    accessible_ids = set(_accessible_project_ids(db, current_user))
    if not any(pid in accessible_ids for pid in (site.project_ids or [])):
        raise HTTPException(status_code=403, detail="접근 권한이 없습니다.")
    site_name = site.name
    remaining_pids = [pid for pid in (site.project_ids or []) if pid in accessible_ids]
    all_pids = list(site.project_ids or [])
    non_accessible_pids = [pid for pid in all_pids if pid not in accessible_ids]

    if non_accessible_pids:
        # 접근 불가 프로젝트가 있으면 접근 가능한 프로젝트 연결만 해제
        new_pids = non_accessible_pids
        site.project_ids = new_pids
        # 접근 가능한 프로젝트들의 project_sites 및 task.site_tags만 정리
        for pid in remaining_pids:
            for t in db.query(Task).filter(Task.project_id == pid).all():
                tags = list(t.site_tags or [])
                if site_name in tags:
                    t.site_tags = [x for x in tags if x != site_name]
            ps_row = db.query(ProjectSite).filter(
                ProjectSite.project_id == pid, ProjectSite.name == site_name
            ).first()
            if ps_row:
                db.delete(ps_row)
    else:
        # 모든 프로젝트가 접근 가능 → SiteDetail 전체 삭제
        db.delete(site)
        for ps in db.query(ProjectSite).filter(ProjectSite.name == site_name).all():
            db.delete(ps)
        # 연결된 모든 프로젝트의 task.site_tags 정리
        for pid in all_pids:
            for t in db.query(Task).filter(Task.project_id == pid).all():
                tags = list(t.site_tags or [])
                if site_name in tags:
                    t.site_tags = [x for x in tags if x != site_name]

    db.commit()
