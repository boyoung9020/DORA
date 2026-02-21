"""Social auth token verification helpers."""
from typing import Any, Dict, Optional

import httpx
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.config import settings


class SocialAuthError(Exception):
    """Raised when social auth token verification fails."""


def verify_google_token(raw_id_token: str) -> Dict[str, Optional[str]]:
    """Verify a Google ID token and return normalized user info."""
    audience = settings.GOOGLE_CLIENT_ID or None
    try:
        payload = google_id_token.verify_oauth2_token(
            raw_id_token,
            google_requests.Request(),
            audience=audience,
        )
    except Exception as exc:  # noqa: BLE001
        raise SocialAuthError("Invalid Google ID token") from exc

    issuer = payload.get("iss")
    if issuer not in {"accounts.google.com", "https://accounts.google.com"}:
        raise SocialAuthError("Invalid Google token issuer")

    social_id = payload.get("sub")
    if not social_id:
        raise SocialAuthError("Google token missing subject")

    email = payload.get("email")
    email_verified = payload.get("email_verified")
    if email and email_verified is False:
        raise SocialAuthError("Google email is not verified")

    display_name = payload.get("name") or payload.get("given_name")
    return {
        "social_id": str(social_id),
        "email": email,
        "display_name": display_name,
    }


async def verify_google_token_or_access_token(token: str) -> Dict[str, Optional[str]]:
    """Google ID token(JWT) 또는 access token을 모두 처리합니다.
    웹 implicit flow는 access token만 반환하므로 userinfo endpoint로 검증합니다."""
    # JWT는 점(.)으로 구분된 3개 파트 (header.payload.signature)
    if token.count(".") == 2:
        return verify_google_token(token)

    # Access token → Google userinfo endpoint로 검증
    headers = {"Authorization": f"Bearer {token}"}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://www.googleapis.com/oauth2/v1/userinfo",
                headers=headers,
            )
    except Exception as exc:
        raise SocialAuthError("Failed to call Google userinfo API") from exc

    if response.status_code != 200:
        raise SocialAuthError("Invalid Google access token")

    data: Dict[str, Any] = response.json()
    social_id = data.get("id")
    if not social_id:
        raise SocialAuthError("Google userinfo missing user id")

    return {
        "social_id": str(social_id),
        "email": data.get("email"),
        "display_name": data.get("name"),
    }


async def verify_kakao_access_token(access_token: str) -> Dict[str, Optional[str]]:
    """Verify a Kakao user access token and return normalized user info."""
    headers = {"Authorization": f"Bearer {access_token}"}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get("https://kapi.kakao.com/v2/user/me", headers=headers)
    except Exception as exc:  # noqa: BLE001
        raise SocialAuthError("Failed to call Kakao API") from exc

    if response.status_code != 200:
        raise SocialAuthError("Invalid Kakao access token")

    data: Dict[str, Any] = response.json()
    social_id = data.get("id")
    if not social_id:
        raise SocialAuthError("Kakao response missing user id")

    kakao_account = data.get("kakao_account") or {}
    profile = kakao_account.get("profile") or data.get("properties") or {}

    return {
        "social_id": str(social_id),
        "email": kakao_account.get("email"),
        "display_name": profile.get("nickname"),
    }
