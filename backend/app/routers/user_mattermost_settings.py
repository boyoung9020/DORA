"""사용자별 Mattermost 웹훅 설정 API."""

import uuid

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.user_mattermost_setting import UserMattermostSetting
from app.utils.dependencies import get_current_user

router = APIRouter()


class MattermostSettingResponse(BaseModel):
    has_setting: bool
    webhook_url: str = ""
    is_enabled: bool = False


class MattermostSettingUpsertRequest(BaseModel):
    webhook_url: str
    is_enabled: bool = True


@router.get("/me", response_model=MattermostSettingResponse)
async def get_my_mattermost_setting(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rec = db.query(UserMattermostSetting).filter(
        UserMattermostSetting.user_id == current_user.id
    ).first()
    if not rec:
        return MattermostSettingResponse(has_setting=False)
    return MattermostSettingResponse(
        has_setting=True,
        webhook_url=rec.webhook_url or "",
        is_enabled=rec.is_enabled,
    )


@router.put("/me", status_code=status.HTTP_204_NO_CONTENT)
async def upsert_my_mattermost_setting(
    body: MattermostSettingUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rec = db.query(UserMattermostSetting).filter(
        UserMattermostSetting.user_id == current_user.id
    ).first()
    if rec:
        rec.webhook_url = body.webhook_url.strip()
        rec.is_enabled = body.is_enabled
    else:
        rec = UserMattermostSetting(
            id=str(uuid.uuid4()),
            user_id=current_user.id,
            webhook_url=body.webhook_url.strip(),
            is_enabled=body.is_enabled,
        )
        db.add(rec)
    db.commit()


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_mattermost_setting(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rec = db.query(UserMattermostSetting).filter(
        UserMattermostSetting.user_id == current_user.id
    ).first()
    if rec:
        db.delete(rec)
        db.commit()
