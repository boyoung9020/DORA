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
    echo "   설치: sudo gem install cocoapods"
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
if [ -d "$APP_PATH" ]; then
    cp -R "$APP_PATH" "$BUILD_DIR/"
    echo "✅ 앱 복사 완료: $BUILD_DIR/${APP_NAME}.app"
else
    echo "❌ 앱 파일을 찾을 수 없습니다: $APP_PATH"
    exit 1
fi

# ZIP 파일 생성
echo "6. ZIP 파일 생성 중..."
cd "$BUILD_DIR"
zip -r "../${APP_NAME}_v${VERSION}.zip" "${APP_NAME}.app" > /dev/null
cd ../..
echo "✅ ZIP 파일 생성 완료: build/${APP_NAME}_v${VERSION}.zip"

# DMG 파일 생성 (선택사항)
if command -v hdiutil &> /dev/null; then
    echo "7. DMG 파일 생성 중..."
    TEMP_DMG="build/dmg_temp"
    rm -rf "$TEMP_DMG"
    mkdir -p "$TEMP_DMG"
    
    cp -R "$APP_PATH" "$TEMP_DMG/"
    ln -s /Applications "$TEMP_DMG/Applications"
    
    DMG_PATH="build/${APP_NAME}_v${VERSION}.dmg"
    hdiutil create -volname "DORA 프로젝트 관리" \
        -srcfolder "$TEMP_DMG" \
        -ov -format UDZO \
        "$DMG_PATH" > /dev/null
    
    rm -rf "$TEMP_DMG"
    echo "✅ DMG 파일 생성 완료: $DMG_PATH"
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
echo ""
echo "📋 파일 크기:"
if [ -f "build/${APP_NAME}_v${VERSION}.zip" ]; then
    echo "   ZIP: $(du -h "build/${APP_NAME}_v${VERSION}.zip" | cut -f1)"
fi
if [ -f "build/${APP_NAME}_v${VERSION}.dmg" ]; then
    echo "   DMG: $(du -h "build/${APP_NAME}_v${VERSION}.dmg" | cut -f1)"
fi

