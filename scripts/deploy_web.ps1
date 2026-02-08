# DORA - Web(Chrome) 배포 스크립트
# 실행: powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1
# 옵션: -ApiUrl "http://myserver.com:8000"  (외부 API 주소)
#        -Port 80                           (Nginx 포트)
#        -BuildOnly                         (웹 빌드만, Docker 안 띄움)

param(
    [string]$ApiUrl = "",
    [int]$Port = 80,
    [switch]$BuildOnly,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$PSScriptRoot\..\pubspec.yaml")) {
    $PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
}
Set-Location $PROJECT_ROOT

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DORA - Web (Chrome) 배포" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "[ERROR] 프로젝트 루트에서 실행해주세요." -ForegroundColor Red
    exit 1
}

# ---- 1. API URL 설정 (웹은 상대경로 사용) ----
$API_CLIENT = "lib\utils\api_client.dart"
$WS_SERVICE = "lib\services\websocket_service.dart"
$ORIGINAL_API_URL = $null
$ORIGINAL_WS_HOST = $null

if ($ApiUrl -ne "") {
    Write-Host "[1/5] API URL 변경: $ApiUrl" -ForegroundColor Yellow
    $content = Get-Content $API_CLIENT -Raw
    if ($content -match "static const String baseUrl = '([^']+)'") {
        $ORIGINAL_API_URL = $Matches[1]
        $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ApiUrl'"
        Set-Content $API_CLIENT $content -NoNewline
    }
} else {
    # 웹 배포 시 Nginx 프록시를 통하므로 상대 경로 사용 가능
    # 기본은 localhost:8000 유지 (Nginx가 프록시)
    Write-Host "[1/5] API URL: 기본값 유지 (Nginx 프록시)" -ForegroundColor Yellow
}

# ---- 2. Flutter 웹 빌드 ----
Write-Host "[2/5] Flutter Web 빌드..." -ForegroundColor Yellow

if ($Clean) {
    Write-Host "       클린 빌드..." -ForegroundColor Gray
    flutter clean | Out-Null
    flutter pub get | Out-Null
} else {
    flutter pub get | Out-Null
}

flutter build web --release --web-renderer canvaskit
if ($LASTEXITCODE -ne 0) {
    # URL 복원
    if ($ORIGINAL_API_URL) {
        $content = Get-Content $API_CLIENT -Raw
        $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ORIGINAL_API_URL'"
        Set-Content $API_CLIENT $content -NoNewline
    }
    Write-Host "[ERROR] 웹 빌드 실패" -ForegroundColor Red
    exit 1
}

Write-Host "       빌드 완료: build\web\" -ForegroundColor Gray

# ---- 3. URL 복원 ----
if ($ORIGINAL_API_URL) {
    Write-Host "[3/5] API URL 복원: $ORIGINAL_API_URL" -ForegroundColor Yellow
    $content = Get-Content $API_CLIENT -Raw
    $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ORIGINAL_API_URL'"
    Set-Content $API_CLIENT $content -NoNewline
} else {
    Write-Host "[3/5] URL 복원 불필요" -ForegroundColor Gray
}

if ($BuildOnly) {
    Write-Host "[4/5] Docker 건너뜀 (-BuildOnly)" -ForegroundColor Gray
    Write-Host "[5/5] 완료" -ForegroundColor Gray
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  웹 빌드 완료!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  빌드 경로: build\web\" -ForegroundColor White
    Write-Host "  이 폴더를 웹서버에 배포하세요." -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# ---- 4. Nginx 포트 설정 ----
if ($Port -ne 80) {
    Write-Host "[4/5] Nginx 포트 변경: $Port" -ForegroundColor Yellow
    $compose = Get-Content "docker-compose.yml" -Raw
    $compose = $compose -replace '"80:80"', "`"${Port}:80`""
    Set-Content "docker-compose.yml" $compose -NoNewline
} else {
    Write-Host "[4/5] Nginx 포트: 기본값 (80)" -ForegroundColor Yellow
}

# ---- 5. Docker 전체 시작 ----
Write-Host "[5/5] Docker 서비스 시작 (DB + API + Nginx)..." -ForegroundColor Yellow
docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker 시작 실패" -ForegroundColor Red
    # 포트 복원
    if ($Port -ne 80) {
        $compose = Get-Content "docker-compose.yml" -Raw
        $compose = $compose -replace "`"${Port}:80`"", '"80:80"'
        Set-Content "docker-compose.yml" $compose -NoNewline
    }
    exit 1
}

# 포트 복원
if ($Port -ne 80) {
    $compose = Get-Content "docker-compose.yml" -Raw
    $compose = $compose -replace "`"${Port}:80`"", '"80:80"'
    Set-Content "docker-compose.yml" $compose -NoNewline
}

# ---- 서비스 상태 확인 ----
Write-Host ""
Write-Host "  서비스 상태 확인..." -ForegroundColor Gray
Start-Sleep -Seconds 5
docker compose ps

# ---- 결과 출력 ----
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  웹 배포 완료!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  웹 앱  : http://localhost:$Port" -ForegroundColor White
Write-Host "  API    : http://localhost:8000" -ForegroundColor White
Write-Host "  DB     : localhost:5432" -ForegroundColor White
Write-Host ""
Write-Host "  관리 명령어:" -ForegroundColor Cyan
Write-Host "    docker compose logs -f api    # API 로그 확인" -ForegroundColor Gray
Write-Host "    docker compose restart api    # API 재시작" -ForegroundColor Gray
Write-Host "    docker compose down           # 전체 중지" -ForegroundColor Gray
Write-Host ""
Write-Host "  기본 계정: admin / admin123" -ForegroundColor Yellow
Write-Host ""
