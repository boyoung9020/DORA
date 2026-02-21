"""Authentication schemas."""
from typing import Literal, Optional

from pydantic import BaseModel


class Token(BaseModel):
    """JWT token response."""

    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Decoded JWT payload."""

    user_id: Optional[str] = None
    username: Optional[str] = None


class GoogleSocialLoginRequest(BaseModel):
    """Google social login payload."""

    id_token: str
    mode: Literal["login", "register"] = "login"


class GoogleSocialCodeLoginRequest(BaseModel):
    """Google social login payload using OAuth authorization code."""

    code: str
    redirect_uri: str
    code_verifier: str
    mode: Literal["login", "register"] = "login"


class KakaoSocialLoginRequest(BaseModel):
    """Kakao social login payload."""

    access_token: str
    mode: Literal["login", "register"] = "login"


class KakaoSocialCodeLoginRequest(BaseModel):
    """Kakao social login payload using OAuth authorization code."""

    code: str
    redirect_uri: str
    code_verifier: str
    mode: Literal["login", "register"] = "login"
