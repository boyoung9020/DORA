# SYNC Project Manager

?꾨줈?앺듃 愿由??곗뒪?ы넲/???좏뵆由ъ??댁뀡 (Flutter + FastAPI + PostgreSQL)

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
?쒋?? main.dart                          # App entry point
?쒋?? models/                            # Data models (fromJson/toJson/copyWith)
?쒋?? providers/                         # State management (ChangeNotifier + Provider)
?쒋?? services/                          # API calls and business logic
?쒋?? screens/                           # UI screens
?쒋?? widgets/                           # Reusable UI components
?붴?? utils/
    ?붴?? api_client.dart                # Centralized HTTP client (baseUrl: localhost:8000)

backend/app/
?쒋?? main.py                            # FastAPI app setup
?쒋?? config.py                          # Environment config (pydantic-settings)
?쒋?? database.py                        # SQLAlchemy engine + session
?쒋?? init_db.py                         # DB initialization + admin account creation
?쒋?? models/                            # SQLAlchemy ORM models
?쒋?? routers/                           # API endpoints (prefix: /api/*)
?쒋?? schemas/                           # Pydantic request/response schemas
?붴?? utils/                             # Security, dependencies, notifications
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
