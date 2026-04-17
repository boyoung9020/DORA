# SYNC - 자동 릴리스 스크립트
# 버전 증가 + CHANGELOG 생성 + git tag + push
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1                  # 패치 릴리스
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -BumpType minor  # 마이너 릴리스
#   powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -DryRun          # 미리보기

param(
    [ValidateSet("major", "minor", "patch")]
    [string]$BumpType = "patch",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# 콘솔 및 git 출력 인코딩을 UTF-8로 강제
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:LC_ALL = "C.UTF-8"

# 프로젝트 루트로 이동
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $PROJECT_ROOT

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SYNC - Release ($BumpType)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. 워킹트리 클린 체크 ----
$status = git status --porcelain
if ($status) {
    Write-Host "[ERROR] 커밋되지 않은 변경사항이 있습니다. 먼저 커밋하세요." -ForegroundColor Red
    Write-Host $status -ForegroundColor Gray
    exit 1
}

# ---- 2. 현재 버전 읽기 ----
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $build = [int]$Matches[4]
} else {
    Write-Host "[ERROR] pubspec.yaml에서 버전을 찾을 수 없습니다." -ForegroundColor Red
    exit 1
}

$oldVersion = "$major.$minor.$patch+$build"

# ---- 3. 버전 증가 ----
switch ($BumpType) {
    "major" { $major++; $minor = 0; $patch = 0 }
    "minor" { $minor++; $patch = 0 }
    "patch" { $patch++ }
}
$build++

$newVersion = "$major.$minor.$patch+$build"
$tag = "v$major.$minor.$patch"

Write-Host "[1/5] 버전: $oldVersion -> $newVersion ($tag)" -ForegroundColor Yellow

# ---- 4. CHANGELOG 생성 ----
Write-Host "[2/5] CHANGELOG 생성..." -ForegroundColor Yellow

# 마지막 태그 찾기
$lastTag = $null
try {
    $lastTag = git describe --tags --abbrev=0 2>$null
} catch {}

if ($lastTag) {
    $commitRange = "$lastTag..HEAD"
    Write-Host "       이전 태그: $lastTag" -ForegroundColor Gray
} else {
    $commitRange = ""
    Write-Host "       첫 릴리스 (전체 커밋 포함)" -ForegroundColor Gray
}

# 커밋 메시지 수집
if ($commitRange) {
    $commits = git log $commitRange --pretty=format:"%s" --no-merges
} else {
    $commits = git log --pretty=format:"%s" --no-merges
}

# 카테고리별 분류
$categories = @{
    "feat"     = @()
    "fix"      = @()
    "refactor" = @()
    "docs"     = @()
    "perf"     = @()
    "style"    = @()
    "test"     = @()
    "chore"    = @()
    "other"    = @()
}

$categoryHeaders = @{
    "feat"     = "새로운 기능"
    "fix"      = "버그 수정"
    "refactor" = "리팩토링"
    "docs"     = "문서"
    "perf"     = "성능 개선"
    "style"    = "스타일"
    "test"     = "테스트"
    "chore"    = "기타 작업"
    "other"    = "기타"
}

foreach ($commit in $commits) {
    if ($commit -match '^(feat|fix|refactor|docs|perf|style|test|chore)(\(.+?\))?:\s*(.+)$') {
        $type = $Matches[1]
        $message = $Matches[3]
        $categories[$type] += $message
    } elseif ($commit.Trim() -ne "") {
        $categories["other"] += $commit.Trim()
    }
}

# CHANGELOG 섹션 생성
$date = Get-Date -Format "yyyy-MM-dd"
$changelogSection = "## [$tag] - $date`n"

$hasContent = $false
foreach ($type in @("feat", "fix", "refactor", "perf", "docs", "style", "test", "chore", "other")) {
    if ($categories[$type].Count -gt 0) {
        $header = $categoryHeaders[$type]
        $changelogSection += "`n### $header`n"
        foreach ($msg in $categories[$type]) {
            $changelogSection += "- $msg`n"
        }
        $hasContent = $true
    }
}

if (-not $hasContent) {
    $changelogSection += "`n- 유지보수 업데이트`n"
}

# CHANGELOG.md 업데이트
$changelogPath = "CHANGELOG.md"
if (Test-Path $changelogPath) {
    $existingChangelog = Get-Content $changelogPath -Raw
    # "# Changelog" 헤더 뒤에 새 섹션 삽입
    if ($existingChangelog -match '^# Changelog\r?\n') {
        $newChangelog = "# Changelog`n`n$changelogSection`n" + ($existingChangelog -replace '^# Changelog\r?\n+', '')
    } else {
        $newChangelog = "# Changelog`n`n$changelogSection`n$existingChangelog"
    }
} else {
    $newChangelog = "# Changelog`n`n$changelogSection"
}

# ---- DryRun 처리 ----
if ($DryRun) {
    Write-Host ""
    Write-Host "========== DRY RUN ==========" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "[pubspec.yaml] version: $oldVersion -> $newVersion" -ForegroundColor White
    Write-Host ""
    Write-Host "[CHANGELOG.md]" -ForegroundColor White
    Write-Host $changelogSection -ForegroundColor Gray
    Write-Host ""
    Write-Host "[git] commit: chore: release $tag" -ForegroundColor White
    Write-Host "[git] tag: $tag" -ForegroundColor White
    Write-Host "[git] push: origin --follow-tags" -ForegroundColor White
    Write-Host ""
    Write-Host "실제 실행하려면 -DryRun 플래그를 제거하세요." -ForegroundColor Magenta
    Write-Host "=============================" -ForegroundColor Magenta
    exit 0
}

# ---- 5. 파일 업데이트 ----
Write-Host "[3/5] 파일 업데이트..." -ForegroundColor Yellow

# pubspec.yaml 버전 업데이트
$pubspecContent = $pubspecContent -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion"
[System.IO.File]::WriteAllText((Resolve-Path $pubspecPath).Path, $pubspecContent, [System.Text.UTF8Encoding]::new($false))

# CHANGELOG.md 저장
[System.IO.File]::WriteAllText((Join-Path $PWD $changelogPath), $newChangelog, [System.Text.UTF8Encoding]::new($false))

Write-Host "       pubspec.yaml: $newVersion" -ForegroundColor Gray
Write-Host "       CHANGELOG.md: 업데이트 완료" -ForegroundColor Gray

# ---- 6. Git commit + tag + push ----
Write-Host "[4/5] Git commit & tag..." -ForegroundColor Yellow

git add pubspec.yaml CHANGELOG.md
git commit -m "chore: release $tag"
git tag $tag

Write-Host "       커밋 완료: chore: release $tag" -ForegroundColor Gray
Write-Host "       태그 생성: $tag" -ForegroundColor Gray

Write-Host "[5/5] Git push..." -ForegroundColor Yellow
git push origin main
git push origin $tag

# ---- 완료 ----
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  릴리스 완료! $tag" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  GitHub Actions에서 Windows 빌드가 시작됩니다." -ForegroundColor White
Write-Host "  확인: GitHub repo -> Actions 탭" -ForegroundColor Gray
Write-Host "  완료 후: GitHub repo -> Releases 에서 다운로드" -ForegroundColor Gray
Write-Host ""
