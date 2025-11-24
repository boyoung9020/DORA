"""
FastAPI 의존성 함수들
인증된 사용자 확인 등
"""
from fastapi import Depends, HTTPException, status, WebSocket
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.utils.security import decode_access_token
from app.schemas.auth import TokenData

security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    현재 로그인한 사용자 가져오기
    JWT 토큰에서 사용자 정보를 추출하고 데이터베이스에서 사용자를 조회합니다.
    """
    token = credentials.credentials
    payload = decode_access_token(token)
    
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="유효하지 않은 토큰입니다",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user_id: str = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="토큰에서 사용자 정보를 찾을 수 없습니다",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="사용자를 찾을 수 없습니다",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_approved:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 승인이 필요합니다",
        )
    
    return user


def get_current_admin_user(current_user: User = Depends(get_current_user)) -> User:
    """관리자 권한 확인"""
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 권한이 필요합니다"
        )
    return current_user


def get_current_admin_or_pm_user(current_user: User = Depends(get_current_user)) -> User:
    """관리자 또는 PM 권한 확인"""
    if not current_user.is_admin and not current_user.is_pm:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 또는 PM 권한이 필요합니다"
        )
    return current_user


async def get_current_user_ws(
    websocket: WebSocket,
    token: str = None,
    db: Session = Depends(get_db)
) -> User:
    """
    WebSocket 연결에서 현재 사용자 가져오기
    쿼리 파라미터나 헤더에서 토큰을 받아 사용자를 인증합니다.
    """
    from fastapi import Query
    
    # 쿼리 파라미터에서 토큰 가져오기
    if not token:
        token = websocket.query_params.get("token")
    
    if not token:
        await websocket.close(code=1008, reason="토큰이 필요합니다")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="토큰이 필요합니다"
        )
    
    payload = decode_access_token(token)
    
    if payload is None:
        await websocket.close(code=1008, reason="유효하지 않은 토큰입니다")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="유효하지 않은 토큰입니다"
        )
    
    user_id: str = payload.get("sub")
    if user_id is None:
        await websocket.close(code=1008, reason="토큰에서 사용자 정보를 찾을 수 없습니다")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="토큰에서 사용자 정보를 찾을 수 없습니다"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        await websocket.close(code=1008, reason="사용자를 찾을 수 없습니다")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="사용자를 찾을 수 없습니다"
        )
    
    if not user.is_approved:
        await websocket.close(code=1008, reason="관리자 승인이 필요합니다")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 승인이 필요합니다"
        )
    
    return user
