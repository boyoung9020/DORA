# Windows EXE 파일 배포 가이드

## ✅ Windows 배포 가능 여부

**네, Windows에도 배포 가능합니다!** Flutter는 Windows 앱을 빌드할 수 있으며, `.exe` 파일로 배포할 수 있습니다.

현재 프로젝트에는 이미 Windows 설정이 포함되어 있습니다:
- ✅ `windows/` 폴더 존재
- ✅ CMake 설정 완료
- ✅ 앱 아이콘 설정 완료

## 🚀 Windows에서 실행 방법

### 1. Windows 개발 환경 요구사항

- Windows 10 이상
- Visual Studio 2022 (Community 버전 이상)
  - "Desktop development with C++" 워크로드 설치 필요
- Flutter SDK
- Git

### 2. Visual Studio 설치

1. [Visual Studio 2022 Community](https://visualstudio.microsoft.com/downloads/) 다운로드
2. 설치 시 다음 워크로드 선택:
   - **Desktop development with C++**
   - **Windows 10/11 SDK** (최신 버전)

### 3. Flutter Windows 지원 확인

```bash
flutter doctor
```

다음 항목이 체크되어야 합니다:
- ✅ Windows toolchain
- ✅ Visual Studio

### 4. 앱 실행

```bash
# 개발 모드로 실행
flutter run -d windows

# 또는 특정 디바이스 선택
flutter devices  # 사용 가능한 디바이스 확인
flutter run -d windows
```

## 📦 Windows 앱 빌드

### 개발 빌드

```bash
flutter build windows
```

빌드 결과물 위치: `build/windows/x64/runner/Debug/dora_project_manager.exe`

### 릴리스 빌드 (배포용)

```bash
flutter build windows --release
```

빌드 결과물 위치: `build/windows/x64/runner/Release/dora_project_manager.exe`

## 📋 빌드 결과물 구조

릴리스 빌드 후 다음 파일들이 생성됩니다:

```
build/windows/x64/runner/Release/
├── dora_project_manager.exe          # 실행 파일
├── flutter_windows.dll              # Flutter 런타임
├── data/                            # 앱 데이터
│   └── flutter_assets/              # 리소스 파일
└── [기타 DLL 파일들]                 # 의존성 라이브러리
```

## 🎯 EXE 파일 배포 방법

### 방법 1: 전체 폴더 배포 (권장)

릴리스 빌드 후 `Release` 폴더 전체를 배포:

```bash
# 빌드
flutter build windows --release

# 배포 폴더 생성
mkdir build/deploy/windows
cp -r build/windows/x64/runner/Release/* build/deploy/windows/
```

**배포 방법:**
- ZIP 파일로 압축
- USB 드라이브로 복사
- 네트워크 공유 폴더에 배치
- 클라우드 스토리지에 업로드

### 방법 2: 단일 EXE 파일 (고급)

모든 의존성을 EXE에 포함하려면 추가 설정이 필요합니다. (권장하지 않음)

## 🔧 Windows 설정 확인

### 1. 앱 이름 확인

`windows/CMakeLists.txt` 파일에서:
```
set(BINARY_NAME "dora_project_manager")
```

### 2. 앱 아이콘 확인

`windows/runner/resources/app_icon.ico` 파일이 있는지 확인

### 3. 최소 Windows 버전 확인

`windows/CMakeLists.txt`에서 Windows SDK 버전 확인

## 📝 API 서버 주소 설정

Windows 앱도 서버에 연결하려면 `lib/utils/api_client.dart`에서 서버 주소를 확인하세요:

```dart
static const String baseUrl = 'http://192.168.1.102';
```

## 🚀 빠른 배포 스크립트

### PowerShell 스크립트 (`build_windows.ps1`)

```powershell
# Windows 앱 빌드 및 배포 스크립트

$APP_NAME = "dora_project_manager"
$VERSION = "1.0.0"

Write-Host "=== DORA Windows 앱 빌드 및 배포 ===" -ForegroundColor Green
Write-Host ""

# 1. 의존성 설치
Write-Host "1. Flutter 의존성 설치 중..." -ForegroundColor Yellow
flutter pub get

# 2. 클린 빌드
Write-Host "2. 클린 빌드 중..." -ForegroundColor Yellow
flutter clean
flutter pub get

# 3. 릴리스 빌드
Write-Host "3. 릴리스 빌드 중..." -ForegroundColor Yellow
flutter build windows --release

# 4. 배포 파일 생성
Write-Host "4. 배포 파일 생성 중..." -ForegroundColor Yellow

$BUILD_DIR = "build\deploy\windows"
$RELEASE_DIR = "build\windows\x64\runner\Release"

# 배포 디렉토리 생성
if (Test-Path $BUILD_DIR) {
    Remove-Item -Recurse -Force $BUILD_DIR
}
New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null

# 파일 복사
Copy-Item -Path "$RELEASE_DIR\*" -Destination $BUILD_DIR -Recurse -Force

Write-Host "✅ 파일 복사 완료: $BUILD_DIR" -ForegroundColor Green

# ZIP 파일 생성
Write-Host "5. ZIP 파일 생성 중..." -ForegroundColor Yellow
$ZIP_PATH = "build\${APP_NAME}_v${VERSION}_windows.zip"
Compress-Archive -Path "$BUILD_DIR\*" -DestinationPath $ZIP_PATH -Force

Write-Host ""
Write-Host "✅ 배포 준비 완료!" -ForegroundColor Green
Write-Host ""
Write-Host "📦 생성된 파일:" -ForegroundColor Cyan
Write-Host "   - EXE: $RELEASE_DIR\dora_project_manager.exe"
Write-Host "   - 배포 폴더: $BUILD_DIR"
Write-Host "   - ZIP: $ZIP_PATH"
Write-Host ""
Write-Host "🚀 배포 방법:" -ForegroundColor Cyan
Write-Host "   1. $BUILD_DIR 폴더 전체를 복사"
Write-Host "   2. 또는 ZIP 파일을 공유"
Write-Host "   3. 사용자가 압축 해제 후 dora_project_manager.exe 실행"
```

## 🔍 문제 해결

### 빌드 오류

```bash
flutter clean
flutter pub get
flutter build windows --release
```

### Visual Studio 오류

- Visual Studio 2022가 설치되어 있는지 확인
- "Desktop development with C++" 워크로드가 설치되어 있는지 확인
- Windows SDK가 설치되어 있는지 확인

### 실행 오류

- 모든 DLL 파일이 EXE와 같은 폴더에 있는지 확인
- `data/flutter_assets` 폴더가 있는지 확인
- Windows Defender나 백신 프로그램이 차단하지 않는지 확인

## 📋 체크리스트

- [ ] Windows 개발 환경 설정 (Visual Studio, Flutter)
- [ ] API 서버 주소 설정 (`api_client.dart`)
- [ ] 앱 실행 테스트 (`flutter run -d windows`)
- [ ] 릴리스 빌드 테스트 (`flutter build windows --release`)
- [ ] 다른 Windows PC에서 실행 테스트

## 💡 참고사항

1. **Windows와 동일한 코드 사용**: Flutter는 같은 코드베이스로 Windows, macOS, Linux 모두 빌드 가능
2. **서버 주소**: Windows 앱도 같은 서버(`192.168.1.102`)에 연결
3. **데이터 공유**: Windows와 macOS 앱이 같은 서버를 사용하므로 데이터가 공유됨
4. **의존성 파일**: EXE 파일만 배포하면 안 되고, 모든 DLL과 데이터 폴더를 함께 배포해야 함

## 🎯 요약

- ✅ Windows 배포 가능
- ✅ 현재 프로젝트에 Windows 설정 포함됨
- ✅ macOS와 동일한 코드 사용
- ✅ 같은 서버에 연결하여 데이터 공유

Windows에서 `flutter build windows --release` 명령어로 빌드하면 됩니다!

