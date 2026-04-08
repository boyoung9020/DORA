"""
API 토큰 관리 라우터 (외부 서비스 연동용 토큰 발급/목록/폐기)
모든 엔드포인트는 일반 JWT 인증 필요
"""
import hashlib
import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.api_token import ApiToken
from app.models.user import User
from app.utils.dependencies import get_current_user

router = APIRouter()


class TokenGenerateRequest(BaseModel):
    name: str


class TokenGenerateResponse(BaseModel):
    id: str
    name: str
    token: str          # 딱 한 번만 반환 — 이후 복원 불가
    token_prefix: str
    created_at: str


class TokenInfo(BaseModel):
    id: str
    name: str
    token_prefix: str
    created_at: str


# ── 엔드포인트 ────────────────────────────────────────────────────────────────

@router.post("", response_model=TokenGenerateResponse, status_code=status.HTTP_201_CREATED)
def generate_token(
    body: TokenGenerateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """새 API 토큰 발급 — 토큰 원문은 이 응답에서만 확인 가능"""
    if not body.name.strip():
        raise HTTPException(status_code=422, detail="토큰 이름을 입력해주세요")

    raw_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    token_prefix = raw_token[:8]

    api_token = ApiToken(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        name=body.name.strip(),
        token_hash=token_hash,
        token_prefix=token_prefix,
    )
    db.add(api_token)
    db.commit()
    db.refresh(api_token)

    return TokenGenerateResponse(
        id=api_token.id,
        name=api_token.name,
        token=raw_token,
        token_prefix=token_prefix,
        created_at=api_token.created_at.isoformat(),
    )


@router.get("", response_model=list[TokenInfo])
def list_tokens(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """내 API 토큰 목록 조회"""
    tokens = (
        db.query(ApiToken)
        .filter(ApiToken.user_id == current_user.id)
        .order_by(ApiToken.created_at.desc())
        .all()
    )
    return [
        TokenInfo(
            id=t.id,
            name=t.name,
            token_prefix=t.token_prefix,
            created_at=t.created_at.isoformat(),
        )
        for t in tokens
    ]


@router.delete("/{token_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_token(
    token_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """API 토큰 폐기"""
    token = (
        db.query(ApiToken)
        .filter(ApiToken.id == token_id, ApiToken.user_id == current_user.id)
        .first()
    )
    if not token:
        raise HTTPException(status_code=404, detail="토큰을 찾을 수 없습니다")
    db.delete(token)
    db.commit()
