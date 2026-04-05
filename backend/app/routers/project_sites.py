"""Project sites API router."""

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.project import Project
from app.models.project_site import ProjectSite
from app.models.site_detail import SiteDetail
from app.models.task import Task
from app.models.user import User
from app.schemas.project_site import ProjectSiteCreate, ProjectSiteResponse
from app.utils.dependencies import get_current_user


router = APIRouter()


def _get_project_or_403(db: Session, project_id: str, user: User) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="프로젝트를 찾을 수 없습니다")
    if not user.is_admin and user.id != project.creator_id and user.id not in (project.team_member_ids or []):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="이 프로젝트에 접근 권한이 없습니다")
    return project


@router.get("/", response_model=List[ProjectSiteResponse])
async def list_project_sites(
    project_id: str = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_project_or_403(db, project_id, current_user)
    rows = (
        db.query(ProjectSite)
        .filter(ProjectSite.project_id == project_id)
        .order_by(ProjectSite.name.asc())
        .all()
    )
    names_ps = {r.name for r in rows}
    # 사이트 상세(site_details)에서만 추가된 항목은 project_sites 행이 없음 → 패치/태스크 UI에서 동일 목록 제공
    detail_rows = (
        db.query(SiteDetail)
        .order_by(SiteDetail.name.asc(), SiteDetail.created_at.asc())
        .all()
    )
    extra: List[ProjectSiteResponse] = []
    for s in detail_rows:
        if project_id not in (s.project_ids or []):
            continue
        if s.name in names_ps:
            continue
        extra.append(
            ProjectSiteResponse(
                id=s.id,
                project_id=project_id,
                name=s.name,
                created_by=None,
                created_at=s.created_at,
                updated_at=s.updated_at,
            )
        )
    combined = [ProjectSiteResponse.model_validate(r) for r in rows] + extra
    combined.sort(key=lambda x: (x.name.lower(), x.created_at))
    return combined


@router.post("/", response_model=ProjectSiteResponse, status_code=status.HTTP_201_CREATED)
async def create_project_site(
    body: ProjectSiteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_project_or_403(db, body.project_id, current_user)
    name = (body.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="name is required")

    existing = (
        db.query(ProjectSite)
        .filter(ProjectSite.project_id == body.project_id, ProjectSite.name == name)
        .first()
    )
    if existing:
        return existing

    row = ProjectSite(
        id=str(uuid.uuid4()),
        project_id=body.project_id,
        name=name,
        created_by=current_user.id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    # site_details 동기 생성: 같은 이름 사이트가 이미 있으면 project_ids에 추가, 없으면 신규 생성
    existing_detail = db.query(SiteDetail).filter(SiteDetail.name == name).first()
    if existing_detail:
        ids: list = list(existing_detail.project_ids or [])
        if body.project_id not in ids:
            ids.append(body.project_id)
            existing_detail.project_ids = ids
            db.commit()
    else:
        db.add(SiteDetail(
            id=row.id,
            project_ids=[body.project_id],
            name=name,
            description="",
            servers=[],
            databases=[],
            services=[],
        ))
        db.commit()

    return row


@router.delete("/{site_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_project_site(
    site_id: str,
    project_id: Optional[str] = Query(
        None,
        description="site_details 전용 항목 삭제 시 어느 프로젝트 연결을 해제할지 (다중 연결 사이트)",
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    row = db.query(ProjectSite).filter(ProjectSite.id == site_id).first()
    if row:
        _get_project_or_403(db, row.project_id, current_user)

        # 삭제 시, 해당 사이트가 할당된 태스크들의 site_tags도 제거(단일값 운용 기준)
        tasks = db.query(Task).filter(Task.project_id == row.project_id).all()
        for t in tasks:
            tags = list(t.site_tags or [])
            if row.name in tags:
                t.site_tags = [x for x in tags if x != row.name]

        # site_details에서도 삭제
        detail = db.query(SiteDetail).filter(SiteDetail.id == site_id).first()
        if detail:
            db.delete(detail)

        db.delete(row)
        db.commit()
        return

    # project_sites 행 없이 site_details에만 있는 경우 (사이트 상세에서만 생성)
    detail = db.query(SiteDetail).filter(SiteDetail.id == site_id).first()
    if not detail:
        raise HTTPException(status_code=404, detail="사이트를 찾을 수 없습니다")

    target_pid = project_id
    pids = list(detail.project_ids or [])
    if not target_pid:
        if len(pids) == 1:
            target_pid = pids[0]
        else:
            raise HTTPException(
                status_code=400,
                detail="이 사이트는 여러 프로젝트에 연결되어 있습니다. project_id 쿼리를 지정하세요.",
            )
    if target_pid not in pids:
        raise HTTPException(status_code=404, detail="사이트를 찾을 수 없습니다")

    _get_project_or_403(db, target_pid, current_user)

    tasks = db.query(Task).filter(Task.project_id == target_pid).all()
    for t in tasks:
        tags = list(t.site_tags or [])
        if detail.name in tags:
            t.site_tags = [x for x in tags if x != detail.name]

    ps_same = (
        db.query(ProjectSite)
        .filter(ProjectSite.project_id == target_pid, ProjectSite.name == detail.name)
        .first()
    )
    if ps_same:
        db.delete(ps_same)

    remaining = [x for x in pids if x != target_pid]
    if not remaining:
        db.delete(detail)
        for ps in db.query(ProjectSite).filter(ProjectSite.name == detail.name).all():
            db.delete(ps)
    else:
        detail.project_ids = remaining

    db.commit()

