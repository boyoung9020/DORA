# Windows 앱 빌드 및 배포 스크립트
# PowerShell에서 실행: .\build_windows.ps1

$APP_NAME = "dora_project_manager"
$VERSION = "1.0.0"

Write-Host "=== DORA Windows 앱 빌드 및 배포 ===" -ForegroundColor Green
Write-Host ""

# 현재 디렉토리 확인
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ 오류: pubspec.yaml 파일을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host "프로젝트 루트 디렉토리에서 실행해주세요." -ForegroundColor Red
    exit 1
}

# 1. 의존성 설치
Write-Host "1. Flutter 의존성 설치 중..." -ForegroundColor Yellow
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 의존성 설치 실패" -ForegroundColor Red
    exit 1
}

# 2. 클린 빌드
Write-Host "2. 클린 빌드 중..." -ForegroundColor Yellow
flutter clean
flutter pub get

# 3. 릴리스 빌드
Write-Host "3. 릴리스 빌드 중..." -ForegroundColor Yellow
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 빌드 실패" -ForegroundColor Red
    exit 1
}

# 4. 배포 파일 생성
Write-Host "4. 배포 파일 생성 중..." -ForegroundColor Yellow

$BUILD_DIR = "build\deploy\windows"
$RELEASE_DIR = "build\windows\x64\runner\Release"
$EXE_PATH = "$RELEASE_DIR\dora_project_manager.exe"

# EXE 파일 확인
if (-not (Test-Path $EXE_PATH)) {
    Write-Host "❌ EXE 파일을 찾을 수 없습니다: $EXE_PATH" -ForegroundColor Red
    exit 1
}

# 배포 디렉토리 생성
if (Test-Path $BUILD_DIR) {
    Remove-Item -Recurse -Force $BUILD_DIR
}
New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null

# 파일 복사
Write-Host "   파일 복사 중..." -ForegroundColor Gray
Copy-Item -Path "$RELEASE_DIR\*" -Destination $BUILD_DIR -Recurse -Force

Write-Host "✅ 파일 복사 완료: $BUILD_DIR" -ForegroundColor Green

# ZIP 파일 생성
Write-Host "5. ZIP 파일 생성 중..." -ForegroundColor Yellow
$ZIP_PATH = "build\${APP_NAME}_v${VERSION}_windows.zip"

# 기존 ZIP 파일 삭제
if (Test-Path $ZIP_PATH) {
    Remove-Item -Force $ZIP_PATH
}

# ZIP 파일 생성
Compress-Archive -Path "$BUILD_DIR\*" -DestinationPath $ZIP_PATH -Force

if (Test-Path $ZIP_PATH) {
    $zipSize = (Get-Item $ZIP_PATH).Length / 1MB
    Write-Host "✅ ZIP 파일 생성 완료: $ZIP_PATH ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "⚠️  ZIP 파일 생성 실패" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ 배포 준비 완료!" -ForegroundColor Green
Write-Host ""
Write-Host "📦 생성된 파일:" -ForegroundColor Cyan
Write-Host "   - EXE: $EXE_PATH"
Write-Host "   - 배포 폴더: $BUILD_DIR"
if (Test-Path $ZIP_PATH) {
    Write-Host "   - ZIP: $ZIP_PATH"
}
Write-Host ""
Write-Host "🚀 배포 방법:" -ForegroundColor Cyan
Write-Host "   1. $BUILD_DIR 폴더 전체를 복사"
Write-Host "   2. 또는 ZIP 파일을 공유"
Write-Host "   3. 사용자가 압축 해제 후 dora_project_manager.exe 실행"
Write-Host ""
Write-Host "📋 중요 사항:" -ForegroundColor Yellow
Write-Host "   - EXE 파일만 복사하면 안 됩니다!"
Write-Host "   - Release 폴더의 모든 파일을 함께 배포해야 합니다"
Write-Host "   - DLL 파일과 data 폴더가 필요합니다"

