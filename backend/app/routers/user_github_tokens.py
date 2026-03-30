"""User GitHub token API router."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.user_github_token import UserGitHubToken
from app.schemas.user_github_token import GitHubTokenStatusResponse, GitHubTokenUpsertRequest
from app.utils.dependencies import get_current_user


router = APIRouter()


@router.get("/me", response_model=GitHubTokenStatusResponse)
async def get_my_github_token_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rec = db.query(UserGitHubToken).filter(UserGitHubToken.user_id == current_user.id).first()
    return GitHubTokenStatusResponse(has_token=bool(rec and rec.access_token))


@router.put("/me", status_code=status.HTTP_204_NO_CONTENT)
async def upsert_my_github_token(
    body: GitHubTokenUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    token = (body.access_token or "").strip()
    if not token:
        raise HTTPException(status_code=400, detail="access_token is required")

    rec = db.query(UserGitHubToken).filter(UserGitHubToken.user_id == current_user.id).first()
    if rec:
        rec.access_token = token
    else:
        rec = UserGitHubToken(
            id=str(uuid.uuid4()),
            user_id=current_user.id,
            access_token=token,
        )
        db.add(rec)

    db.commit()


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_github_token(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rec = db.query(UserGitHubToken).filter(UserGitHubToken.user_id == current_user.id).first()
    if not rec:
        return
    db.delete(rec)
    db.commit()

