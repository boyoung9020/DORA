# 백엔드 서버 실행 가이드

이 문서는 Nginx + FastAPI + PostgreSQL을 Docker Compose로 실행하는 방법을 설명합니다.

## 🚀 빠른 시작

### 1. Docker Compose로 서버 시작

```bash
# 프로젝트 루트 디렉토리에서 실행
docker-compose up -d
```

이 명령어는 다음을 수행합니다:

- PostgreSQL 데이터베이스 컨테이너 시작
- FastAPI 백엔드 서버 컨테이너 시작
- Nginx 리버스 프록시 컨테이너 시작
- 초기 관리자 계정 자동 생성

### 2. 서버 상태 확인

```bash
# 모든 컨테이너 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f
```

### 3. API 테스트

브라우저에서 다음 URL을 열어보세요:

- API 문서: http://localhost/docs
- 헬스 체크: http://localhost/health

## 📋 초기 관리자 계정

서버 시작 시 자동으로 생성됩니다:

- **사용자명**: `admin`
- **비밀번호**: `admin123`

**⚠️ 프로덕션 환경에서는 반드시 비밀번호를 변경하세요!**

## 🔧 주요 명령어

### 서비스 시작/중지

```bash
# 서비스 시작 (백그라운드)
docker-compose up -d

# 서비스 중지
docker-compose stop

# 서비스 중지 및 컨테이너 삭제
docker-compose down

# 데이터베이스 데이터까지 삭제
docker-compose down -v
```

### 로그 확인

```bash
# 모든 서비스 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f api      # FastAPI
docker-compose logs -f nginx    # Nginx
docker-compose logs -f postgres # PostgreSQL
```

### 컨테이너 재시작

```bash
# 특정 서비스 재시작
docker-compose restart api

# 모든 서비스 재시작
docker-compose restart
```

## 🌐 접근 주소

- **Nginx (리버스 프록시)**: http://localhost
- **FastAPI (직접 접근)**: http://localhost:8000
- **PostgreSQL (직접 접근)**: localhost:5432

## 📝 API 엔드포인트

### 인증

- `POST /api/auth/register` - 회원가입
- `POST /api/auth/login` - 로그인
- `GET /api/auth/me` - 현재 사용자 정보

### 사용자 관리

- `GET /api/users` - 모든 사용자 (관리자만)
- `GET /api/users/pending` - 승인 대기 사용자 (관리자만)
- `PATCH /api/users/{id}/approve` - 사용자 승인 (관리자만)

### 프로젝트

- `GET /api/projects` - 프로젝트 목록
- `POST /api/projects` - 프로젝트 생성
- `PATCH /api/projects/{id}` - 프로젝트 수정
- `DELETE /api/projects/{id}` - 프로젝트 삭제

### 태스크

- `GET /api/tasks` - 태스크 목록
- `POST /api/tasks` - 태스크 생성
- `PATCH /api/tasks/{id}` - 태스크 수정
- `DELETE /api/tasks/{id}` - 태스크 삭제

자세한 API 문서는 http://localhost/docs 에서 확인할 수 있습니다.

## 🔍 문제 해결

### 포트가 이미 사용 중인 경우

`docker-compose.yml` 파일에서 포트를 변경하세요:

```yaml
nginx:
  ports:
    - "8080:80" # 80 대신 8080 사용
```

### 데이터베이스 연결 오류

```bash
# PostgreSQL 로그 확인
docker-compose logs postgres

# PostgreSQL 컨테이너에 접속
docker-compose exec postgres psql -U dora_user -d dora_db
```

### Nginx 설정 오류

```bash
# Nginx 설정 파일 문법 검사
docker-compose exec nginx nginx -t

# Nginx 재시작
docker-compose restart nginx
```

## 📚 더 자세한 정보

자세한 구현 설명은 `BACKEND_SETUP.md` 파일을 참고하세요.
