# 프로젝트 구조

> **이 파일은 프로젝트 구조와 개발 규칙의 원본입니다.**
> 앱 구성, 폴더 구조, 기술 스택이 변경되면 이 파일(`project.md`)을 업데이트해야 합니다.

## 테스트 정보
- **기본 관리자 계정**: `admin / admin123` (최초 실행 시 `init_db.py`가 자동 생성)
- **API 테스트용 외부 토큰**: `/api/api-tokens` 에서 발급 (발급 시 1회만 노출, 이후 prefix만 저장됨)
- **Flutter Web UI 테스트 주소**: `http://localhost:3000` (개발 환경, `run_web.sh` 또는 `flutter run -d chrome --web-port=3000`)
- **API 테스트 주소**: `http://localhost:4000` (로컬 uvicorn 또는 docker compose)
- **Windows 네이티브 앱 테스트**: `flutter run -d windows`

## Apps
- `lib/` — Flutter (Dart) 프론트엔드 (Windows Desktop / Web)
- `backend/app/` — FastAPI (Python 3.11) 백엔드
- `backend/` — `Dockerfile`, `requirements.txt`, `scripts/`, `.env`
- `docker-compose.yml` — postgres / api / nginx 서비스 정의
- `nginx/` — Nginx 리버스 프록시 설정 (Flutter Web 빌드 서빙 + API 프록시)
- `oracle_cloud/` — Oracle Cloud 운영 배포 스크립트 (`deploy.sh`, `deploy_backend.sh` 등)
- `scripts/` — PowerShell 배포 스크립트 (`deploy_web.ps1`, `deploy_windows_app.ps1`)
- `installer/` — Inno Setup 기반 Windows 설치 프로그램
- `android/`, `ios/`, `macos/`, `linux/`, `web/`, `windows/` — Flutter 플랫폼별 프로젝트 설정

## Database
- **DB**: PostgreSQL 15 (Docker 컨테이너 `sync_postgres`, 포트 5432)
- **ORM**: SQLAlchemy 2.x (`backend/app/models/`)
- **세션**: `backend/app/database.py` — `SessionLocal` (pool_size 5, max_overflow 5)
- **DI**: FastAPI `Depends(get_db)` 로 `Session` 주입
- **마이그레이션 전략**:
  - 최초 생성: `Base.metadata.create_all()` (빈 DB 초기화 시에만 유효)
  - 기존 테이블 컬럼 추가/변경: `backend/app/main.py` 의 `ensure_*` 함수 패턴 (`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`) — startup 시 순차 실행
  - 일회성 복잡 마이그레이션: `backend/app/migrations/` 아래 스크립트 작성 후 수동 실행

## Ports

| Service    | Internal | Exposed |
|------------|----------|---------|
| API        | 4000     | 4000    |
| PostgreSQL | 5432     | 5432    |
| Nginx/Web  | 80, 443  | 80, 443 |

> `lib/utils/api_client.dart` 는 기본 base URL을 `http://localhost:4000`으로 해석하며, Flutter Web 빌드에서는 `Uri.base.origin`(Nginx 동일 도메인 프록시)을 사용한다.

# 핵심 아키텍처 패턴

- **인증**: JWT 기반. FastAPI `Depends` 헬퍼로 권한 계층 분리
  - `get_current_user` — 일반 사용자 인증
  - `get_current_admin_user` — 관리자 전용
  - `get_current_admin_or_pm_user` — 관리자 또는 PM
  - `get_current_user_ws` — WebSocket 전용 인증
  - `get_user_by_api_token` — `Authorization: Bearer <api_token>` (외부 연동용 `request_issue` 라우터, JWT 와 별개)
- **사용자 역할**: `admin` / `pm` / `member` + `is_approved` 플래그 (가입 후 관리자 승인 필수)
- **DB 접근**: `db: Session = Depends(get_db)` — 라우터/핸들러에서 세션 주입
- **API 응답**: Pydantic `response_model` 기반 스키마 직반환 (예: `response_model=TaskResponse`, `List[TaskResponse]`)
- **프론트엔드 상태**: `provider` 패키지 (`ChangeNotifier` + `MultiProvider`) — `lib/main.dart` 에 전역 등록
  - 10종: `AuthProvider`, `TaskProvider`, `ProjectProvider`, `ThemeProvider`, `NotificationProvider`, `ChatProvider`, `WorkspaceProvider`, `SprintProvider`, `GitHubProvider`, `CommentProvider`
  - 위젯에서 `Consumer<T>` 사용, 일회성 호출은 `Provider.of<T>(context, listen: false)`
- **API 클라이언트**: `lib/utils/api_client.dart` 의 `ApiClient` 정적 메서드 (`get/post/patch/put/delete`)
  - JWT 는 `SharedPreferences` 의 `auth_token` 키에 저장
  - 401 응답 시 전역 `onUnauthorized` 콜백 → 강제 로그아웃
  - 단건 응답은 `handleResponse`, 배열 응답은 `handleListResponse` 헬퍼로 파싱
- **Enum 변환**: 프런트 camelCase (`inProgress`, `inReview`) ↔ 백엔드 snake_case (`in_progress`, `in_review`) — Dart 모델의 `fromJson()` 이 양쪽을 자동 수용
- **WebSocket 실시간**: `lib/services/websocket_service.dart`
  - 엔드포인트: `ws://localhost:4000/api/ws`
  - 자동 재연결: 지수 백오프 + jitter, 최대 5회
  - 이벤트 포맷: `{ "type": "event_name", "data": {...} }`
  - 백엔드 `ConnectionManager` 가 유저별 연결을 트래킹 — 타겟/멀티유저/브로드캐스트 지원
- **인증 플로우**: 3가지 경로 — 이메일/비밀번호, Google OAuth, Kakao OAuth
  - 소셜 가입은 10분 pending 윈도우 → 유저네임 입력 필수
  - 가입 후 관리자 승인(`is_approved`)을 받아야 로그인 가능

# 외부 API 토큰 시스템
- 사용자가 `/api/api-tokens` 에서 장기 토큰 발급 (`api_tokens` 테이블에 해시 저장, prefix 만 이후 표시)
- `backend/app/routers/request_issue.py` (`/api/request-issue/`) 가 외부 앱에서 태스크 생성 시 이 토큰을 검증 — JWT 와 별개 인증
- 토큰은 발급 시점에 1회만 평문 노출

# AI / 외부 통합
- **Gemini**: `backend/app/routers/ai.py` — `GEMINI_API_KEY` 환경변수, 모델 체인 `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-1.5-flash` (503 시 자동 재시도)
- **GitHub**: `backend/app/utils/github_api.py`, 사용자별 토큰은 `user_github_tokens` 테이블
- **Mattermost**: 사용자별 Webhook URL 은 `user_mattermost_settings` 테이블, Flutter `MattermostService` 가 직접 포스트
- **소셜 로그인**: `backend/app/utils/social_auth.py` — Google / Kakao OAuth

# 코드 스타일
- 코드의 크기가 커지지 않도록 기능별로 파일을 분리하여 관리
  - 300 라인 이상 파일은 기능별 분리 고려 (Flutter 위젯, Dart 서비스, FastAPI 라우터 모두 동일)

# 쿼리 성능
- **쿼리 속도에 영향을 줄 수 있는 기능을 구현할 때는 반드시 쿼리 성능과 최적화를 검토**
  - JOIN, 서브쿼리, 집계 함수 등 복잡한 쿼리 구성 시 `EXPLAIN (ANALYZE, BUFFERS)` 로 실행 계획 확인
  - 필요한 인덱스가 존재하는지 확인하고, 누락 시 `backend/app/main.py` 의 `ensure_*` 함수에 `CREATE INDEX IF NOT EXISTS` 추가
  - N+1 쿼리 문제가 발생하지 않도록 주의 — SQLAlchemy 의 `joinedload` / `selectinload` 활용
  - 대량 데이터 조회 시 페이지네이션 및 필터 조건의 인덱스 활용 여부 검토

# DB 마이그레이션
- **No Alembic** — 스키마 변경은 `backend/app/main.py` 의 `ensure_*` 함수에 `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` 또는 `CREATE TABLE IF NOT EXISTS` 블록으로 추가
- 신규 테이블이면 `backend/app/models/` 에 SQLAlchemy 모델 정의 → 빈 DB 에서는 `Base.metadata.create_all()` 로 생성되지만, **기존 DB 에서는 반드시 `ensure_*` 함수에 `CREATE TABLE IF NOT EXISTS` 블록을 추가해야 반영됨**
- **컬럼 타입 변경 / 복잡한 데이터 이동**: `backend/app/migrations/` 아래 일회성 스크립트 작성 후 수동 실행 (`docker compose exec api python -m app.migrations.<script>`)
- 마이그레이션 추가 후에는 반드시 DB 에 실제로 반영되었는지 확인 (`docker compose exec postgres psql -U postgres -d sync -c "\d <table>"`)

# 중요 주의사항 (Caveats)
- **Windows Desktop + 파일 업로드**: `dart:io` `File` / `MultipartFile.fromPath()` 사용 금지. Windows 네임스페이스 경로 때문에 `_Namespace` 에러 발생 → `XFile.readAsBytes()` + `MultipartFile.fromBytes()` 사용
- **SQLAlchemy `create_all()`**: 기존 테이블에 컬럼을 추가하지 않음. 반드시 `ALTER TABLE` 을 `ensure_*` 함수에 추가할 것
- **CORS**: 현재 모든 Origin 허용 (`*`) — 개발 전용, 운영 전에 반드시 도메인 제한 필요
- **`bitsdojo_window`**: Windows 데스크탑 커스텀 창 크롬용. 웹 빌드에서는 `lib/bitsdojo_window_stub.dart` 로 스텁 처리
- **파일 다운로드**: 플랫폼별 구현 (`file_download_web.dart`, `file_download_io.dart`, `file_download_stub.dart`) 조건부 임포트

# 그룹 권한
- **구현되는 모든 기능에 권한 체크가 필요함** — 역할(`admin` / `pm` / `member`) 및 `is_approved` 플래그 기반
- 관리자 전용 기능은 `get_current_admin_user`, PM 이상은 `get_current_admin_or_pm_user` Depends 헬퍼 사용
- 새 관리자 화면을 추가할 때는 프론트 `AuthProvider` 역할 검사 + 백엔드 라우터 Depends 양쪽 모두 적용

# 개발 문서
- 개발 환경 셋업, 배포, 스키마 관련 가이드는 `docs_organize/` 아래에 보관되어 있음
  - `BACKEND_SETUP.md`, `FLUTTER_SETUP_GUIDE.md`, `DOCKER_REBUILD_GUIDE.md`, `JWT_SECRET_KEY_GUIDE.md`
  - `DATABASE_SCHEMA.md`
  - `RELEASE_GUIDE.md`, `WEB_DEPLOYMENT_GUIDE.md`, `WINDOWS_DEPLOYMENT_GUIDE.md`, `MACOS_DEPLOYMENT_COMPLETE.md`
  - `TESTING_GUIDE.md`, `social-login-setup.md`
- 새 스크립트/환경 변수/마이그레이션 절차를 추가하면 해당 가이드 또는 최상위 `CLAUDE.md` 에 반영할 것
