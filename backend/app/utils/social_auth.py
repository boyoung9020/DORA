"""Social auth token verification helpers."""
from typing import Any, Dict, Optional

import httpx
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.config import settings


class SocialAuthError(Exception):
    """Raised when social auth token verification fails."""


async def exchange_google_auth_code(
    code: str,
    redirect_uri: str,
    code_verifier: str,
) -> Dict[str, Optional[str]]:
    """Exchange Google OAuth authorization code for tokens."""
    if not settings.GOOGLE_CLIENT_ID:
        raise SocialAuthError("Google client id is not configured")

    body = {
        "code": code,
        "client_id": settings.GOOGLE_CLIENT_ID,
        "redirect_uri": redirect_uri,
        "grant_type": "authorization_code",
        "code_verifier": code_verifier,
    }
    if settings.GOOGLE_CLIENT_SECRET:
        body["client_secret"] = settings.GOOGLE_CLIENT_SECRET

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                "https://oauth2.googleapis.com/token",
                data=body,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
    except Exception as exc:  # noqa: BLE001
        raise SocialAuthError("Failed to exchange Google auth code") from exc

    if response.status_code != 200:
        detail = None
        try:
            detail = response.json().get("error_description") or response.json().get("error")
        except Exception:  # noqa: BLE001
            detail = response.text
        raise SocialAuthError(f"Google auth code exchange failed: {detail}")

    data: Dict[str, Any] = response.json()
    id_token = data.get("id_token")
    access_token = data.get("access_token")
    if not id_token and not access_token:
        raise SocialAuthError("Google token exchange response missing token")

    return {
        "id_token": id_token,
        "access_token": access_token,
    }


async def exchange_kakao_auth_code(
    code: str,
    redirect_uri: str,
    code_verifier: str,
) -> str:
    """Exchange Kakao OAuth authorization code for access token."""
    if not settings.KAKAO_REST_API_KEY:
        raise SocialAuthError("Kakao REST API key is not configured")

    body = {
        "grant_type": "authorization_code",
        "client_id": settings.KAKAO_REST_API_KEY,
        "redirect_uri": redirect_uri,
        "code": code,
    }
    if settings.KAKAO_CLIENT_SECRET:
        body["client_secret"] = settings.KAKAO_CLIENT_SECRET

    import sys
    print(f"[Kakao] token request body: {body}", flush=True, file=sys.stderr)
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                "https://kauth.kakao.com/oauth/token",
                data=body,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
    except Exception as exc:  # noqa: BLE001
        raise SocialAuthError("Failed to exchange Kakao auth code") from exc

    print(f"[Kakao] token response status={response.status_code} body={response.text}", flush=True, file=sys.stderr)
    if response.status_code != 200:
        detail = None
        try:
            detail = response.json().get("error_description") or response.json().get("error")
        except Exception:  # noqa: BLE001
            detail = response.text
        raise SocialAuthError(f"Kakao auth code exchange failed: {detail}")

    data: Dict[str, Any] = response.json()
    access_token = data.get("access_token")
    if not access_token:
        raise SocialAuthError("Kakao token exchange response missing access token")

    return str(access_token)


def verify_google_token(raw_id_token: str) -> Dict[str, Optional[str]]:
    """Verify a Google ID token and return normalized user info."""
    audience = settings.GOOGLE_CLIENT_ID or None
    try:
        payload = google_id_token.verify_oauth2_token(
            raw_id_token,
            google_requests.Request(),
            audience=audience,
            clock_skew_in_seconds=10,
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
