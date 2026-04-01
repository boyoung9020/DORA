# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# SYNC Project Manager

Flutter + FastAPI + PostgreSQL project management tool (Windows Desktop & Web).

## Tech Stack

- **Frontend**: Flutter/Dart (Windows Desktop, Web)
- **Backend**: FastAPI (Python 3.11)
- **Database**: PostgreSQL 15
- **Infrastructure**: Docker Compose, Nginx reverse proxy

## Quick Commands

```bash
# Frontend
flutter pub get                        # Install dependencies
flutter run -d windows                 # Run on Windows
flutter run -d chrome                  # Run on Web
flutter build windows --release        # Build Windows exe
flutter build web --release            # Build Web release
flutter analyze                        # Lint check

# Backend (Docker) — API is exposed on port 4000
docker compose up -d                   # Start all services
docker compose down                    # Stop all services
docker compose restart api             # Restart API only
docker compose logs -f api             # View API logs

# Backend (local dev — port 4000 to match docker convention)
cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 4000
```

## Ports

| Service    | Internal | Exposed |
|------------|----------|---------|
| API        | 8000     | 4000    |
| PostgreSQL | 5432     | 5432    |
| Nginx/Web  | 80       | 80      |

> `lib/utils/api_client.dart` resolves the base URL as `http://localhost:4000`. For Flutter Web, it uses `Uri.base.origin` (same-domain via Nginx).

## Architecture

```
lib/
├── main.dart                    # App entry, MultiProvider registration, theme
├── models/                      # Data models (fromJson/toJson/copyWith)
├── providers/                   # State (ChangeNotifier + Provider)
├── services/                    # API calls and business logic
├── screens/                     # 20 UI screens
├── widgets/                     # Reusable components
└── utils/api_client.dart        # Centralized HTTP client

backend/app/
├── main.py                      # FastAPI setup, router registration, ALTER TABLE migrations
├── config.py                    # Pydantic-settings env config
├── database.py                  # SQLAlchemy engine + session (pool size 5, overflow 5)
├── init_db.py                   # DB init + admin account creation
├── models/                      # SQLAlchemy ORM (UUID PKs, ARRAY/JSON columns)
├── routers/                     # API endpoints (/api/*)
├── schemas/                     # Pydantic request/response schemas
└── utils/                       # Security, dependencies, notifications
```

## Key Patterns

### Frontend State Management
- All providers registered globally in `main.dart` via `MultiProvider`
- Providers: `AuthProvider`, `TaskProvider`, `ProjectProvider`, `ThemeProvider`, `NotificationProvider`, `ChatProvider`, `WorkspaceProvider`, `SprintProvider`, `GitHubProvider`
- Use `Consumer<T>` in widgets; `Provider.of<T>(context, listen: false)` for one-shot calls

### API Client
- All HTTP calls via `ApiClient` static methods: `get`, `post`, `patch`, `put`, `delete`
- JWT token stored in `SharedPreferences` under key `auth_token`
- 401 responses trigger global `onUnauthorized` callback → force logout
- Use `handleResponse()` for single objects, `handleListResponse()` for arrays

### Enum Handling
- Frontend: camelCase (`inProgress`, `inReview`)
- Backend: snake_case (`in_progress`, `in_review`)
- `fromJson()` in Dart models handles both forms automatically

### WebSocket (Real-time)
- `WebSocketService` connects to `ws://localhost:4000/api/ws`
- Auto-reconnect: exponential backoff with jitter, max 5 attempts
- Events are JSON: `{ "type": "event_name", "data": {...} }`
- Backend `ConnectionManager` tracks per-user connections; supports targeted, multi-user, and broadcast sends

### Authentication Flow
- 3 pathways: email/password, Google OAuth, Kakao OAuth
- Social auth creates a 10-minute pending registration window → user must submit a username
- Admin approval required after registration (`is_approved` flag); users cannot log in until approved

### Backend Dependencies (FastAPI `Depends`)
- `get_db`: yields SQLAlchemy session
- `get_current_user`: validates JWT → returns User
- `get_current_admin_user`: enforces admin role
- `get_current_admin_or_pm_user`: enforces admin OR PM role
- `get_current_user_ws`: WebSocket-specific auth

### DB Migration Strategy
- `Base.metadata.create_all()` is used only for fresh environments
- Schema changes on existing tables use raw `ALTER TABLE` SQL called at startup in `main.py`
- **No Alembic** — add column changes as `ALTER TABLE` blocks in `main.py`

## Important Caveats

- **Windows Desktop + file uploads**: Do NOT use `dart:io` `File` class or `MultipartFile.fromPath()`. Use `XFile.readAsBytes()` + `MultipartFile.fromBytes()`. Windows namespace paths cause `_Namespace` errors.
- **DB migrations**: `SQLAlchemy create_all()` does NOT add columns to existing tables. Always use `ALTER TABLE`.
- **CORS**: Currently allows all origins (`*`) — dev only. Must restrict before production.
- **`bitsdojo_window`**: Used for custom window chrome on Windows desktop; stubbed for web.
- **File downloads**: Platform-specific implementations exist for web, IO (desktop), and a stub.
- **Task display order**: Persisted in DB; reorderable in kanban view.

## Default Admin

- Username: `admin` / Password: `admin123` (auto-created by `init_db.py`)
