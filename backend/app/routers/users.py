"""
사용자 관리 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate
from app.utils.dependencies import get_current_user, get_current_admin_user, get_current_admin_or_pm_user

router = APIRouter()


@router.get("/", response_model=List[UserResponse])
async def get_all_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_or_pm_user)
):
    """모든 사용자 목록 가져오기 (관리자 또는 PM 권한 필요)"""
    users = db.query(User).all()
    return users


@router.get("/pending", response_model=List[UserResponse])
async def get_pending_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """승인 대기 중인 사용자 목록 (관리자만)"""
    users = db.query(User).filter(
        User.is_approved == False,
        User.is_admin == False
    ).all()
    return users


@router.get("/approved", response_model=List[UserResponse])
async def get_approved_users(db: Session = Depends(get_db)):
    """승인된 사용자 목록"""
    users = db.query(User).filter(User.is_approved == True).all()
    return users


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """특정 사용자 정보 가져오기"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="사용자를 찾을 수 없습니다"
        )
    return user


@router.patch("/{user_id}/approve", response_model=UserResponse)
async def approve_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """사용자 승인 (관리자만)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="사용자를 찾을 수 없습니다"
        )
    
    print(f"[Approve] 승인 전: {user.username}, is_approved: {user.is_approved}")
    user.is_approved = True
    db.commit()
    db.refresh(user)
    print(f"[Approve] 승인 후: {user.username}, is_approved: {user.is_approved}")
    return user


@router.delete("/{user_id}/reject")
async def reject_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """사용자 거부 (관리자만)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="사용자를 찾을 수 없습니다"
        )
    
    db.delete(user)
    db.commit()
    return {"message": "사용자가 거부되었습니다"}


@router.patch("/{user_id}/grant-pm", response_model=UserResponse)
async def grant_pm_permission(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """PM 권한 부여 (관리자만)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="사용자를 찾을 수 없습니다"
        )
    
    user.is_pm = True
    db.commit()
    db.refresh(user)
    return user


@router.patch("/{user_id}/revoke-pm", response_model=UserResponse)
async def revoke_pm_permission(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """PM 권한 제거 (관리자만)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="사용자를 찾을 수 없습니다"
        )
    
    user.is_pm = False
    db.commit()
    db.refresh(user)
    return user

