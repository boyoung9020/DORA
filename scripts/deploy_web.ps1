# SYNC - Web(Chrome) 諛고룷 ?ㅽ겕由쏀듃
# ?ㅽ뻾: powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1
# ?듭뀡: -ApiUrl "http://myserver.com:8000"  (?몃? API 二쇱냼)
#        -Port 80                           (Nginx ?ы듃)
#        -BuildOnly                         (??鍮뚮뱶留? Docker ???꾩?)

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
Write-Host "  SYNC - Web (Chrome) 諛고룷" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "[ERROR] ?꾨줈?앺듃 猷⑦듃?먯꽌 ?ㅽ뻾?댁＜?몄슂." -ForegroundColor Red
    exit 1
}

# ---- 1. API URL ?ㅼ젙 (?뱀? ?곷?寃쎈줈 ?ъ슜) ----
$API_CLIENT = "lib\utils\api_client.dart"
$WS_SERVICE = "lib\services\websocket_service.dart"
$ORIGINAL_API_URL = $null
$ORIGINAL_WS_HOST = $null

if ($ApiUrl -ne "") {
    Write-Host "[1/5] API URL 蹂寃? $ApiUrl" -ForegroundColor Yellow
    $content = Get-Content $API_CLIENT -Raw
    if ($content -match "static const String baseUrl = '([^']+)'") {
        $ORIGINAL_API_URL = $Matches[1]
        $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ApiUrl'"
        Set-Content $API_CLIENT $content -NoNewline
    }
} else {
    # ??諛고룷 ??Nginx ?꾨줉?쒕? ?듯븯誘濡??곷? 寃쎈줈 ?ъ슜 媛??
    # 湲곕낯? localhost:8000 ?좎? (Nginx媛 ?꾨줉??
    Write-Host "[1/5] API URL: 湲곕낯媛??좎? (Nginx ?꾨줉??" -ForegroundColor Yellow
}

# ---- 2. Flutter ??鍮뚮뱶 ----
Write-Host "[2/5] Flutter Web 鍮뚮뱶..." -ForegroundColor Yellow

if ($Clean) {
    Write-Host "       ?대┛ 鍮뚮뱶..." -ForegroundColor Gray
    flutter clean | Out-Null
    flutter pub get | Out-Null
} else {
    flutter pub get | Out-Null
}

flutter build web --release --web-renderer canvaskit
if ($LASTEXITCODE -ne 0) {
    # URL 蹂듭썝
    if ($ORIGINAL_API_URL) {
        $content = Get-Content $API_CLIENT -Raw
        $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ORIGINAL_API_URL'"
        Set-Content $API_CLIENT $content -NoNewline
    }
    Write-Host "[ERROR] ??鍮뚮뱶 ?ㅽ뙣" -ForegroundColor Red
    exit 1
}

Write-Host "       鍮뚮뱶 ?꾨즺: build\web\" -ForegroundColor Gray

# ---- 3. URL 蹂듭썝 ----
if ($ORIGINAL_API_URL) {
    Write-Host "[3/5] API URL 蹂듭썝: $ORIGINAL_API_URL" -ForegroundColor Yellow
    $content = Get-Content $API_CLIENT -Raw
    $content = $content -replace "static const String baseUrl = '[^']+'", "static const String baseUrl = '$ORIGINAL_API_URL'"
    Set-Content $API_CLIENT $content -NoNewline
} else {
    Write-Host "[3/5] URL 蹂듭썝 遺덊븘?? -ForegroundColor Gray
}

if ($BuildOnly) {
    Write-Host "[4/5] Docker 嫄대꼫? (-BuildOnly)" -ForegroundColor Gray
    Write-Host "[5/5] ?꾨즺" -ForegroundColor Gray
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  ??鍮뚮뱶 ?꾨즺!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  鍮뚮뱶 寃쎈줈: build\web\" -ForegroundColor White
    Write-Host "  ???대뜑瑜??뱀꽌踰꾩뿉 諛고룷?섏꽭??" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# ---- 4. Nginx ?ы듃 ?ㅼ젙 ----
if ($Port -ne 80) {
    Write-Host "[4/5] Nginx ?ы듃 蹂寃? $Port" -ForegroundColor Yellow
    $compose = Get-Content "docker-compose.yml" -Raw
    $compose = $compose -replace '"80:80"', "`"${Port}:80`""
    Set-Content "docker-compose.yml" $compose -NoNewline
} else {
    Write-Host "[4/5] Nginx ?ы듃: 湲곕낯媛?(80)" -ForegroundColor Yellow
}

# ---- 5. Docker ?꾩껜 ?쒖옉 ----
Write-Host "[5/5] Docker ?쒕퉬???쒖옉 (DB + API + Nginx)..." -ForegroundColor Yellow
docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker ?쒖옉 ?ㅽ뙣" -ForegroundColor Red
    # ?ы듃 蹂듭썝
    if ($Port -ne 80) {
        $compose = Get-Content "docker-compose.yml" -Raw
        $compose = $compose -replace "`"${Port}:80`"", '"80:80"'
        Set-Content "docker-compose.yml" $compose -NoNewline
    }
    exit 1
}

# ?ы듃 蹂듭썝
if ($Port -ne 80) {
    $compose = Get-Content "docker-compose.yml" -Raw
    $compose = $compose -replace "`"${Port}:80`"", '"80:80"'
    Set-Content "docker-compose.yml" $compose -NoNewline
}

# ---- ?쒕퉬???곹깭 ?뺤씤 ----
Write-Host ""
Write-Host "  ?쒕퉬???곹깭 ?뺤씤..." -ForegroundColor Gray
Start-Sleep -Seconds 5
docker compose ps

# ---- 寃곌낵 異쒕젰 ----
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  ??諛고룷 ?꾨즺!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  ???? : http://localhost:$Port" -ForegroundColor White
Write-Host "  API    : http://localhost:8000" -ForegroundColor White
Write-Host "  DB     : localhost:5432" -ForegroundColor White
Write-Host ""
Write-Host "  愿由?紐낅졊??" -ForegroundColor Cyan
Write-Host "    docker compose logs -f api    # API 濡쒓렇 ?뺤씤" -ForegroundColor Gray
Write-Host "    docker compose restart api    # API ?ъ떆?? -ForegroundColor Gray
Write-Host "    docker compose down           # ?꾩껜 以묒?" -ForegroundColor Gray
Write-Host ""
Write-Host "  湲곕낯 怨꾩젙: admin / admin123" -ForegroundColor Yellow
Write-Host ""
