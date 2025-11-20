# 백엔드 서버 설정 가이드

이 문서는 Nginx + FastAPI + PostgreSQL을 Docker Compose로 구성하는 방법을 자세히 설명합니다.

## 📋 목차

1. [아키텍처 개요](#아키텍처-개요)
2. [Nginx란?](#nginx란)
3. [구현 구조 설명](#구현-구조-설명)
4. [실행 방법](#실행-방법)
5. [테스트 방법](#테스트-방법)

---

## 🏗️ 아키텍처 개요

```
┌─────────────┐
│   클라이언트  │ (Flutter 앱 또는 웹 브라우저)
│  (포트 80)   │
└──────┬──────┘
       │ HTTP 요청
       ▼
┌─────────────┐
│    Nginx    │ (리버스 프록시)
│  (포트 80)  │
└──────┬──────┘
       │ 프록시 요청
       ▼
┌─────────────┐
│   FastAPI   │ (백엔드 API 서버)
│  (포트 8000)│
└──────┬──────┘
       │ SQL 쿼리
       ▼
┌─────────────┐
│ PostgreSQL  │ (데이터베이스)
│  (포트 5432) │
└─────────────┘
```

### 각 컴포넌트의 역할

1. **Nginx**: 리버스 프록시 서버

   - 클라이언트의 요청을 받아서 FastAPI 서버로 전달
   - 로드 밸런싱, SSL 종료, 정적 파일 제공 등 가능

2. **FastAPI**: 백엔드 API 서버

   - 비즈니스 로직 처리
   - 데이터베이스와 통신
   - RESTful API 제공

3. **PostgreSQL**: 관계형 데이터베이스
   - 모든 데이터 영구 저장
   - 트랜잭션 관리

---

## 🔍 Nginx란?

### Nginx의 역할

**Nginx**는 고성능 웹 서버이자 리버스 프록시 서버입니다.

#### 1. 리버스 프록시 (Reverse Proxy)

리버스 프록시는 클라이언트와 백엔드 서버 사이에 위치하여:

- 클라이언트는 Nginx에만 요청을 보냅니다
- Nginx가 요청을 적절한 백엔드 서버로 전달합니다
- 백엔드 서버의 실제 주소를 숨길 수 있습니다

**예시:**

```
클라이언트 → http://localhost/api/users
           ↓
         Nginx (포트 80)
           ↓
         FastAPI (포트 8000) → /api/users 처리
```

#### 2. 로드 밸런싱

여러 개의 FastAPI 서버가 있을 때, Nginx가 요청을 분산시킬 수 있습니다.

#### 3. SSL/TLS 종료

HTTPS 요청을 받아서 백엔드로는 HTTP로 전달할 수 있습니다.

#### 4. 정적 파일 제공

이미지, CSS, JavaScript 파일 등을 직접 제공할 수 있습니다.

---

## 📁 구현 구조 설명

### 1. Docker Compose 설정 (`docker-compose.yml`)

Docker Compose는 여러 컨테이너를 하나의 네트워크에서 함께 실행합니다.

```yaml
services:
  postgres: # PostgreSQL 데이터베이스
  api: # FastAPI 백엔드 서버
  nginx: # Nginx 리버스 프록시
```

#### 주요 설정 설명:

**PostgreSQL 서비스:**

```yaml
postgres:
  image: postgres:15-alpine
  environment:
    POSTGRES_USER: dora_user
    POSTGRES_PASSWORD: dora_password
    POSTGRES_DB: dora_db
  volumes:
    - ./postgres_data:/var/lib/postgresql/data # 데이터 영구 저장
  ports:
    - "5432:5432" # 호스트:컨테이너 포트 매핑
```

**FastAPI 서비스:**

```yaml
api:
  build:
    context: ./backend
  environment:
    DB_HOST: postgres # Docker Compose 서비스 이름으로 접근
  depends_on:
    postgres:
      condition: service_healthy # PostgreSQL이 준비될 때까지 대기
```

**Nginx 서비스:**

```yaml
nginx:
  image: nginx:alpine
  ports:
    - "80:80" # 외부에서 포트 80으로 접근
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
  depends_on:
    - api # API 서버가 먼저 시작되어야 함
```

### 2. Nginx 설정 (`nginx/nginx.conf`)

#### 업스트림 정의:

```nginx
upstream api {
    server api:8000;  # 'api'는 Docker Compose 서비스 이름
}
```

- `upstream`: 백엔드 서버 그룹을 정의
- `api:8000`: Docker Compose 네트워크 내부에서 FastAPI 서버에 접근

#### 서버 블록:

```nginx
server {
    listen 80;  # 포트 80에서 요청 대기

    location /api {
        proxy_pass http://api;  # /api로 시작하는 요청을 FastAPI로 전달
        proxy_set_header Host $host;  # 원본 호스트 헤더 전달
        proxy_set_header X-Real-IP $remote_addr;  # 클라이언트 IP 전달
    }
}
```

**프록시 헤더 설명:**

- `Host`: 원본 요청의 호스트 정보 유지
- `X-Real-IP`: 클라이언트의 실제 IP 주소 (로그, 보안에 사용)
- `X-Forwarded-For`: 프록시 체인을 통과한 IP 주소들
- `X-Forwarded-Proto`: 원본 프로토콜 (http/https)

### 3. FastAPI 애플리케이션

#### 메인 파일 (`app/main.py`):

```python
app = FastAPI()

# CORS 설정 (Flutter 앱에서 접근 가능하도록)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 모든 출처 허용
    allow_methods=["*"],  # 모든 HTTP 메서드 허용
)

# 라우터 등록
app.include_router(auth.router, prefix="/api/auth")
```

#### 데이터베이스 연결 (`app/database.py`):

```python
DATABASE_URL = f"postgresql://{user}:{password}@{host}:{port}/{dbname}"
engine = create_engine(DATABASE_URL)
```

### 4. 데이터베이스 모델

SQLAlchemy ORM을 사용하여 Python 클래스로 데이터베이스 테이블을 정의합니다.

```python
class User(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True)
    username = Column(String, unique=True)
    # ...
```

---

## 🚀 실행 방법

### 1. Docker Compose로 실행

```bash
# 프로젝트 루트 디렉토리에서
docker-compose up -d
```

**명령어 설명:**

- `up`: 서비스 시작
- `-d`: 백그라운드 모드 (detached)

**실행 순서:**

1. PostgreSQL 컨테이너 시작
2. 데이터베이스가 준비될 때까지 대기 (healthcheck)
3. FastAPI 컨테이너 시작
4. 데이터베이스 초기화 (관리자 계정 생성)
5. Nginx 컨테이너 시작

### 2. 로그 확인

```bash
# 모든 서비스 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f api
docker-compose logs -f nginx
docker-compose logs -f postgres
```

### 3. 서비스 상태 확인

```bash
# 실행 중인 컨테이너 확인
docker-compose ps
```

### 4. 서비스 중지

```bash
# 서비스 중지 (컨테이너만 종료)
docker-compose stop

# 서비스 중지 및 컨테이너 삭제
docker-compose down

# 데이터베이스 데이터까지 삭제
docker-compose down -v
```

---

## 🧪 테스트 방법

### 1. 헬스 체크

```bash
# Nginx를 통한 접근
curl http://localhost/health

# FastAPI 직접 접근
curl http://localhost:8000/health
```

### 2. API 테스트

#### 회원가입:

```bash
curl -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "test123"
  }'
```

#### 로그인:

```bash
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'
```

응답 예시:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

#### 인증이 필요한 API 호출:

```bash
curl -X GET http://localhost/api/projects \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### 3. 브라우저에서 확인

- API 문서: http://localhost/docs (Swagger UI)
- 대체 문서: http://localhost/redoc

---

## 🔧 문제 해결

### 1. 포트가 이미 사용 중인 경우

```bash
# Windows에서 포트 사용 확인
netstat -ano | findstr :80
netstat -ano | findstr :8000
netstat -ano | findstr :5432

# docker-compose.yml에서 포트 변경
ports:
  - "8080:80"  # 80 대신 8080 사용
```

### 2. 데이터베이스 연결 오류

```bash
# PostgreSQL 로그 확인
docker-compose logs postgres

# FastAPI 로그 확인
docker-compose logs api
```

### 3. Nginx 설정 오류

```bash
# Nginx 설정 파일 문법 검사
docker-compose exec nginx nginx -t

# Nginx 재시작
docker-compose restart nginx
```

---

## 📚 추가 학습 자료

- [Nginx 공식 문서](https://nginx.org/en/docs/)
- [FastAPI 공식 문서](https://fastapi.tiangolo.com/)
- [Docker Compose 공식 문서](https://docs.docker.com/compose/)
- [PostgreSQL 공식 문서](https://www.postgresql.org/docs/)

---

## ✅ 다음 단계

1. Flutter 앱에서 API 호출하도록 수정
2. 프로덕션 환경 설정 (SSL, 보안 강화)
3. 로그 관리 및 모니터링 설정
4. 백업 전략 수립
