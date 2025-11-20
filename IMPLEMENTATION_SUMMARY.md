# 백엔드 서버 구현 완료 요약

## ✅ 구현 완료 사항

### 1. 백엔드 서버 (FastAPI)

- ✅ 사용자 인증 시스템 (JWT 토큰 기반)
- ✅ 사용자 관리 API (회원가입, 로그인, 승인)
- ✅ 프로젝트 관리 API
- ✅ 태스크 관리 API
- ✅ 댓글 관리 API
- ✅ PostgreSQL 데이터베이스 연동
- ✅ 초기 관리자 계정 자동 생성

### 2. Nginx 리버스 프록시

- ✅ 클라이언트 요청을 FastAPI로 프록시
- ✅ CORS 설정
- ✅ 로드 밸런싱 준비

### 3. Docker Compose 설정

- ✅ PostgreSQL 컨테이너
- ✅ FastAPI 컨테이너
- ✅ Nginx 컨테이너
- ✅ 네트워크 및 볼륨 설정

### 4. Flutter 앱 연동

- ✅ API 클라이언트 유틸리티 구현
- ✅ 모든 서비스를 API 호출로 변경
  - AuthService
  - ProjectService
  - TaskService
  - CommentService
- ✅ JWT 토큰 관리
- ✅ 오프라인 지원 (로컬 캐시)

## 📁 프로젝트 구조

```
DORA/
├── backend/                 # 백엔드 서버
│   ├── app/
│   │   ├── main.py         # FastAPI 메인
│   │   ├── database.py     # DB 연결
│   │   ├── config.py       # 설정
│   │   ├── models/         # SQLAlchemy 모델
│   │   ├── schemas/         # Pydantic 스키마
│   │   ├── routers/        # API 라우터
│   │   └── utils/          # 유틸리티
│   ├── Dockerfile
│   └── requirements.txt
├── nginx/                   # Nginx 설정
│   └── nginx.conf
├── docker-compose.yml       # Docker Compose 설정
├── lib/                     # Flutter 앱
│   ├── services/           # API 서비스
│   ├── utils/
│   │   └── api_client.dart # API 클라이언트
│   └── models/             # 데이터 모델
└── README_BACKEND.md        # 실행 가이드
```

## 🚀 실행 방법

### 1. 백엔드 서버 시작

```bash
docker-compose up -d
```

### 2. Flutter 앱에서 API URL 설정

`lib/utils/api_client.dart` 파일에서 API 베이스 URL을 확인하세요:

```dart
static const String baseUrl = 'http://localhost';
```

로컬 개발 환경에서는 `localhost`를 사용하고, 실제 서버에 배포할 때는 서버 IP나 도메인으로 변경하세요.

### 3. 패키지 설치

```bash
flutter pub get
```

## 🔑 초기 관리자 계정

- **사용자명**: `admin`
- **비밀번호**: `admin123`

## 📡 API 엔드포인트

모든 API는 `http://localhost/api/`로 시작합니다.

### 인증

- `POST /api/auth/register` - 회원가입
- `POST /api/auth/login` - 로그인 (JWT 토큰 반환)
- `GET /api/auth/me` - 현재 사용자 정보

### 사용자

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

### 댓글

- `GET /api/comments/task/{task_id}` - 태스크의 댓글 목록
- `POST /api/comments` - 댓글 생성
- `PATCH /api/comments/{id}` - 댓글 수정
- `DELETE /api/comments/{id}` - 댓글 삭제

자세한 API 문서는 http://localhost/docs 에서 확인할 수 있습니다.

## 🔍 Nginx 동작 원리

### 리버스 프록시란?

Nginx는 클라이언트와 백엔드 서버 사이에 위치하여:

1. 클라이언트는 Nginx(포트 80)에만 요청을 보냅니다
2. Nginx가 요청을 분석하여 FastAPI(포트 8000)로 전달합니다
3. FastAPI가 처리한 응답을 Nginx가 클라이언트로 전달합니다

### 설정 파일 위치

`nginx/nginx.conf` 파일에서 다음을 설정합니다:

- 업스트림 서버 (FastAPI) 주소
- 프록시 규칙 (`/api`로 시작하는 요청을 FastAPI로 전달)
- 헤더 설정 (인증 정보, 클라이언트 IP 등)

### 장점

1. **보안**: 백엔드 서버의 실제 주소를 숨길 수 있습니다
2. **로드 밸런싱**: 여러 백엔드 서버로 요청을 분산할 수 있습니다
3. **SSL 종료**: HTTPS 요청을 받아서 백엔드로는 HTTP로 전달할 수 있습니다
4. **캐싱**: 정적 파일을 캐시할 수 있습니다

## 🐳 Docker Compose 동작 원리

### 서비스 정의

`docker-compose.yml` 파일에서 3개의 서비스를 정의합니다:

1. **postgres**: PostgreSQL 데이터베이스
2. **api**: FastAPI 백엔드 서버
3. **nginx**: Nginx 리버스 프록시

### 네트워크

모든 서비스는 `dora_network`라는 같은 네트워크에 있어서, 서비스 이름으로 서로 통신할 수 있습니다:

- `postgres:5432` - PostgreSQL에 접근
- `api:8000` - FastAPI에 접근

### 볼륨

- `./postgres_data:/var/lib/postgresql/data`: 데이터베이스 데이터를 호스트에 영구 저장
- `./backend:/app`: 개발 중 코드 변경 시 자동 반영

### 의존성

- `api`는 `postgres`가 준비될 때까지 대기
- `nginx`는 `api`가 시작된 후 시작

## 🔐 보안 고려사항

### 프로덕션 환경에서 변경해야 할 사항

1. **JWT 시크릿 키 변경**

   - `docker-compose.yml`의 `SECRET_KEY` 환경 변수
   - 강력한 랜덤 문자열 사용

2. **데이터베이스 비밀번호 변경**

   - `docker-compose.yml`의 PostgreSQL 비밀번호

3. **CORS 설정 제한**

   - `backend/app/main.py`의 `allow_origins`를 특정 도메인만 허용

4. **HTTPS 설정**

   - Nginx에 SSL 인증서 설정
   - Let's Encrypt 사용 권장

5. **초기 관리자 비밀번호 변경**
   - 서버 시작 후 즉시 변경

## 📝 다음 단계

1. **프로덕션 배포**

   - 서버에 Docker 설치
   - 도메인 설정
   - SSL 인증서 설정

2. **모니터링 설정**

   - 로그 수집
   - 성능 모니터링
   - 에러 알림

3. **백업 전략**

   - 데이터베이스 자동 백업
   - 백업 파일 저장소 설정

4. **확장성 고려**
   - 로드 밸런서 추가
   - 데이터베이스 복제
   - 캐싱 레이어 추가 (Redis)

## 📚 참고 문서

- `BACKEND_SETUP.md`: 자세한 구현 설명
- `README_BACKEND.md`: 실행 가이드
- `backend/README.md`: 백엔드 API 문서
