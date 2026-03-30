"""Patch history API router."""

import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.patch import ProjectPatch
from app.models.project import Project
from app.models.user import User
from app.schemas.patch import PatchCreate, PatchResponse
from app.utils.dependencies import get_current_user


router = APIRouter()


def _get_project_or_403(db: Session, project_id: str, user: User) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="프로젝트를 찾을 수 없습니다")
    if not user.is_admin and user.id not in (project.team_member_ids or []):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="이 프로젝트에 접근 권한이 없습니다")
    return project


@router.get("/", response_model=List[PatchResponse])
async def list_patches(
    project_id: str = Query(..., description="프로젝트 ID"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_project_or_403(db, project_id, current_user)
    patches = (
        db.query(ProjectPatch)
        .filter(ProjectPatch.project_id == project_id)
        .order_by(ProjectPatch.patch_date.desc(), ProjectPatch.created_at.desc())
        .all()
    )
    return patches


@router.post("/", response_model=PatchResponse, status_code=status.HTTP_201_CREATED)
async def create_patch(
    body: PatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_project_or_403(db, body.project_id, current_user)

    site = (body.site or "").strip()
    content = (body.content or "").strip()
    version = (body.version or "").strip()

    if not site:
        raise HTTPException(status_code=400, detail="site is required")
    if not content:
        raise HTTPException(status_code=400, detail="content is required")

    patch = ProjectPatch(
        id=str(uuid.uuid4()),
        project_id=body.project_id,
        site=site,
        patch_date=body.patch_date,
        version=version,
        content=content,
        created_by=current_user.id,
    )
    db.add(patch)
    db.commit()
    db.refresh(patch)
    return patch

