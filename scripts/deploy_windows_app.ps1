# SYNC - Windows Desktop 諛고룷 ?ㅽ겕由쏀듃
# ?ㅽ뻾: powershell -ExecutionPolicy Bypass -File scripts\deploy_windows_app.ps1
# ?듭뀡: -ApiUrl "http://192.168.0.10:8000"  (API ?쒕쾭 二쇱냼 吏??

param(
    [string]$ApiUrl = "",
    [switch]$SkipBackend,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$APP_NAME = "sync_project_manager"
$VERSION = Get-Date -Format "yyyyMMdd"
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$PSScriptRoot\..\pubspec.yaml")) {
    $PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
}
Set-Location $PROJECT_ROOT

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SYNC - Windows Desktop 諛고룷" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# pubspec.yaml ?뺤씤
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "[ERROR] ?꾨줈?앺듃 猷⑦듃?먯꽌 ?ㅽ뻾?댁＜?몄슂." -ForegroundColor Red
    exit 1
}

# ---- 1. API URL ?ㅼ젙 ----
$API_CLIENT = "lib\utils\api_client.dart"
$ORIGINAL_URL = $null

if ($ApiUrl -ne "") {
    Write-Host "[1/5] API URL 蹂寃? $ApiUrl" -ForegroundColor Yellow
    $content = Get-Content $API_CLIENT -Raw
    if ($content -match "static const String baseUrl = '([^']+)'") {
        $ORIGINAL_URL = $Matches[1]
        $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ApiUrl'"
        Set-Content $API_CLIENT $content -NoNewline
        Write-Host "       $ORIGINAL_URL -> $ApiUrl" -ForegroundColor Gray
    }
} else {
    Write-Host "[1/5] API URL: 湲곕낯媛?(localhost:8000)" -ForegroundColor Yellow
}

# ---- 2. 諛깆뿏???쒖옉 ----
if (-not $SkipBackend) {
    Write-Host "[2/5] Docker 諛깆뿏???쒖옉..." -ForegroundColor Yellow
    docker compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker ?쒖옉 ?ㅽ뙣. Docker Desktop???ㅽ뻾 以묒씤吏 ?뺤씤?섏꽭??" -ForegroundColor Red
        exit 1
    }
    Write-Host "       諛깆뿏??以鍮??湲?(10珥?..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
} else {
    Write-Host "[2/5] 諛깆뿏??嫄대꼫? (-SkipBackend)" -ForegroundColor Gray
}

# ---- 3. Flutter 鍮뚮뱶 ----
Write-Host "[3/5] Flutter Windows 鍮뚮뱶..." -ForegroundColor Yellow

if ($Clean) {
    Write-Host "       ?대┛ 鍮뚮뱶..." -ForegroundColor Gray
    flutter clean | Out-Null
    flutter pub get | Out-Null
} else {
    flutter pub get | Out-Null
}

flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    # API URL 蹂듭썝
    if ($ORIGINAL_URL) {
        $content = Get-Content $API_CLIENT -Raw
        $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ORIGINAL_URL'"
        Set-Content $API_CLIENT $content -NoNewline
    }
    Write-Host "[ERROR] 鍮뚮뱶 ?ㅽ뙣" -ForegroundColor Red
    exit 1
}

# ---- 4. 諛고룷 ?⑦궎吏 ?앹꽦 ----
Write-Host "[4/5] 諛고룷 ?⑦궎吏 ?앹꽦..." -ForegroundColor Yellow

$RELEASE_DIR = "build\windows\x64\runner\Release"
$DEPLOY_DIR = "build\deploy\${APP_NAME}_windows_$VERSION"
$ZIP_PATH = "build\deploy\${APP_NAME}_windows_${VERSION}.zip"

# 諛고룷 ?대뜑 ?앹꽦
if (Test-Path $DEPLOY_DIR) { Remove-Item -Recurse -Force $DEPLOY_DIR }
New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null
Copy-Item -Path "$RELEASE_DIR\*" -Destination $DEPLOY_DIR -Recurse -Force

# ZIP ?앹꽦
if (Test-Path "build\deploy") {
    if (Test-Path $ZIP_PATH) { Remove-Item -Force $ZIP_PATH }
    Compress-Archive -Path "$DEPLOY_DIR\*" -DestinationPath $ZIP_PATH -Force
}

# ---- 5. API URL 蹂듭썝 ----
if ($ORIGINAL_URL) {
    Write-Host "[5/5] API URL 蹂듭썝: $ORIGINAL_URL" -ForegroundColor Yellow
    $content = Get-Content $API_CLIENT -Raw
    $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ORIGINAL_URL'"
    Set-Content $API_CLIENT $content -NoNewline
} else {
    Write-Host "[5/5] ?꾨즺" -ForegroundColor Yellow
}

# ---- 寃곌낵 異쒕젰 ----
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  諛고룷 ?꾨즺!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  EXE : $RELEASE_DIR\$APP_NAME.exe" -ForegroundColor White

if (Test-Path $ZIP_PATH) {
    $zipSize = [math]::Round((Get-Item $ZIP_PATH).Length / 1MB, 1)
    Write-Host "  ZIP : $ZIP_PATH ($zipSize MB)" -ForegroundColor White
}

Write-Host ""
Write-Host "  ?ъ슜踰?" -ForegroundColor Cyan
Write-Host "    - ZIP ?뚯씪??諛고룷 ???뺤텞 ?댁젣" -ForegroundColor Gray
Write-Host "    - $APP_NAME.exe ?ㅽ뻾" -ForegroundColor Gray
Write-Host "    - (!) EXE留?蹂듭궗?섎㈃ ???? ?대뜑 ?꾩껜 ?꾩슂" -ForegroundColor Gray
Write-Host ""
