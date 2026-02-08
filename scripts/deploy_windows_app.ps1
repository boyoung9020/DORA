# DORA - Windows Desktop 배포 스크립트
# 실행: powershell -ExecutionPolicy Bypass -File scripts\deploy_windows_app.ps1
# 옵션: -ApiUrl "http://192.168.0.10:8000"  (API 서버 주소 지정)

param(
    [string]$ApiUrl = "",
    [switch]$SkipBackend,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$APP_NAME = "dora_project_manager"
$VERSION = Get-Date -Format "yyyyMMdd"
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$PSScriptRoot\..\pubspec.yaml")) {
    $PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
}
Set-Location $PROJECT_ROOT

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DORA - Windows Desktop 배포" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# pubspec.yaml 확인
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "[ERROR] 프로젝트 루트에서 실행해주세요." -ForegroundColor Red
    exit 1
}

# ---- 1. API URL 설정 ----
$API_CLIENT = "lib\utils\api_client.dart"
$ORIGINAL_URL = $null

if ($ApiUrl -ne "") {
    Write-Host "[1/5] API URL 변경: $ApiUrl" -ForegroundColor Yellow
    $content = Get-Content $API_CLIENT -Raw
    if ($content -match "static const String baseUrl = '([^']+)'") {
        $ORIGINAL_URL = $Matches[1]
        $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ApiUrl'"
        Set-Content $API_CLIENT $content -NoNewline
        Write-Host "       $ORIGINAL_URL -> $ApiUrl" -ForegroundColor Gray
    }
} else {
    Write-Host "[1/5] API URL: 기본값 (localhost:8000)" -ForegroundColor Yellow
}

# ---- 2. 백엔드 시작 ----
if (-not $SkipBackend) {
    Write-Host "[2/5] Docker 백엔드 시작..." -ForegroundColor Yellow
    docker compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker 시작 실패. Docker Desktop이 실행 중인지 확인하세요." -ForegroundColor Red
        exit 1
    }
    Write-Host "       백엔드 준비 대기 (10초)..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
} else {
    Write-Host "[2/5] 백엔드 건너뜀 (-SkipBackend)" -ForegroundColor Gray
}

# ---- 3. Flutter 빌드 ----
Write-Host "[3/5] Flutter Windows 빌드..." -ForegroundColor Yellow

if ($Clean) {
    Write-Host "       클린 빌드..." -ForegroundColor Gray
    flutter clean | Out-Null
    flutter pub get | Out-Null
} else {
    flutter pub get | Out-Null
}

flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    # API URL 복원
    if ($ORIGINAL_URL) {
        $content = Get-Content $API_CLIENT -Raw
        $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ORIGINAL_URL'"
        Set-Content $API_CLIENT $content -NoNewline
    }
    Write-Host "[ERROR] 빌드 실패" -ForegroundColor Red
    exit 1
}

# ---- 4. 배포 패키지 생성 ----
Write-Host "[4/5] 배포 패키지 생성..." -ForegroundColor Yellow

$RELEASE_DIR = "build\windows\x64\runner\Release"
$DEPLOY_DIR = "build\deploy\${APP_NAME}_windows_$VERSION"
$ZIP_PATH = "build\deploy\${APP_NAME}_windows_${VERSION}.zip"

# 배포 폴더 생성
if (Test-Path $DEPLOY_DIR) { Remove-Item -Recurse -Force $DEPLOY_DIR }
New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null
Copy-Item -Path "$RELEASE_DIR\*" -Destination $DEPLOY_DIR -Recurse -Force

# ZIP 생성
if (Test-Path "build\deploy") {
    if (Test-Path $ZIP_PATH) { Remove-Item -Force $ZIP_PATH }
    Compress-Archive -Path "$DEPLOY_DIR\*" -DestinationPath $ZIP_PATH -Force
}

# ---- 5. API URL 복원 ----
if ($ORIGINAL_URL) {
    Write-Host "[5/5] API URL 복원: $ORIGINAL_URL" -ForegroundColor Yellow
    $content = Get-Content $API_CLIENT -Raw
    $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ORIGINAL_URL'"
    Set-Content $API_CLIENT $content -NoNewline
} else {
    Write-Host "[5/5] 완료" -ForegroundColor Yellow
}

# ---- 결과 출력 ----
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  배포 완료!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  EXE : $RELEASE_DIR\$APP_NAME.exe" -ForegroundColor White

if (Test-Path $ZIP_PATH) {
    $zipSize = [math]::Round((Get-Item $ZIP_PATH).Length / 1MB, 1)
    Write-Host "  ZIP : $ZIP_PATH ($zipSize MB)" -ForegroundColor White
}

Write-Host ""
Write-Host "  사용법:" -ForegroundColor Cyan
Write-Host "    - ZIP 파일을 배포 후 압축 해제" -ForegroundColor Gray
Write-Host "    - $APP_NAME.exe 실행" -ForegroundColor Gray
Write-Host "    - (!) EXE만 복사하면 안 됨, 폴더 전체 필요" -ForegroundColor Gray
Write-Host ""
