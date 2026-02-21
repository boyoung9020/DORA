# 소셜 로그인 구현 현황

> 마지막 업데이트: 2026-02-21

---

## 목차

1. [전체 아키텍처](#전체-아키텍처)
2. [백엔드 API 엔드포인트](#백엔드-api-엔드포인트)
3. [백엔드 환경변수 설정](#백엔드-환경변수-설정)
4. [Flutter 플랫폼별 인증 흐름](#flutter-플랫폼별-인증-흐름)
5. [화면 구현 현황](#화면-구현-현황)
6. [외부 서비스 설정 현황](#외부-서비스-설정-현황)
7. [아직 해야 할 설정](#아직-해야-할-설정)
8. [앱 실행 명령어](#앱-실행-명령어)

---

## 전체 아키텍처

```
[Flutter Web]                [Flutter Desktop(Windows)]
     │                               │
     │ PKCE redirect flow            │ PKCE loopback server flow
     │ (현재 탭에서 리다이렉트)        │ (임의 포트 로컬 HTTP 서버)
     ▼                               ▼
[Google / Kakao OAuth]       [Google / Kakao OAuth]
     │                               │
     ▼                               ▼
[auth code 반환]             [auth code → Dart에서 token 교환]
     │                               │
     ▼                               ▼
[백엔드 /code 엔드포인트]     [백엔드 /token 엔드포인트]
     │                               │
     └──────────────┬────────────────┘
                    ▼
             [PostgreSQL DB]
             유저 조회/생성 후
             JWT 발급
```

---

## 백엔드 API 엔드포인트

### 일반 인증
| Method | Path | 설명 |
|--------|------|------|
| `POST` | `/api/auth/register` | 이메일/비밀번호 회원가입 |
| `POST` | `/api/auth/login` | 이메일/비밀번호 로그인 |
| `GET`  | `/api/auth/me` | 현재 로그인 사용자 정보 |

### 소셜 로그인 (토큰 직접 전달 — Desktop 전용)
| Method | Path | Body | 설명 |
|--------|------|------|------|
| `POST` | `/api/auth/social/google` | `{id_token, mode}` | Google ID token으로 로그인/가입 |
| `POST` | `/api/auth/social/kakao` | `{access_token, mode}` | Kakao access token으로 로그인/가입 |

### 소셜 로그인 (Authorization Code — Web 전용)
| Method | Path | Body | 설명 |
|--------|------|------|------|
| `POST` | `/api/auth/social/google/code` | `{code, redirect_uri, code_verifier, mode}` | Google auth code → 백엔드가 token 교환 |
| `POST` | `/api/auth/social/kakao/code` | `{code, redirect_uri, code_verifier, mode}` | Kakao auth code → 백엔드가 token 교환 |

### `mode` 필드 동작
| mode | 동작 |
|------|------|
| `"login"` | 기존 계정만 허용. 계정 없으면 **404** "가입된 계정이 없습니다." |
| `"register"` | 계정 없으면 자동 생성. 이미 있으면 그대로 로그인 |

---

## 백엔드 환경변수 설정

### `backend/.env` 파일 (Docker Compose가 읽음)

```dotenv
# DB 설정 (docker-compose.yml과 일치해야 함)
DB_HOST=postgres
DB_PORT=5432
DB_USER=admin
DB_PASSWORD=admin123
DB_NAME=dora_db

# JWT
SECRET_KEY=your-very-secret-key-change-in-production

# Google OAuth (Web Application 타입 클라이언트)
GOOGLE_CLIENT_ID=666748471519-j64u791pkatfus7c3hu5fi98akuqv2bc.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=            # ← 아직 미입력 (Google Console에서 확인 필요)

# Kakao
KAKAO_REST_API_KEY=              # ← 아직 미입력 (Kakao Developers에서 확인 필요)
KAKAO_CLIENT_SECRET=             # ← 선택사항 (미사용 시 비워도 됨)
```

> **주의**: `GOOGLE_CLIENT_SECRET`이 없으면 Web redirect 흐름에서 token 교환이 실패할 수 있음.
> Web Application 타입 Google 클라이언트는 code 교환 시 `client_secret`이 필요.

### 관련 파일
- [`backend/app/config.py`](../backend/app/config.py) — pydantic-settings로 `.env` 로드
- [`backend/app/utils/social_auth.py`](../backend/app/utils/social_auth.py) — token 검증 / code 교환 로직

---

## Flutter 플랫폼별 인증 흐름

### Web (`kIsWeb == true`) — PKCE Redirect Flow

```
1. 버튼 클릭 (login_screen / register_screen)
2. Flutter 로딩 다이얼로그 표시
3. PKCE code_verifier + code_challenge 생성
4. state, code_verifier, redirect_uri를 SharedPreferences에 저장
5. Google/Kakao OAuth URL로 현재 탭 리다이렉트 (_self)
   ↓ [사용자가 브라우저에서 인증 완료]
6. http://localhost:3000/?code=...&state=... 로 돌아옴
7. 앱 시작 시 completePendingWebSocialLogin() 호출 (AuthProvider._loadCurrentUser)
8. URL에서 code + state 읽기
9. state 검증 (CSRF 방지)
10. 백엔드 /api/auth/social/{provider}/code 호출
    (code + redirect_uri + code_verifier + mode 전송)
11. 백엔드가 OAuth 서버에서 token 교환
12. JWT 발급 → 로그인 완료
```

**관련 파일**:
- [`lib/services/auth_service.dart`](../lib/services/auth_service.dart)
  - `_startGoogleWebRedirectFlow(mode)`
  - `_startKakaoWebRedirectFlow(mode)`
  - `completePendingWebSocialLogin()`

---

### Windows Desktop (`kIsWeb == false`) — PKCE Loopback Flow

```
1. 버튼 클릭
2. Flutter 로딩 다이얼로그 표시
3. PKCE code_verifier + code_challenge 생성
4. 임의 포트로 로컬 HTTP 서버 시작 (dart:io HttpServer)
   redirect_uri = http://localhost:{임의포트}
5. 시스템 브라우저에서 OAuth URL 오픈 (LaunchMode.externalApplication)
   ↓ [사용자가 브라우저에서 인증 완료]
6. OAuth 서버가 http://localhost:{포트}/?code=... 로 리다이렉트
7. Dart HTTP 서버가 code 수신 + 브라우저에 "완료" 페이지 전송
8. [Google] code + code_verifier로 googleapis.com/token 에서 직접 token 교환
          (client_secret 필요: --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...)
   [Kakao]  code + code_verifier로 kauth.kakao.com/oauth/token 에서 직접 token 교환
9. 백엔드 /api/auth/social/google 또는 /kakao 에 id_token / access_token 전송
10. JWT 발급 → 로그인 완료
```

**관련 파일**:
- [`lib/services/auth_service.dart`](../lib/services/auth_service.dart)
  - `_loginWithGoogleDesktop(mode)`
  - `_loginWithKakaoDesktop(mode)`

---

## 화면 구현 현황

### 로그인 화면 (`lib/screens/login_screen.dart`)

| 기능 | 구현 상태 |
|------|----------|
| 이메일/비밀번호 로그인 | ✅ 완료 |
| Google로 계속하기 버튼 | ✅ 완료 |
| 카카오로 계속하기 버튼 | ✅ 완료 |
| 소셜 로그인 중 다이얼로그 표시 | ✅ 완료 |
| 계정 없을 때 에러 메시지 | ✅ "가입된 계정이 없습니다. 먼저 회원가입을 해주세요." |
| 취소 시 아무 동작 없음 | ✅ 완료 (errorMessage == null이면 스낵바 없음) |

**소셜 로그인 버튼 동작**: `mode = "login"` → 기존 계정만 허용

---

### 회원가입 화면 (`lib/screens/register_screen.dart`)

| 기능 | 구현 상태 |
|------|----------|
| 이메일/비밀번호 회원가입 | ✅ 완료 |
| Google로 시작하기 버튼 | ✅ 완료 |
| 카카오로 시작하기 버튼 | ✅ 완료 |
| 소셜 가입 완료 후 메인으로 이동 | ✅ 완료 |

**소셜 로그인 버튼 동작**: `mode = "register"` → 없으면 계정 생성, 이미 있으면 로그인

---

### 소셜 로그인 다이얼로그

버튼 클릭 시 배경을 어둡게 하고 아래 다이얼로그 표시:

```
┌──────────────────────────────┐
│                              │
│    ⏳ (로딩 스피너)           │
│                              │
│    Google 로그인 중...        │
│  인증 페이지로 이동합니다      │
│                              │
└──────────────────────────────┘
```

- Web: 리다이렉트 직전에 잠깐 표시됨
- Desktop: 브라우저가 열려 있는 동안 표시됨

---

## 외부 서비스 설정 현황

### Google Cloud Console

| 항목 | 값 | 상태 |
|------|-----|------|
| Web Application Client ID | `666748471519-j64u791pkatfus7c3hu5fi98akuqv2bc.apps.googleusercontent.com` | ✅ 발급됨 |
| Web Application Client Secret | — | ❓ 백엔드 `.env`에 미입력 |
| Authorized JavaScript origins | `http://localhost`, `http://localhost:3000` | ✅ 등록됨 (추정) |
| Authorized redirect URIs (Web) | `http://localhost:3000` | ❓ **확인 필요** — redirect flow용 |
| People API | 활성화 | ✅ 완료 |
| Desktop App Client ID | — | ❓ Windows 빌드 시 별도 발급 필요 |
| Desktop App Client Secret | — | ❓ Windows 빌드 시 별도 발급 필요 |

---

### Kakao Developers

| 항목 | 값 | 상태 |
|------|-----|------|
| 네이티브 앱 키 | `e5f10d7e9297ae72a3dd08a2d512a223` | ✅ 발급됨 |
| JavaScript 키 | `91cad79c79703a53ac47994e328c2f13` | ✅ 발급됨 |
| REST API 키 | — | ❓ **run_web.bat에 미입력** |
| JavaScript SDK 도메인 | `http://localhost:3000` | ✅ 등록됨 |
| 카카오 로그인 활성화 | ON | ✅ |
| Redirect URI (REST API용) | `http://localhost:3000` | ❓ **확인 필요** — redirect flow용 |
| 동의항목 (이메일, 닉네임) | — | ✅ 설정됨 (추정) |
| PKCE 지원 | — | ❓ **활성화 필요** — 현재 코드가 PKCE 사용 |

---

## 아직 해야 할 설정

### 1. Google Cloud Console
- [ ] **Authorized redirect URIs에 `http://localhost:3000` 추가**
  `APIs & Services` → `Credentials` → Web Application 클라이언트 편집
  → Authorized redirect URIs에 `http://localhost:3000` 추가
- [ ] **`GOOGLE_CLIENT_SECRET`을 `backend/.env`에 입력**
  Web Application 클라이언트의 secret 값 복사 → `.env`에 저장

### 2. Kakao Developers
- [ ] **REST API 키 확인**
  앱 키 페이지에서 `REST API 키` 값 복사
- [ ] **Redirect URI (REST API용) `http://localhost:3000` 등록**
  카카오 로그인 → Redirect URI → `http://localhost:3000` 추가
  *(JavaScript SDK 도메인과 별개의 설정)*
- [ ] **PKCE 지원 활성화**
  카카오 로그인 → 보안 → PKCE 활성화
  *(현재 코드가 `code_challenge`를 전송하므로 필수)*

### 3. Flutter 실행 명령어 업데이트
- [ ] **`KAKAO_REST_API_KEY` 추가** (아래 참고)

### 4. Windows Desktop (선택사항)
- [ ] Google Cloud Console에서 **Desktop app** 타입 OAuth 클라이언트 별도 생성
- [ ] `GOOGLE_DESKTOP_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_SECRET` 발급

---

## 앱 실행 명령어

### Web (`run_web.bat`)

```batch
@echo off
flutter run -d chrome ^
  --web-port=3000 ^
  --dart-define=GOOGLE_CLIENT_ID=666748471519-j64u791pkatfus7c3hu5fi98akuqv2bc.apps.googleusercontent.com ^
  --dart-define=GOOGLE_SERVER_CLIENT_ID=666748471519-j64u791pkatfus7c3hu5fi98akuqv2bc.apps.googleusercontent.com ^
  --dart-define=KAKAO_NATIVE_APP_KEY=e5f10d7e9297ae72a3dd08a2d512a223 ^
  --dart-define=KAKAO_JAVASCRIPT_APP_KEY=91cad79c79703a53ac47994e328c2f13 ^
  --dart-define=KAKAO_REST_API_KEY=여기에_REST_API_키_입력
```

> `KAKAO_REST_API_KEY`는 아직 미입력 상태. Kakao Developers에서 확인 후 추가 필요.

### Windows Desktop (미완성 — 별도 클라이언트 발급 후 사용)

```batch
flutter run -d windows ^
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=발급받은_Desktop_Client_ID ^
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=발급받은_Desktop_Client_Secret ^
  --dart-define=KAKAO_REST_API_KEY=발급받은_REST_API_키
```

### 백엔드

```bash
# Docker로 실행
docker compose up -d

# 로그 확인
docker compose logs -f api

# 코드 변경 후 재시작
docker compose restart api
```
