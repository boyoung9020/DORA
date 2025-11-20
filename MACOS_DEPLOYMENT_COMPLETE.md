# macOS 앱 배포 완전 가이드

## 📦 배포 방법 종류

1. **직접 배포** - 앱 파일을 직접 복사
2. **DMG 파일 배포** - 설치 이미지 파일 생성
3. **ZIP 파일 배포** - 압축 파일로 배포
4. **App Store 배포** - 공식 앱 스토어 배포

---

## 방법 1: 직접 배포 (가장 간단)

### 1단계: 앱 빌드

```bash
# 프로젝트 디렉토리에서
flutter build macos --release
```

### 2단계: 앱 파일 찾기

빌드된 앱 위치:
```
build/macos/Build/Products/Release/dora_project_manager.app
```

### 3단계: 다른 맥으로 복사

#### 옵션 A: USB 드라이브 사용
```bash
# USB 드라이브에 복사
cp -R build/macos/Build/Products/Release/dora_project_manager.app /Volumes/USB드라이브이름/
```

#### 옵션 B: 네트워크 공유 사용
```bash
# 서버에 업로드 (SCP 사용)
scp -r build/macos/Build/Products/Release/dora_project_manager.app user@server:/path/to/share/

# 또는 공유 폴더에 복사
cp -R build/macos/Build/Products/Release/dora_project_manager.app /Users/Shared/
```

#### 옵션 C: AirDrop 사용
1. Finder에서 `build/macos/Build/Products/Release/` 폴더 열기
2. `dora_project_manager.app` 우클릭
3. 공유 > AirDrop 선택
4. 대상 맥 선택

### 4단계: 앱 실행

다른 맥에서:
1. 앱 파일을 Applications 폴더로 이동 (선택사항)
2. 앱 더블 클릭
3. "확인되지 않은 개발자" 경고가 나오면:
   - 시스템 설정 > 개인정보 보호 및 보안
   - "확인 없이 열기" 클릭

---

## 방법 2: DMG 파일 배포 (권장)

DMG 파일은 macOS의 표준 설치 이미지 형식입니다.

### 1단계: DMG 생성 스크립트 만들기

`create_dmg.sh` 파일 생성:

```bash
#!/bin/bash
# DMG 파일 생성 스크립트

APP_NAME="dora_project_manager"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}_v1.0.0"
DMG_PATH="build/${DMG_NAME}.dmg"
VOLUME_NAME="DORA 프로젝트 관리"

# 앱이 빌드되어 있는지 확인
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 앱을 먼저 빌드해주세요: flutter build macos --release"
    exit 1
fi

# 임시 DMG 디렉토리 생성
TEMP_DIR="build/dmg_temp"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# 앱 복사
cp -R "$APP_PATH" "$TEMP_DIR/"

# Applications 폴더 링크 생성 (선택사항)
ln -s /Applications "$TEMP_DIR/Applications"

# DMG 파일 생성
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# 임시 디렉토리 삭제
rm -rf "$TEMP_DIR"

echo "✅ DMG 파일 생성 완료: $DMG_PATH"
echo "📦 파일 크기: $(du -h "$DMG_PATH" | cut -f1)"
```

### 2단계: DMG 생성

```bash
chmod +x create_dmg.sh
./create_dmg.sh
```

### 3단계: DMG 파일 배포

생성된 DMG 파일 위치:
```
build/dora_project_manager_v1.0.0.dmg
```

이 파일을:
- 이메일로 전송
- 클라우드 스토리지에 업로드 (iCloud, Google Drive, Dropbox 등)
- 웹사이트에 업로드
- USB 드라이브로 복사

### 4단계: 사용자가 설치

1. DMG 파일 더블 클릭
2. 열린 창에서 앱을 Applications 폴더로 드래그
3. Applications 폴더에서 앱 실행

---

## 방법 3: ZIP 파일 배포

### 1단계: ZIP 파일 생성

```bash
cd build/macos/Build/Products/Release/
zip -r ../../../dora_project_manager.zip dora_project_manager.app
cd ../../../../..
```

또는 스크립트로:

```bash
#!/bin/bash
# ZIP 파일 생성 스크립트

APP_NAME="dora_project_manager"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
ZIP_PATH="build/${APP_NAME}.zip"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 앱을 먼저 빌드해주세요: flutter build macos --release"
    exit 1
fi

cd build/macos/Build/Products/Release/
zip -r "../../../../${ZIP_PATH}" "${APP_NAME}.app"
cd ../../../../..

echo "✅ ZIP 파일 생성 완료: $ZIP_PATH"
```

### 2단계: ZIP 파일 배포

생성된 ZIP 파일을 공유하면 됩니다.

---

## 방법 4: App Store 배포 (공식 배포)

### 1단계: Apple Developer 계정 필요

- Apple Developer Program 가입 ($99/년)
- https://developer.apple.com 에서 가입

### 2단계: 코드 서명 설정

#### Xcode에서 설정:

1. `macos/Runner.xcworkspace` 파일을 Xcode로 열기
2. Runner 타겟 선택
3. Signing & Capabilities 탭:
   - Team 선택 (Apple Developer 계정)
   - Automatically manage signing 체크
   - Bundle Identifier 확인 (예: `com.yourcompany.dora`)

### 3단계: 앱 정보 설정

`macos/Runner/Configs/AppInfo.xcconfig` 파일 수정:

```
PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.dora
PRODUCT_NAME = DORA
```

### 4단계: 앱 아카이브 생성

```bash
# 릴리스 빌드
flutter build macos --release

# Xcode에서 아카이브
# 1. Xcode에서 Product > Archive
# 2. Organizer 창에서 Distribute App 클릭
# 3. App Store Connect 선택
# 4. 업로드 완료
```

### 5단계: App Store Connect에서 설정

1. https://appstoreconnect.apple.com 접속
2. 새 앱 추가
3. 앱 정보 입력
4. 빌드 선택 및 제출

---

## 🔧 배포 전 체크리스트

### 필수 확인 사항

- [ ] 앱이 정상적으로 빌드되는지 확인
- [ ] API 서버 주소가 올바른지 확인 (`lib/utils/api_client.dart`)
- [ ] 앱 아이콘 설정 확인
- [ ] 앱 이름 확인 (`macos/Runner/Configs/AppInfo.xcconfig`)
- [ ] Bundle Identifier 확인
- [ ] 네트워크 권한 확인 (Entitlements 파일)

### 테스트 항목

- [ ] 앱 실행 테스트
- [ ] 로그인 기능 테스트
- [ ] 서버 연결 테스트
- [ ] 모든 기능 동작 확인

---

## 📋 빠른 배포 스크립트

### 전체 배포 스크립트 (`deploy_macos.sh`)

```bash
#!/bin/bash
# macOS 앱 빌드 및 배포 스크립트

set -e

APP_NAME="dora_project_manager"
VERSION="1.0.0"

echo "=== DORA macOS 앱 빌드 및 배포 ==="
echo ""

# 1. 의존성 설치
echo "1. Flutter 의존성 설치 중..."
flutter pub get

# 2. macOS 의존성 설치
echo "2. macOS 의존성 설치 중..."
cd macos
if command -v pod &> /dev/null; then
    pod install
else
    echo "⚠️  CocoaPods가 설치되어 있지 않습니다."
fi
cd ..

# 3. 클린 빌드
echo "3. 클린 빌드 중..."
flutter clean
flutter pub get

# 4. 릴리스 빌드
echo "4. 릴리스 빌드 중..."
flutter build macos --release

# 5. 배포 파일 생성
echo "5. 배포 파일 생성 중..."

APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
BUILD_DIR="build/deploy"

# 배포 디렉토리 생성
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 앱 복사
cp -R "$APP_PATH" "$BUILD_DIR/"

# ZIP 파일 생성
cd "$BUILD_DIR"
zip -r "../${APP_NAME}_v${VERSION}.zip" "${APP_NAME}.app"
cd ../..

# DMG 파일 생성 (선택사항)
if command -v hdiutil &> /dev/null; then
    echo "6. DMG 파일 생성 중..."
    TEMP_DMG="build/dmg_temp"
    rm -rf "$TEMP_DMG"
    mkdir -p "$TEMP_DMG"
    
    cp -R "$APP_PATH" "$TEMP_DMG/"
    ln -s /Applications "$TEMP_DMG/Applications"
    
    hdiutil create -volname "DORA 프로젝트 관리" \
        -srcfolder "$TEMP_DMG" \
        -ov -format UDZO \
        "build/${APP_NAME}_v${VERSION}.dmg"
    
    rm -rf "$TEMP_DMG"
fi

echo ""
echo "✅ 배포 준비 완료!"
echo ""
echo "📦 생성된 파일:"
echo "   - 앱: $APP_PATH"
echo "   - ZIP: build/${APP_NAME}_v${VERSION}.zip"
if [ -f "build/${APP_NAME}_v${VERSION}.dmg" ]; then
    echo "   - DMG: build/${APP_NAME}_v${VERSION}.dmg"
fi
echo ""
echo "🚀 배포 방법:"
echo "   1. ZIP 또는 DMG 파일을 공유"
echo "   2. 사용자가 다운로드 후 설치"
echo "   3. Applications 폴더로 이동 후 실행"
```

---

## 🔐 코드 서명 및 공증 (선택사항)

### 개발자 ID로 서명 (App Store 외 배포)

```bash
# 개발자 ID 인증서 필요
codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: Your Name" \
    build/macos/Build/Products/Release/dora_project_manager.app

# 공증 (notarization)
xcrun notarytool submit \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "app-specific-password" \
    build/dora_project_manager_v1.0.0.dmg
```

---

## 📤 배포 채널

### 1. 이메일
- ZIP 또는 DMG 파일 첨부
- 파일 크기 제한 확인 (일반적으로 25MB)

### 2. 클라우드 스토리지
- iCloud Drive
- Google Drive
- Dropbox
- OneDrive

### 3. 웹사이트
- 직접 다운로드 링크 제공
- 파일 호스팅 서비스 사용

### 4. 내부 네트워크
- 공유 폴더에 배치
- 네트워크 드라이브 마운트

---

## 🎯 권장 배포 방법

**소규모 배포 (10명 이하):**
- 직접 배포 또는 AirDrop

**중규모 배포 (10-100명):**
- DMG 파일 + 클라우드 스토리지

**대규모 배포 (100명 이상):**
- App Store 배포 또는 자체 업데이트 서버

---

## ❓ 문제 해결

### "확인되지 않은 개발자" 경고

해결:
1. 시스템 설정 > 개인정보 보호 및 보안
2. "확인 없이 열기" 클릭
3. 또는 개발자 ID로 코드 서명

### 앱이 실행되지 않음

확인:
- macOS 버전 호환성
- 네트워크 권한
- 서버 연결 가능 여부

### 빌드 오류

```bash
flutter clean
rm -rf macos/Pods macos/Podfile.lock
cd macos && pod install && cd ..
flutter build macos --release
```

---

## 📝 요약

가장 간단한 배포 방법:
1. `flutter build macos --release`
2. `build/macos/Build/Products/Release/dora_project_manager.app` 복사
3. 다른 맥으로 전송
4. Applications 폴더로 이동 후 실행

더 전문적인 배포:
1. DMG 파일 생성
2. 코드 서명 (선택사항)
3. 클라우드 스토리지에 업로드
4. 다운로드 링크 공유

