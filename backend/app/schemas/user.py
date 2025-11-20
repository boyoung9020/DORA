"""
사용자 관련 Pydantic 스키마
API 요청/응답 데이터 검증 및 직렬화
"""
from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional


class UserBase(BaseModel):
    """사용자 기본 스키마"""
    username: str
    email: EmailStr


class UserCreate(UserBase):
    """회원가입 요청 스키마"""
    password: str


class UserLogin(BaseModel):
    """로그인 요청 스키마"""
    username: str
    password: str


class UserResponse(UserBase):
    """사용자 응답 스키마"""
    id: str
    is_admin: bool
    is_approved: bool
    is_pm: bool
    created_at: datetime
    
    class Config:
        from_attributes = True  # SQLAlchemy 모델에서 자동 변환


class UserUpdate(BaseModel):
    """사용자 정보 수정 스키마"""
    email: Optional[EmailStr] = None
    is_approved: Optional[bool] = None
    is_pm: Optional[bool] = None

