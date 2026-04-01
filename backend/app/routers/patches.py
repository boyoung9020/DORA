"""Patch history API router."""

import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models.patch import ProjectPatch
from app.models.project import Project
from app.models.user import User
from app.schemas.patch import PatchCreate, PatchUpdate, PatchResponse
from app.utils.dependencies import get_current_user


router = APIRouter()


def _get_project_or_403(db: Session, project_id: str, user: User) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="프로젝트를 찾을 수 없습니다")
    if not user.is_admin and user.id not in (project.team_member_ids or []):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="이 프로젝트에 접근 권한이 없습니다")
    return project


def _accessible_project_ids(db: Session, user: User):
    all_projects = db.query(Project).all()
    return [
        p.id for p in all_projects
        if user.is_admin or p.creator_id == user.id or user.id in (p.team_member_ids or [])
    ]


@router.get("/", response_model=List[PatchResponse])
async def list_patches(
    project_id: Optional[str] = Query(None, description="프로젝트 ID"),
    site_name: Optional[str] = Query(None, description="사이트명 (전체 프로젝트 대상 조회)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if site_name:
        # 사이트명으로 전체 접근 가능 프로젝트의 패치 조회
        accessible = set(_accessible_project_ids(db, current_user))
        patches = (
            db.query(ProjectPatch)
            .filter(ProjectPatch.site == site_name)
            .order_by(ProjectPatch.patch_date.desc(), ProjectPatch.created_at.desc())
            .all()
        )
        return [p for p in patches if p.project_id in accessible]

    if not project_id:
        raise HTTPException(status_code=400, detail="project_id 또는 site_name이 필요합니다")
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


@router.patch("/{patch_id}", response_model=PatchResponse)
async def update_patch(
    patch_id: str,
    body: PatchUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    patch = db.query(ProjectPatch).filter(ProjectPatch.id == patch_id).first()
    if not patch:
        raise HTTPException(status_code=404, detail="패치를 찾을 수 없습니다")
    _get_project_or_403(db, patch.project_id, current_user)

    if body.site is not None:
        patch.site = body.site.strip()
    if body.patch_date is not None:
        patch.patch_date = body.patch_date
    if body.version is not None:
        patch.version = body.version.strip()
    if body.content is not None:
        patch.content = body.content.strip()
    if body.steps is not None:
        patch.steps = body.steps
    if body.test_items is not None:
        patch.test_items = body.test_items
    if body.status is not None:
        allowed = {"pending", "in_progress", "done"}
        if body.status in allowed:
            patch.status = body.status
    if body.notes is not None:
        patch.notes = body.notes
    if body.note_image_urls is not None:
        patch.note_image_urls = body.note_image_urls

    db.commit()
    db.refresh(patch)
    return patch


@router.delete("/{patch_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_patch(
    patch_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    patch = db.query(ProjectPatch).filter(ProjectPatch.id == patch_id).first()
    if not patch:
        raise HTTPException(status_code=404, detail="패치를 찾을 수 없습니다")
    _get_project_or_403(db, patch.project_id, current_user)
    db.delete(patch)
    db.commit()

