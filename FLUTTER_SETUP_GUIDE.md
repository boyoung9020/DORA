# Flutter 설치 가이드 (VSCode)

## 📋 단계별 설치 방법

### 1단계: Flutter SDK 다운로드 및 설치

1. **Flutter SDK 다운로드**

   - https://docs.flutter.dev/get-started/install/windows 방문
   - "Download Flutter SDK" 클릭하여 최신 버전 다운로드
   - 또는 직접 다운로드: https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.x.x-stable.zip

2. **Flutter SDK 압축 해제**

   - 다운로드한 zip 파일을 원하는 위치에 압축 해제
   - 권장 경로: `C:\src\flutter` 또는 `D:\flutter`
   - ⚠️ **중요**: 경로에 공백이나 특수문자가 없어야 합니다!

3. **환경 변수 설정**

   - Windows 검색에서 "환경 변수" 검색
   - "시스템 환경 변수 편집" 선택
   - "환경 변수" 버튼 클릭
   - "시스템 변수" 섹션에서 `Path` 선택 후 "편집"
   - "새로 만들기" 클릭
   - Flutter SDK의 `bin` 폴더 경로 추가 (예: `C:\src\flutter\bin`)
   - 모든 창에서 "확인" 클릭

4. **환경 변수 적용 확인**
   - PowerShell 또는 명령 프롬프트를 **새로 열기**
   - 다음 명령어 실행:
   ```bash
   flutter --version
   ```
   - 버전 정보가 표시되면 성공!

### 2단계: VSCode 확장 프로그램 설치

1. **VSCode 열기**

   - Visual Studio Code 실행

2. **Flutter 확장 설치**
   - 왼쪽 사이드바에서 확장 프로그램 아이콘 클릭 (또는 `Ctrl+Shift+X`)
   - 검색창에 "Flutter" 입력
   - **Flutter** 확장 프로그램 설치 (Dart 확장도 자동 설치됨)
   - 설치 후 VSCode 재시작

### 3단계: Flutter Doctor 실행

1. **명령 팔레트 열기**

   - `Ctrl+Shift+P` 누르기

2. **Flutter Doctor 실행**

   - "Flutter: Run Flutter Doctor" 입력 후 선택
   - 또는 터미널에서 `flutter doctor` 실행

3. **문제 해결**
   - 빨간색 X 표시가 있으면 해당 항목 설치 필요
   - Android Studio, Chrome 등 필요한 도구 설치

### 4단계: 프로젝트 실행

#### 방법 1: VSCode에서 실행

1. VSCode에서 프로젝트 폴더 열기
2. `F5` 키 누르기 (디버그 모드)
3. 또는 하단 상태바에서 실행 디바이스 선택 후 실행

#### 방법 2: 터미널에서 실행

```bash
# 의존성 설치
flutter pub get

# 웹 브라우저에서 실행
flutter run -d chrome

# Windows 앱으로 실행
flutter run -d windows
```

## 🔧 빠른 설치 스크립트 (PowerShell)

PowerShell을 관리자 권한으로 실행한 후:

```powershell
# Flutter SDK 다운로드 경로 설정
$flutterPath = "C:\src\flutter"

# Flutter SDK 다운로드 (최신 버전)
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_stable.zip"
$zipPath = "$env:TEMP\flutter.zip"

Write-Host "Flutter SDK 다운로드 중..." -ForegroundColor Green
Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath

# 압축 해제
Write-Host "압축 해제 중..." -ForegroundColor Green
Expand-Archive -Path $zipPath -DestinationPath "C:\src" -Force

# 환경 변수 추가
Write-Host "환경 변수 설정 중..." -ForegroundColor Green
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$flutterPath\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterPath\bin", "Machine")
    Write-Host "환경 변수가 추가되었습니다. 새 터미널을 열어주세요." -ForegroundColor Yellow
}

# 정리
Remove-Item $zipPath

Write-Host "설치 완료! 새 터미널에서 'flutter doctor'를 실행하세요." -ForegroundColor Green
```

## ✅ 설치 확인

터미널에서 다음 명령어들을 실행하여 확인:

```bash
# Flutter 버전 확인
flutter --version

# Flutter 상태 확인
flutter doctor

# 사용 가능한 디바이스 확인
flutter devices
```

## 🚀 프로젝트 실행

설치가 완료되면:

```bash
# 프로젝트 디렉토리로 이동
cd D:\Project\DORA

# 의존성 설치
flutter pub get

# 실행 (웹)
flutter run -d chrome

# 또는 실행 (Windows)
flutter run -d windows
```

## 📝 기본 관리자 계정

앱 실행 후 로그인:

- **사용자 이름**: `admin`
- **비밀번호**: `admin123`
- **이메일**: `admin@dora.com`

## 🆘 문제 해결

### Flutter 명령어를 찾을 수 없음

- 환경 변수 설정 후 **새 터미널**을 열어야 합니다
- 또는 컴퓨터를 재시작하세요

### VSCode에서 Flutter를 인식하지 못함

- VSCode를 완전히 종료 후 다시 실행
- Flutter 확장 프로그램이 설치되었는지 확인

### flutter doctor 오류

- Android Studio 설치 필요 (Android 개발 시)
- Chrome 설치 필요 (웹 개발 시)
- Git 설치 필요

