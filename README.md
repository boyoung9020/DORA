# DORA - 프로젝트 관리 시스템

Flutter로 만든 멀티 플랫폼 프로젝트 관리 애플리케이션입니다.

## 🎯 주요 기능

### ✅ 로그인 시스템 (구현 완료)
- 사용자 로그인/로그아웃
- 회원가입 (관리자 승인 필요)
- 관리자 승인 시스템
- 비밀번호 해싱 (SHA-256)

### 📋 프로젝트 관리 (예정)
- 프로젝트 생성/수정/삭제
- 작업(Task) 관리
- 우선순위 및 마감일 설정

## 🚀 시작하기

### 필수 요구사항
- Flutter SDK 3.9.2 이상
- Dart 3.9.2 이상

### 설치 및 실행

1. **의존성 설치**
   ```bash
   flutter pub get
   ```

2. **앱 실행**
   ```bash
   # 웹
   flutter run -d chrome
   
   # Windows
   flutter run -d windows
   
   # Android
   flutter run -d android
   
   # iOS (macOS만 가능)
   flutter run -d ios
   ```

## 👤 기본 관리자 계정

앱을 처음 실행하면 자동으로 관리자 계정이 생성됩니다:

- **사용자 이름**: `admin`
- **비밀번호**: `admin123`
- **이메일**: `admin@dora.com`

⚠️ **보안 주의**: 실제 배포 시 반드시 비밀번호를 변경하세요!

## 📁 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── models/                   # 데이터 모델
│   └── user.dart            # 사용자 모델
├── services/                 # 비즈니스 로직
│   └── auth_service.dart    # 인증 서비스
├── providers/               # 상태 관리
│   └── auth_provider.dart   # 인증 상태 관리
└── screens/                 # 화면
    ├── login_screen.dart    # 로그인 화면
    ├── register_screen.dart # 회원가입 화면
    ├── admin_approval_screen.dart # 관리자 승인 화면
    └── home_screen.dart     # 홈 화면
```

## 🔐 인증 시스템 작동 방식

### 1. 회원가입 프로세스
1. 사용자가 회원가입 화면에서 정보 입력
2. 비밀번호는 SHA-256으로 해싱되어 저장
3. `isApproved: false` 상태로 저장 (승인 대기)
4. 관리자 승인 전까지 로그인 불가

### 2. 관리자 승인 프로세스
1. 관리자가 홈 화면에서 "회원가입 승인 관리" 메뉴 접근
2. 승인 대기 중인 사용자 목록 확인
3. 승인 또는 거부 선택
4. 승인된 사용자는 로그인 가능

### 3. 로그인 프로세스
1. 사용자 이름과 비밀번호 입력
2. 비밀번호를 해싱하여 저장된 해시와 비교
3. 승인된 사용자만 로그인 성공
4. 로그인 상태는 SharedPreferences에 저장

## 📦 사용된 패키지

- **provider**: 상태 관리
- **shared_preferences**: 로컬 데이터 저장
- **crypto**: 비밀번호 해싱

## 🛠️ 개발 가이드

### Flutter 기본 개념

1. **Widget**: Flutter의 모든 UI 요소
   - `StatelessWidget`: 상태가 없는 위젯
   - `StatefulWidget`: 상태가 있는 위젯

2. **Provider**: 상태 관리 패턴
   - `ChangeNotifier`: 상태 변경 알림
   - `Consumer`: 상태 변경 감지

3. **Navigator**: 화면 전환
   - `Navigator.push()`: 새 화면으로 이동
   - `Navigator.pop()`: 이전 화면으로 돌아가기

### 코드 예시

#### 상태 관리 사용
```dart
// Provider 가져오기
final authProvider = Provider.of<AuthProvider>(context);

// 상태 읽기
if (authProvider.isAuthenticated) {
  // 로그인된 상태
}

// 메서드 호출
await authProvider.login(username, password);
```

#### 화면 전환
```dart
// 새 화면으로 이동
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => NextScreen()),
);

// 화면 교체 (뒤로 가기 불가)
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => NextScreen()),
);
```

## 📚 문서

| 문서 | 설명 |
|------|------|
| [BACKEND_SETUP.md](BACKEND_SETUP.md) | 백엔드(Nginx + FastAPI + PostgreSQL) 설정 및 Docker 실행 |
| [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) | PostgreSQL 테이블 구조 및 스키마 |
| [DOCKER_REBUILD_GUIDE.md](DOCKER_REBUILD_GUIDE.md) | Docker 이미지 재빌드 방법 |
| [FLUTTER_SETUP_GUIDE.md](FLUTTER_SETUP_GUIDE.md) | Flutter SDK 설치 (Windows/VSCode) |
| [JWT_SECRET_KEY_GUIDE.md](JWT_SECRET_KEY_GUIDE.md) | JWT 시크릿 키 설정 가이드 |
| [MACOS_DEPLOYMENT_COMPLETE.md](MACOS_DEPLOYMENT_COMPLETE.md) | macOS 앱 빌드·배포 가이드 |
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | API·데이터 공유 테스트 방법 |
| [WEB_DEPLOYMENT_GUIDE.md](WEB_DEPLOYMENT_GUIDE.md) | Flutter 웹 빌드 및 배포 |
| [WINDOWS_DEPLOYMENT_GUIDE.md](WINDOWS_DEPLOYMENT_GUIDE.md) | Windows EXE 빌드 및 배포 |

## 📝 라이선스

MIT
