# Python 3.11 기반 이미지 사용
FROM python:3.11-slim

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 업데이트 및 PostgreSQL 클라이언트 라이브러리 설치
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Python 의존성 파일 복사
COPY requirements.txt .

# Python 패키지 설치
RUN pip install --no-cache-dir -r requirements.txt

# 애플리케이션 코드 복사
COPY . .

# Python 경로 설정 (app 모듈을 찾기 위해)
ENV PYTHONPATH=/app

# 포트 8000 노출 (FastAPI 기본 포트)
EXPOSE 8000

# Uvicorn으로 FastAPI 앱 실행
# --host 0.0.0.0: 모든 네트워크 인터페이스에서 접근 가능
# --reload: 개발 모드 (코드 변경 시 자동 재시작)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

