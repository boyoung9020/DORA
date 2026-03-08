"""Authentication API routes."""
import re
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.user import User
from app.schemas.auth import (
    GoogleSocialCodeLoginRequest,
    GoogleSocialLoginRequest,
    KakaoSocialCodeLoginRequest,
    KakaoSocialLoginRequest,
    Token,
)
from app.schemas.user import UserCreate, UserLogin, UserResponse
from app.utils.dependencies import get_current_user
from app.utils.security import create_access_token, get_password_hash, verify_password
from app.utils.social_auth import (
    SocialAuthError,
    exchange_google_auth_code,
    exchange_kakao_auth_code,
    verify_google_token_or_access_token,
    verify_kakao_access_token,
)

router = APIRouter()

# 소셜 신규 가입 대기 저장소 (10분 TTL)
_pending_social_registrations: dict[str, dict] = {}


def _store_pending_social_registration(
    provider: str, social_id: str, email: str | None, display_name: str | None
) -> str:
    token = str(uuid.uuid4())
    _pending_social_registrations[token] = {
        "provider": provider,
        "social_id": social_id,
        "email": email,
        "display_name": display_name,
        "expires_at": datetime.now(timezone.utc) + timedelta(minutes=10),
    }
    return token


def _pop_pending_social_registration(token: str) -> dict | None:
    entry = _pending_social_registrations.pop(token, None)
    if entry is None:
        return None
    if datetime.now(timezone.utc) > entry["expires_at"]:
        return None
    return entry


def _issue_access_token(user: User) -> Token:
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.id, "username": user.username},
        expires_delta=access_token_expires,
    )
    return Token(access_token=access_token, token_type="bearer")


def _slugify_username(value: str) -> str:
    # \w matches Unicode letters/digits/underscore (including Korean, etc.)
    slug = re.sub(r"[^\w]", "_", value.strip(), flags=re.UNICODE)
    slug = re.sub(r"_+", "_", slug).strip("_")
    if len(slug) < 3:
        slug = f"user_{slug}" if slug else "user"
    return slug[:30]


def _build_unique_username(db: Session, base_username: str) -> str:
    candidate = _slugify_username(base_username)
    if not db.query(User).filter(User.username == candidate).first():
        return candidate

    suffix = 1
    while True:
        retry = f"{candidate[:24]}_{suffix}"
        if not db.query(User).filter(User.username == retry).first():
            return retry
        suffix += 1


def _find_social_user(
    db: Session,
    provider: str,
    social_id: str,
    email: str | None,
) -> User | None:
    """소셜 계정으로 기존 유저를 찾습니다. 없으면 None 반환."""
    fallback_email = f"{provider}_{social_id}@social.local"
    resolved_email = (email or fallback_email).lower()

    existing = db.query(User).filter(User.email == resolved_email).first()
    if existing:
        return existing

    if email:
        by_email = db.query(User).filter(User.email == email.lower()).first()
        if by_email:
            return by_email

    return None


def _create_social_user(
    db: Session,
    provider: str,
    social_id: str,
    email: str | None,
    display_name: str | None,
    username: str | None = None,
) -> User:
    """소셜 계정으로 새 유저를 생성합니다."""
    fallback_email = f"{provider}_{social_id}@social.local"
    resolved_email = (email or fallback_email).lower()

    base_username = username or display_name or (email.split("@")[0] if email else f"{provider}_{social_id[:8]}")
    username = _build_unique_username(db, base_username)

    new_user = User(
        id=str(uuid.uuid4()),
        username=username,
        email=resolved_email,
        password_hash=get_password_hash(uuid.uuid4().hex),
        is_admin=False,
        is_approved=True,
        is_pm=False,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


def _resolve_social_user_by_mode(
    db: Session,
    provider: str,
    social_id: str,
    email: str | None,
    display_name: str | None,
    mode: str,
    username: str | None = None,
) -> User:
    user = _find_social_user(
        db,
        provider=provider,
        social_id=social_id,
        email=email,
    )

    if mode == "login":
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="가입된 계정이 없습니다. 먼저 회원가입을 해주세요.",
            )
        return user

    if user is None:
        user = _create_social_user(
            db,
            provider=provider,
            social_id=social_id,
            email=email,
            display_name=display_name,
            username=username,
        )
    return user


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user with email/password."""
    existing_user = db.query(User).filter(
        (User.username == user_data.username) | (User.email == user_data.email)
    ).first()

    if existing_user:
        if existing_user.username == user_data.username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="이미 사용 중인 사용자 이름입니다.",
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미 사용 중인 이메일입니다.",
        )

    new_user = User(
        id=str(uuid.uuid4()),
        username=user_data.username,
        email=user_data.email,
        password_hash=get_password_hash(user_data.password),
        is_admin=False,
        is_approved=True,
        is_pm=False,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user


@router.post("/login", response_model=Token)
async def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """Login with username/email and password."""
    user = db.query(User).filter(
        (User.email == user_data.username) | (User.username == user_data.username)
    ).first()

    if not user or not verify_password(user_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이메일 또는 비밀번호가 올바르지 않습니다.",
        )

    if not user.is_approved:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 승인 대기 중입니다. 승인 후 로그인할 수 있습니다.",
        )

    return _issue_access_token(user)


@router.post("/social/google", response_model=Token)
async def social_google_login(
    body: GoogleSocialLoginRequest,
    db: Session = Depends(get_db),
):
    """Login or register with Google ID token.
    mode='login': 기존 계정만 허용, 없으면 404.
    mode='register': 없으면 계정 생성, 있으면 그대로 로그인.
    """
    try:
        profile = await verify_google_token_or_access_token(body.id_token)
    except SocialAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    user = _resolve_social_user_by_mode(
        db,
        provider="google",
        social_id=profile["social_id"] or "",
        email=profile.get("email"),
        display_name=profile.get("display_name"),
        mode=body.mode,
        username=body.username,
    )

    if not user.is_approved:
        user.is_approved = True
        db.commit()
        db.refresh(user)

    return _issue_access_token(user)


@router.post("/social/google/code", response_model=Token)
async def social_google_login_with_code(
    body: GoogleSocialCodeLoginRequest,
    db: Session = Depends(get_db),
):
    """Login or register with Google OAuth authorization code."""
    try:
        exchanged = await exchange_google_auth_code(
            code=body.code,
            redirect_uri=body.redirect_uri,
            code_verifier=body.code_verifier,
        )
        verify_token = exchanged.get("id_token") or exchanged.get("access_token")
        if not verify_token:
            raise SocialAuthError("Google token exchange response missing token")
        profile = await verify_google_token_or_access_token(verify_token)
    except SocialAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    social_id = profile["social_id"] or ""
    email = profile.get("email")
    display_name = profile.get("display_name")

    existing_user = _find_social_user(db, provider="google", social_id=social_id, email=email)
    if existing_user is None and body.mode == "login":
        reg_token = _store_pending_social_registration("google", social_id, email, display_name)
        return JSONResponse(
            status_code=202,
            content={"registration_required": True, "registration_token": reg_token},
        )

    user = _resolve_social_user_by_mode(
        db,
        provider="google",
        social_id=social_id,
        email=email,
        display_name=display_name,
        mode=body.mode,
        username=body.username,
    )

    if not user.is_approved:
        user.is_approved = True
        db.commit()
        db.refresh(user)

    return _issue_access_token(user)


@router.post("/social/kakao", response_model=Token)
async def social_kakao_login(
    body: KakaoSocialLoginRequest,
    db: Session = Depends(get_db),
):
    """Login or register with Kakao access token.
    mode='login': 기존 계정만 허용, 없으면 404.
    mode='register': 없으면 계정 생성, 있으면 그대로 로그인.
    """
    try:
        profile = await verify_kakao_access_token(body.access_token)
    except SocialAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    user = _resolve_social_user_by_mode(
        db,
        provider="kakao",
        social_id=profile["social_id"] or "",
        email=profile.get("email"),
        display_name=profile.get("display_name"),
        mode=body.mode,
        username=body.username,
    )

    if not user.is_approved:
        user.is_approved = True
        db.commit()
        db.refresh(user)

    return _issue_access_token(user)


@router.post("/social/kakao/code", response_model=Token)
async def social_kakao_login_with_code(
    body: KakaoSocialCodeLoginRequest,
    db: Session = Depends(get_db),
):
    """Login or register with Kakao OAuth authorization code."""
    try:
        access_token = await exchange_kakao_auth_code(
            code=body.code,
            redirect_uri=body.redirect_uri,
            code_verifier=body.code_verifier,
        )
        profile = await verify_kakao_access_token(access_token)
    except SocialAuthError as exc:
        import traceback; traceback.print_exc()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    social_id = profile["social_id"] or ""
    email = profile.get("email")
    display_name = profile.get("display_name")

    existing_user = _find_social_user(db, provider="kakao", social_id=social_id, email=email)
    if existing_user is None and body.mode == "login":
        reg_token = _store_pending_social_registration("kakao", social_id, email, display_name)
        return JSONResponse(
            status_code=202,
            content={"registration_required": True, "registration_token": reg_token},
        )

    user = _resolve_social_user_by_mode(
        db,
        provider="kakao",
        social_id=social_id,
        email=email,
        display_name=display_name,
        mode=body.mode,
        username=body.username,
    )

    if not user.is_approved:
        user.is_approved = True
        db.commit()
        db.refresh(user)

    return _issue_access_token(user)


@router.post("/social/complete_registration", response_model=Token)
async def complete_social_registration(
    body: dict,
    db: Session = Depends(get_db),
):
    """신규 소셜 유저 회원가입 완료 (registration_token + username)."""
    registration_token = body.get("registration_token", "")
    username = body.get("username", "")

    entry = _pop_pending_social_registration(registration_token)
    if entry is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="유효하지 않거나 만료된 가입 토큰입니다.")

    user = _resolve_social_user_by_mode(
        db,
        provider=entry["provider"],
        social_id=entry["social_id"],
        email=entry["email"],
        display_name=entry["display_name"],
        mode="register",
        username=username or None,
    )

    if not user.is_approved:
        user.is_approved = True
        db.commit()
        db.refresh(user)

    return _issue_access_token(user)


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current authenticated user profile."""
    return current_user
