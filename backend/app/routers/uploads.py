"""
이미지 업로드 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse
from app.utils.dependencies import get_current_user
from app.models.user import User
import os
import uuid
from pathlib import Path
from typing import Optional

router = APIRouter()

# 업로드 디렉토리 설정 (서버 절대 경로)
# 환경 변수로 설정 가능, 없으면 기본값 사용
# Docker 컨테이너 내부: /app/uploads
# 호스트 시스템: ./backend/uploads (docker-compose.yml의 볼륨 마운트)
UPLOAD_BASE_DIR = os.getenv("UPLOAD_DIR", "/app/uploads")
UPLOAD_DIR = Path(UPLOAD_BASE_DIR)
# 디렉토리가 없으면 생성 (부모 디렉토리 포함)
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


# 허용된 이미지 확장자
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}

# 허용된 일반 파일 확장자
ALLOWED_FILE_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".webp",
    ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
    ".txt", ".csv", ".json", ".xml", ".yaml", ".yml",
    ".zip", ".rar", ".7z", ".tar", ".gz",
    ".mp4", ".mp3", ".wav",
    ".py", ".js", ".ts", ".dart", ".html", ".css",
}


def is_allowed_image(filename: str) -> bool:
    """이미지 확장자 확인"""
    ext = Path(filename).suffix.lower()
    return ext in ALLOWED_IMAGE_EXTENSIONS


def is_allowed_file(filename: str) -> bool:
    """일반 파일 확장자 확인"""
    ext = Path(filename).suffix.lower()
    return ext in ALLOWED_FILE_EXTENSIONS


@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """이미지 업로드"""
    # 파일 확장자 확인
    if not is_allowed_image(file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="허용되지 않은 파일 형식입니다. (jpg, jpeg, png, gif, webp만 가능)"
        )
    
    # 파일 크기 확인 (10MB 제한)
    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:  # 10MB
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="파일 크기는 10MB를 초과할 수 없습니다"
        )
    
    # 고유한 파일명 생성
    file_ext = Path(file.filename).suffix.lower()
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = UPLOAD_DIR / unique_filename
    
    # 파일 저장
    with open(file_path, "wb") as f:
        f.write(contents)
    
    # URL 반환
    image_url = f"/api/uploads/image/{unique_filename}"
    return {"url": image_url, "filename": unique_filename}


@router.get("/image/{filename}")
async def get_image(filename: str):
    """이미지 파일 반환"""
    file_path = UPLOAD_DIR / filename

    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="이미지를 찾을 수 없습니다"
        )

    return FileResponse(file_path)


@router.post("/file")
async def upload_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """일반 파일 업로드"""
    if not is_allowed_file(file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="허용되지 않은 파일 형식입니다."
        )

    contents = await file.read()
    if len(contents) > 50 * 1024 * 1024:  # 50MB
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="파일 크기는 50MB를 초과할 수 없습니다"
        )

    file_ext = Path(file.filename).suffix.lower()
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = UPLOAD_DIR / unique_filename

    with open(file_path, "wb") as f:
        f.write(contents)

    file_url = f"/api/uploads/file/{unique_filename}"
    return {
        "url": file_url,
        "filename": unique_filename,
        "original_name": file.filename,
        "size": len(contents),
    }


@router.get("/file/{filename}")
async def get_file(filename: str):
    """일반 파일 다운로드"""
    file_path = UPLOAD_DIR / filename

    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="파일을 찾을 수 없습니다"
        )

    return FileResponse(file_path, filename=filename)

