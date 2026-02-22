# Flutter ?먮룞 ?ㅼ튂 ?ㅽ겕由쏀듃
# 愿由ъ옄 沅뚰븳?쇰줈 ?ㅽ뻾 ?꾩슂

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flutter SDK ?먮룞 ?ㅼ튂 ?ㅽ겕由쏀듃" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 愿由ъ옄 沅뚰븳 ?뺤씤
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "?좑툘  愿由ъ옄 沅뚰븳???꾩슂?⑸땲??" -ForegroundColor Red
    Write-Host "PowerShell??愿由ъ옄 沅뚰븳?쇰줈 ?ㅽ뻾?????ㅼ떆 ?쒕룄?섏꽭??" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "諛⑸쾿: PowerShell ?꾩씠肄??고겢由?> '愿由ъ옄 沅뚰븳?쇰줈 ?ㅽ뻾'" -ForegroundColor Yellow
    pause
    exit 1
}

# Flutter SDK ?ㅼ튂 寃쎈줈
$flutterPath = "C:\src\flutter"
$flutterBinPath = "$flutterPath\bin"
$flutterRepo = "https://github.com/flutter/flutter.git"

Write-Host "[1/6] Git ?ㅼ튂 ?뺤씤..." -ForegroundColor Green
try {
    $gitVersion = git --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git???ㅼ튂?섏뼱 ?덉? ?딆뒿?덈떎"
    }
    Write-Host "  ??Git ?ㅼ튂?? $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "  ??Git???ㅼ튂?섏뼱 ?덉? ?딆뒿?덈떎!" -ForegroundColor Red
    Write-Host "  Git??癒쇱? ?ㅼ튂?댁＜?몄슂: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "  ?먮뒗 ?섎룞 ?ㅼ튂 諛⑸쾿??李멸퀬?섏꽭??" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "[2/6] Flutter SDK ?ㅼ튂 寃쎈줈 ?뺤씤..." -ForegroundColor Green
if (Test-Path $flutterPath) {
    Write-Host "  ?좑툘  $flutterPath 寃쎈줈???대? Flutter媛 ?ㅼ튂?섏뼱 ?덉뒿?덈떎." -ForegroundColor Yellow
    $overwrite = Read-Host "  ??뼱?곗떆寃좎뒿?덇퉴? (y/n)"
    if ($overwrite -ne "y") {
        Write-Host "  ?ㅼ튂瑜?痍⑥냼?덉뒿?덈떎." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "  湲곗〈 ?ㅼ튂 ?쒓굅 以?.." -ForegroundColor Yellow
    Remove-Item $flutterPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "[3/6] C:\src ?대뜑 ?앹꽦..." -ForegroundColor Green
try {
    if (-not (Test-Path "C:\src")) {
        New-Item -ItemType Directory -Path "C:\src" -Force | Out-Null
        Write-Host "  ???대뜑 ?앹꽦 ?꾨즺" -ForegroundColor Green
    } else {
        Write-Host "  ???대뜑 ?대? 議댁옱" -ForegroundColor Green
    }
} catch {
    Write-Host "  ???대뜑 ?앹꽦 ?ㅽ뙣: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[4/6] Flutter SDK ?대줎 以?.." -ForegroundColor Green
Write-Host "  ??μ냼: $flutterRepo" -ForegroundColor Gray
Write-Host "  ???묒뾽? 紐?遺꾩씠 嫄몃┫ ???덉뒿?덈떎..." -ForegroundColor Yellow
try {
    Push-Location "C:\src"
    git clone -b stable $flutterRepo
    if ($LASTEXITCODE -ne 0) {
        throw "Git clone ?ㅽ뙣"
    }
    Write-Host "  ???대줎 ?꾨즺" -ForegroundColor Green
    Pop-Location
} catch {
    Pop-Location
    Write-Host "  ???대줎 ?ㅽ뙣: $_" -ForegroundColor Red
    Write-Host "  ?ㅽ듃?뚰겕 ?곌껐???뺤씤?섍굅???섎룞 ?ㅼ튂瑜??쒕룄?섏꽭??" -ForegroundColor Yellow
    exit 1
}

Write-Host "[5/6] ?섍꼍 蹂???ㅼ젙 以?.." -ForegroundColor Green
try {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if ($currentPath -notlike "*$flutterBinPath*") {
        $newPath = "$currentPath;$flutterBinPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "  ???섍꼍 蹂??異붽? ?꾨즺" -ForegroundColor Green
        Write-Host "  ?좑툘  ???곕??먯쓣 ?댁뼱???섍꼍 蹂?섍? ?곸슜?⑸땲??" -ForegroundColor Yellow
    } else {
        Write-Host "  ???섍꼍 蹂?섍? ?대? ?ㅼ젙?섏뼱 ?덉뒿?덈떎." -ForegroundColor Green
    }
} catch {
    Write-Host "  ???섍꼍 蹂???ㅼ젙 ?ㅽ뙣: $_" -ForegroundColor Red
    Write-Host "  ?섎룞?쇰줈 ?섍꼍 蹂?섎? ?ㅼ젙?댁＜?몄슂: $flutterBinPath" -ForegroundColor Yellow
}

Write-Host "[6/6] Flutter ?ㅼ젙 ?뺤씤 以?.." -ForegroundColor Green
try {
    # ?섍꼍 蹂?섎? ?꾩옱 ?몄뀡??異붽??섏뿬 flutter 紐낅졊???뚯뒪??
    $env:Path = "$flutterBinPath;$env:Path"
    $flutterVersion = & "$flutterBinPath\flutter.bat" --version 2>&1 | Select-Object -First 1
    Write-Host "  ??Flutter ?ㅼ튂 ?뺤씤: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "  ?좑툘  Flutter 紐낅졊???뺤씤 ?ㅽ뙣 (???곕??먯뿉???뺤씤 ?꾩슂)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ?ㅼ튂 ?꾨즺!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "?ㅼ쓬 ?④퀎:" -ForegroundColor Yellow
Write-Host "1. PowerShell???덈줈 ?댁뼱二쇱꽭??(?섍꼍 蹂???곸슜)" -ForegroundColor White
Write-Host "2. ?ㅼ쓬 紐낅졊?대줈 ?ㅼ튂 ?뺤씤:" -ForegroundColor White
Write-Host "   flutter --version" -ForegroundColor Gray
Write-Host "   flutter doctor" -ForegroundColor Gray
Write-Host ""
Write-Host "3. VSCode?먯꽌 Flutter ?뺤옣 ?꾨줈洹몃옩 ?ㅼ튂:" -ForegroundColor White
Write-Host "   - VSCode ?닿린" -ForegroundColor Gray
Write-Host "   - ?뺤옣 ?꾨줈洹몃옩?먯꽌 'Flutter' 寃?????ㅼ튂" -ForegroundColor Gray
Write-Host ""
Write-Host "4. ?꾨줈?앺듃 ?ㅽ뻾:" -ForegroundColor White
Write-Host "   cd D:\Project\SYNC" -ForegroundColor Gray
Write-Host "   flutter pub get" -ForegroundColor Gray
Write-Host "   flutter run -d chrome" -ForegroundColor Gray
Write-Host ""
pause

