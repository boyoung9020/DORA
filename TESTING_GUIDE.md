# 데이터 공유 테스트 가이드

## ✅ 확인 사항

Docker Compose를 올리면 모든 데이터가 PostgreSQL 데이터베이스에 저장되어 모든 유저가 공유합니다.

### 현재 구현 상태

1. **모든 주요 데이터는 API를 통해 저장/조회**

   - ✅ 사용자 정보 → `/api/users`
   - ✅ 프로젝트 → `/api/projects`
   - ✅ 태스크 → `/api/tasks`
   - ✅ 댓글 → `/api/comments`

2. **SharedPreferences는 다음 용도로만 사용**
   - JWT 토큰 저장 (인증용)
   - 현재 사용자 정보 캐시 (오프라인 지원)
   - 현재 프로젝트 ID (UI 상태)
   - 메뉴 순서, 테마 설정 (UI 설정)

## 🧪 테스트 방법

### 1. 서버 시작

```bash
# Docker Compose로 서버 시작
docker-compose up -d

# 서버 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f api
```

### 2. API 테스트 (브라우저 또는 curl)

#### 회원가입

```bash
curl -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"user1\",\"email\":\"user1@test.com\",\"password\":\"test123\"}"
```

#### 로그인

```bash
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"admin123\"}"
```

응답에서 `access_token`을 복사하세요.

#### 프로젝트 생성

```bash
curl -X POST http://localhost/api/projects \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d "{\"name\":\"테스트 프로젝트\",\"description\":\"공유 테스트\"}"
```

### 3. Flutter 앱에서 테스트

#### 단계 1: 서버 연결 확인

1. Flutter 앱 실행
2. 로그인 화면에서 관리자 계정으로 로그인
   - 사용자명: `admin`
   - 비밀번호: `admin123`

#### 단계 2: 데이터 생성

1. 프로젝트 생성
2. 태스크 생성
3. 댓글 작성

#### 단계 3: 다른 유저로 확인

1. 새 계정 회원가입
2. 관리자로 로그인하여 새 계정 승인
3. 새 계정으로 로그인
4. **같은 프로젝트와 태스크가 보이는지 확인** ✅

### 4. Windows 네트워크 설정 확인

Windows에서 Flutter 앱이 `localhost`에 접근할 때 문제가 있을 수 있습니다.

#### 문제 해결

`lib/utils/api_client.dart` 파일을 확인하세요:

```dart
static const String baseUrl = 'http://localhost';
```

만약 연결이 안 되면:

1. **방화벽 확인**

   - Windows 방화벽에서 포트 80 허용 확인

2. **127.0.0.1 사용**

   ```dart
   static const String baseUrl = 'http://127.0.0.1';
   ```

3. **서버 IP 사용 (다른 PC에서 접근 시)**
   ```dart
   static const String baseUrl = 'http://192.168.1.100';  // 서버 IP
   ```

## 🔍 데이터 공유 확인 체크리스트

### ✅ 확인 항목

- [ ] 서버가 정상 실행 중인가? (`docker-compose ps`)
- [ ] API가 응답하는가? (`http://localhost/health`)
- [ ] Flutter 앱이 서버에 연결되는가? (로그인 성공)
- [ ] 유저 A가 프로젝트를 생성하면
- [ ] 유저 B가 같은 프로젝트를 볼 수 있는가?
- [ ] 유저 A가 태스크를 생성하면
- [ ] 유저 B가 같은 태스크를 볼 수 있는가?
- [ ] 유저 A가 댓글을 작성하면
- [ ] 유저 B가 같은 댓글을 볼 수 있는가?

### ❌ 문제 발생 시

#### 1. 연결 오류

```
네트워크 오류: Connection refused
```

**해결:**

- 서버가 실행 중인지 확인: `docker-compose ps`
- 포트가 사용 중인지 확인: `netstat -ano | findstr :80`

#### 2. 인증 오류

```
인증이 만료되었습니다
```

**해결:**

- 다시 로그인
- JWT 토큰이 올바르게 저장되었는지 확인

#### 3. 데이터가 보이지 않음

**확인:**

- 프로젝트에 팀원이 추가되었는지 확인
- 같은 프로젝트를 보고 있는지 확인
- API 응답 확인: `docker-compose logs -f api`

## 📊 데이터 흐름

```
유저 A (Flutter 앱)
    ↓ HTTP 요청
Nginx (포트 80)
    ↓ 프록시
FastAPI (포트 8000)
    ↓ SQL 쿼리
PostgreSQL (포트 5432)
    ↑ 데이터 저장

유저 B (Flutter 앱)
    ↓ HTTP 요청
Nginx (포트 80)
    ↓ 프록시
FastAPI (포트 8000)
    ↓ SQL 쿼리
PostgreSQL (포트 5432)
    ↑ 같은 데이터 조회 ✅
```

## 🎯 결론

**네, Docker Compose를 올리면 모든 데이터가 PostgreSQL에 저장되어 모든 유저가 공유합니다!**

- ✅ 모든 데이터는 중앙 데이터베이스에 저장
- ✅ 모든 유저가 같은 데이터를 조회
- ✅ 실시간으로 데이터 동기화
- ✅ 팀 협업 가능
