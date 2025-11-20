# DORA 백엔드 API 서버

FastAPI 기반의 프로젝트 관리 시스템 백엔드 서버입니다.

## 기술 스택

- **FastAPI**: Python 웹 프레임워크
- **PostgreSQL**: 관계형 데이터베이스
- **SQLAlchemy**: ORM (Object-Relational Mapping)
- **Nginx**: 리버스 프록시 서버
- **Docker Compose**: 컨테이너 오케스트레이션

## 프로젝트 구조

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI 메인 애플리케이션
│   ├── config.py            # 설정 관리
│   ├── database.py           # 데이터베이스 연결
│   ├── models/              # SQLAlchemy 모델
│   │   ├── user.py
│   │   ├── project.py
│   │   ├── task.py
│   │   └── comment.py
│   ├── schemas/             # Pydantic 스키마 (API 요청/응답)
│   │   ├── user.py
│   │   ├── project.py
│   │   ├── task.py
│   │   └── comment.py
│   ├── routers/             # API 라우터
│   │   ├── auth.py          # 인증 (회원가입, 로그인)
│   │   ├── users.py         # 사용자 관리
│   │   ├── projects.py      # 프로젝트 관리
│   │   ├── tasks.py         # 태스크 관리
│   │   └── comments.py      # 댓글 관리
│   └── utils/               # 유틸리티 함수
│       ├── security.py      # 비밀번호 해싱, JWT 토큰
│       └── dependencies.py  # FastAPI 의존성
├── requirements.txt         # Python 패키지 의존성
├── Dockerfile              # Docker 이미지 빌드 설정
└── init_db.py             # 데이터베이스 초기화 스크립트
```

## API 엔드포인트

### 인증 (`/api/auth`)

- `POST /api/auth/register` - 회원가입
- `POST /api/auth/login` - 로그인 (JWT 토큰 반환)
- `GET /api/auth/me` - 현재 사용자 정보

### 사용자 (`/api/users`)

- `GET /api/users` - 모든 사용자 목록 (관리자만)
- `GET /api/users/pending` - 승인 대기 사용자 (관리자만)
- `GET /api/users/{user_id}` - 특정 사용자 정보
- `PATCH /api/users/{user_id}/approve` - 사용자 승인 (관리자만)
- `DELETE /api/users/{user_id}/reject` - 사용자 거부 (관리자만)
- `PATCH /api/users/{user_id}/grant-pm` - PM 권한 부여 (관리자만)
- `PATCH /api/users/{user_id}/revoke-pm` - PM 권한 제거 (관리자만)

### 프로젝트 (`/api/projects`)

- `GET /api/projects` - 모든 프로젝트 목록
- `GET /api/projects/{project_id}` - 특정 프로젝트 정보
- `POST /api/projects` - 새 프로젝트 생성
- `PATCH /api/projects/{project_id}` - 프로젝트 수정
- `DELETE /api/projects/{project_id}` - 프로젝트 삭제
- `POST /api/projects/{project_id}/members/{user_id}` - 팀원 추가
- `DELETE /api/projects/{project_id}/members/{user_id}` - 팀원 제거

### 태스크 (`/api/tasks`)

- `GET /api/tasks` - 모든 태스크 목록 (필터링 옵션)
- `GET /api/tasks/{task_id}` - 특정 태스크 정보
- `POST /api/tasks` - 새 태스크 생성
- `PATCH /api/tasks/{task_id}` - 태스크 수정
- `DELETE /api/tasks/{task_id}` - 태스크 삭제
- `PATCH /api/tasks/{task_id}/status` - 태스크 상태 변경

### 댓글 (`/api/comments`)

- `GET /api/comments/task/{task_id}` - 태스크의 댓글 목록
- `GET /api/comments/{comment_id}` - 특정 댓글 정보
- `POST /api/comments` - 새 댓글 생성
- `PATCH /api/comments/{comment_id}` - 댓글 수정
- `DELETE /api/comments/{comment_id}` - 댓글 삭제

## 실행 방법

### Docker Compose 사용 (권장)

```bash
# 모든 서비스 시작 (PostgreSQL, FastAPI, Nginx)
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 서비스 중지
docker-compose down

# 데이터베이스 데이터까지 삭제
docker-compose down -v
```

### 로컬 개발 환경

```bash
# 가상 환경 생성
python -m venv venv

# 가상 환경 활성화
# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

# 패키지 설치
pip install -r requirements.txt

# 데이터베이스 초기화
python app/init_db.py

# 서버 실행
uvicorn app.main:app --reload
```

## 초기 관리자 계정

서버 시작 시 자동으로 생성됩니다:

- 사용자명: `admin`
- 비밀번호: `admin123`

**프로덕션 환경에서는 반드시 비밀번호를 변경하세요!**

## 환경 변수

`.env` 파일을 생성하여 다음 설정을 변경할 수 있습니다:

```env
DB_HOST=postgres
DB_PORT=5432
DB_USER=dora_user
DB_PASSWORD=dora_password
DB_NAME=dora_db

SECRET_KEY=your-secret-key-change-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=1440
```
