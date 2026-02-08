# DORA Project Manager

프로젝트 관리 데스크톱/웹 애플리케이션 (Flutter + FastAPI + PostgreSQL)

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

# Backend (Docker)
docker compose up -d                   # Start all services
docker compose down                    # Stop all services
docker compose restart api             # Restart API only
docker compose logs -f api             # View API logs

# Backend (local dev)
cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Architecture

```
lib/
├── main.dart                          # App entry point
├── models/                            # Data models (fromJson/toJson/copyWith)
├── providers/                         # State management (ChangeNotifier + Provider)
├── services/                          # API calls and business logic
├── screens/                           # UI screens
├── widgets/                           # Reusable UI components
└── utils/
    └── api_client.dart                # Centralized HTTP client (baseUrl: localhost:8000)

backend/app/
├── main.py                            # FastAPI app setup
├── config.py                          # Environment config (pydantic-settings)
├── database.py                        # SQLAlchemy engine + session
├── init_db.py                         # DB initialization + admin account creation
├── models/                            # SQLAlchemy ORM models
├── routers/                           # API endpoints (prefix: /api/*)
├── schemas/                           # Pydantic request/response schemas
└── utils/                             # Security, dependencies, notifications
```

## Key Patterns

- **State**: Provider pattern (`ChangeNotifier` + `Consumer<T>`)
- **API**: All HTTP calls go through `ApiClient` static methods (`get`, `post`, `patch`, `delete`)
- **Auth**: JWT Bearer tokens, stored in `SharedPreferences`
- **Real-time**: WebSocket via `web_socket_channel` for chat and notifications
- **Models**: Dart models use camelCase, backend uses snake_case. `fromJson` handles both.
- **Backend deps**: FastAPI `Depends()` for auth (`get_current_user`) and DB sessions (`get_db`)

## Important Caveats

- **Windows Desktop + dart:io**: File uploads must NOT use `dart:io` File class or `MultipartFile.fromPath`. Use `XFile.readAsBytes()` + `MultipartFile.fromBytes()` instead. Windows namespace paths cause `_Namespace` errors.
- **DB migrations**: `SQLAlchemy create_all()` does NOT add columns to existing tables. Use `ALTER TABLE` or Alembic for schema changes on existing tables.
- **CORS**: Currently allows all origins (dev mode). Must restrict in production.
- **API base URL**: Hardcoded in `lib/utils/api_client.dart` as `http://localhost:8000`

## Ports

| Service    | Port |
|------------|------|
| API        | 8000 |
| PostgreSQL | 5432 |
| Nginx/Web  | 80   |

## Default Admin

- Username: `admin` / Password: `admin123` (created automatically by `init_db.py`)
