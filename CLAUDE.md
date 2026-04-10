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
| API        | 4000     | 4000    |
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
├── screens/                     # UI screens; project_info/ is a tabbed sub-screen
│   ├── project_info/            #   (overview, members, tasks, patch, documents, github, settings tabs)
│   ├── main_layout.dart         #   Slack-style shell: left sidebar + right content area
│   ├── site_screen.dart         #   Server/DB/service info management (cross-project site details)
│   ├── kanban_screen.dart       #   Kanban board with drag-to-reorder
│   ├── catch_up_screen.dart     #   Activity catch-up view
│   └── workspace_member_stats_screen.dart  # Member contribution stats
├── widgets/                     # Reusable components
└── utils/api_client.dart        # Centralized HTTP client

backend/app/
├── main.py                      # FastAPI setup, router registration, ALTER TABLE migrations
├── config.py                    # Pydantic-settings env config
├── database.py                  # SQLAlchemy engine + session (pool size 5, overflow 5)
├── init_db.py                   # DB init + admin account creation
├── mbc_site_default_data.py     # Seed data for site defaults
├── models/                      # SQLAlchemy ORM (UUID PKs, ARRAY/JSON columns)
├── routers/                     # API endpoints (/api/*): auth, projects, tasks, sprints,
│                                #   workspaces, users, chat, github, user_github_tokens, patches,
│                                #   project_sites, site_details, checklists, comments, uploads,
│                                #   search, notifications, websocket, ai,
│                                #   api_tokens, request_issue, user_mattermost_settings
├── schemas/                     # Pydantic request/response schemas
├── migrations/                  # Standalone migration scripts (run manually if needed)
└── utils/                       # security.py, dependencies.py, notifications.py,
                                 #   github_api.py, social_auth.py (Google/Kakao OAuth)
```

## Key Patterns

### Frontend State Management
- All providers registered globally in `main.dart` via `MultiProvider`
- Providers: `AuthProvider`, `TaskProvider`, `ProjectProvider`, `ThemeProvider`, `NotificationProvider`, `ChatProvider`, `WorkspaceProvider`, `SprintProvider`, `GitHubProvider`, `CommentProvider`
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
- `get_user_by_api_token`: validates `Authorization: Bearer <api_token>` for external integrations (used by `request_issue` router — separate from JWT tokens)

### External API Token System
- Users generate long-lived API tokens via `/api/api-tokens` (stored hashed in `api_tokens` table)
- The `request_issue` router (`/api/request-issue/`) lets external apps create tasks using these tokens
- Token is shown only once on generation; thereafter only a prefix is stored

### AI Integration
- Backend `/api/ai/` calls Google Gemini API (`GEMINI_API_KEY` env var)
- Model fallback chain: `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-1.5-flash` (auto-retries on 503)

### Mattermost Integration
- Per-user webhook URL stored in `user_mattermost_settings` table
- `MattermostService` in Flutter posts to the webhook; backend `user_mattermost_settings` router manages settings

### DB Migration Strategy
- `Base.metadata.create_all()` is used only for fresh environments
- Schema changes on existing tables use raw `ALTER TABLE` SQL called at startup in `main.py` (see the `ensure_*` functions pattern)
- **No Alembic** — add column changes as `ALTER TABLE` blocks in `main.py`
- One-off migration scripts live in `backend/app/migrations/` and must be run manually

## Important Caveats

- **Windows Desktop + file uploads**: Do NOT use `dart:io` `File` class or `MultipartFile.fromPath()`. Use `XFile.readAsBytes()` + `MultipartFile.fromBytes()`. Windows namespace paths cause `_Namespace` errors.
- **DB migrations**: `SQLAlchemy create_all()` does NOT add columns to existing tables. Always use `ALTER TABLE`.
- **CORS**: Currently allows all origins (`*`) — dev only. Must restrict before production.
- **`bitsdojo_window`**: Used for custom window chrome on Windows desktop; stubbed for web (`lib/bitsdojo_window_stub.dart`).
- **File downloads**: Platform-specific implementations exist for web, IO (desktop), and a stub.
- **Task display order**: Persisted in DB; reorderable in kanban view.
- **Custom font**: `NanumSquareRound` (weights 300/400/700/800) — loaded from `font/nanum-square-round/`. Use this family for all text styles.
- **Markdown rendering**: Use `flutter_markdown` package for any markdown content display.
- **File picking**: Use `image_picker` (cross-platform) + `desktop_drop` (drag-and-drop on desktop) — never use `dart:io File` directly on Windows (see file upload caveat above).

## Default Admin

- Username: `admin` / Password: `admin123` (auto-created by `init_db.py`)
