# Flutter 자동 설치 스크립트
# 관리자 권한으로 실행 필요

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flutter SDK 자동 설치 스크립트" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 관리자 권한 확인
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "⚠️  관리자 권한이 필요합니다!" -ForegroundColor Red
    Write-Host "PowerShell을 관리자 권한으로 실행한 후 다시 시도하세요." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "방법: PowerShell 아이콘 우클릭 > '관리자 권한으로 실행'" -ForegroundColor Yellow
    pause
    exit 1
}

# Flutter SDK 설치 경로
$flutterPath = "C:\src\flutter"
$flutterBinPath = "$flutterPath\bin"
$flutterRepo = "https://github.com/flutter/flutter.git"

Write-Host "[1/6] Git 설치 확인..." -ForegroundColor Green
try {
    $gitVersion = git --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git이 설치되어 있지 않습니다"
    }
    Write-Host "  ✓ Git 설치됨: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Git이 설치되어 있지 않습니다!" -ForegroundColor Red
    Write-Host "  Git을 먼저 설치해주세요: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "  또는 수동 설치 방법을 참고하세요." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "[2/6] Flutter SDK 설치 경로 확인..." -ForegroundColor Green
if (Test-Path $flutterPath) {
    Write-Host "  ⚠️  $flutterPath 경로에 이미 Flutter가 설치되어 있습니다." -ForegroundColor Yellow
    $overwrite = Read-Host "  덮어쓰시겠습니까? (y/n)"
    if ($overwrite -ne "y") {
        Write-Host "  설치를 취소했습니다." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "  기존 설치 제거 중..." -ForegroundColor Yellow
    Remove-Item $flutterPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "[3/6] C:\src 폴더 생성..." -ForegroundColor Green
try {
    if (-not (Test-Path "C:\src")) {
        New-Item -ItemType Directory -Path "C:\src" -Force | Out-Null
        Write-Host "  ✓ 폴더 생성 완료" -ForegroundColor Green
    } else {
        Write-Host "  ✓ 폴더 이미 존재" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ 폴더 생성 실패: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[4/6] Flutter SDK 클론 중..." -ForegroundColor Green
Write-Host "  저장소: $flutterRepo" -ForegroundColor Gray
Write-Host "  이 작업은 몇 분이 걸릴 수 있습니다..." -ForegroundColor Yellow
try {
    Push-Location "C:\src"
    git clone -b stable $flutterRepo
    if ($LASTEXITCODE -ne 0) {
        throw "Git clone 실패"
    }
    Write-Host "  ✓ 클론 완료" -ForegroundColor Green
    Pop-Location
} catch {
    Pop-Location
    Write-Host "  ✗ 클론 실패: $_" -ForegroundColor Red
    Write-Host "  네트워크 연결을 확인하거나 수동 설치를 시도하세요." -ForegroundColor Yellow
    exit 1
}

Write-Host "[5/6] 환경 변수 설정 중..." -ForegroundColor Green
try {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if ($currentPath -notlike "*$flutterBinPath*") {
        $newPath = "$currentPath;$flutterBinPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "  ✓ 환경 변수 추가 완료" -ForegroundColor Green
        Write-Host "  ⚠️  새 터미널을 열어야 환경 변수가 적용됩니다." -ForegroundColor Yellow
    } else {
        Write-Host "  ✓ 환경 변수가 이미 설정되어 있습니다." -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ 환경 변수 설정 실패: $_" -ForegroundColor Red
    Write-Host "  수동으로 환경 변수를 설정해주세요: $flutterBinPath" -ForegroundColor Yellow
}

Write-Host "[6/6] Flutter 설정 확인 중..." -ForegroundColor Green
try {
    # 환경 변수를 현재 세션에 추가하여 flutter 명령어 테스트
    $env:Path = "$flutterBinPath;$env:Path"
    $flutterVersion = & "$flutterBinPath\flutter.bat" --version 2>&1 | Select-Object -First 1
    Write-Host "  ✓ Flutter 설치 확인: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Flutter 명령어 확인 실패 (새 터미널에서 확인 필요)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  설치 완료!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "1. PowerShell을 새로 열어주세요 (환경 변수 적용)" -ForegroundColor White
Write-Host "2. 다음 명령어로 설치 확인:" -ForegroundColor White
Write-Host "   flutter --version" -ForegroundColor Gray
Write-Host "   flutter doctor" -ForegroundColor Gray
Write-Host ""
Write-Host "3. VSCode에서 Flutter 확장 프로그램 설치:" -ForegroundColor White
Write-Host "   - VSCode 열기" -ForegroundColor Gray
Write-Host "   - 확장 프로그램에서 'Flutter' 검색 후 설치" -ForegroundColor Gray
Write-Host ""
Write-Host "4. 프로젝트 실행:" -ForegroundColor White
Write-Host "   cd D:\Project\DORA" -ForegroundColor Gray
Write-Host "   flutter pub get" -ForegroundColor Gray
Write-Host "   flutter run -d chrome" -ForegroundColor Gray
Write-Host ""
pause

