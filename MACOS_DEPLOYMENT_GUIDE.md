# macOS 배포 가이드

## ✅ macOS 배포 가능 여부

**네, macOS에도 배포 가능합니다!** Flutter는 크로스 플랫폼 프레임워크이므로 Windows, macOS, Linux 모두 지원합니다.

현재 프로젝트에는 이미 macOS 설정이 포함되어 있습니다:

- ✅ `macos/` 폴더 존재
- ✅ Xcode 프로젝트 설정 완료
- ✅ Info.plist 설정 완료
- ✅ 앱 아이콘 설정 완료

## 🚀 macOS에서 실행 방법

### 1. macOS 개발 환경 요구사항

- macOS 10.14 이상
- Xcode (App Store에서 설치)
- Flutter SDK
- CocoaPods (iOS/macOS 의존성 관리)

### 2. CocoaPods 설치 (필요한 경우)

```bash
sudo gem install cocoapods
```

### 3. 의존성 설치

```bash
cd macos
pod install
cd ..
```

### 4. 앱 실행

```bash
# 개발 모드로 실행
flutter run -d macos

# 또는 특정 디바이스 선택
flutter devices  # 사용 가능한 디바이스 확인
flutter run -d macos
```

## 📦 macOS 앱 빌드

### 개발 빌드

```bash
flutter build macos
```

빌드 결과물 위치: `build/macos/Build/Products/Debug/dora_project_manager.app`

### 릴리스 빌드

```bash
flutter build macos --release
```

빌드 결과물 위치: `build/macos/Build/Products/Release/dora_project_manager.app`

## 🔧 macOS 설정 확인

### 1. Bundle Identifier 확인

`macos/Runner/Configs/AppInfo.xcconfig` 파일에서:

```
PRODUCT_BUNDLE_IDENTIFIER = com.example.doraProjectManager
```

필요시 변경하세요.

### 2. 앱 이름 확인

`macos/Runner/Configs/AppInfo.xcconfig` 파일에서:

```
PRODUCT_NAME = dora_project_manager
```

### 3. 최소 macOS 버전 확인

`macos/Runner.xcodeproj/project.pbxproj`에서 `MACOSX_DEPLOYMENT_TARGET` 확인

## 🌐 네트워크 설정 (중요!)

macOS 앱이 서버에 접근하려면 네트워크 권한이 필요합니다.

### 1. Entitlements 파일 확인

`macos/Runner/DebugProfile.entitlements`와 `macos/Runner/Release.entitlements`에 다음이 포함되어 있는지 확인:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### 2. Info.plist 네트워크 권한

`macos/Runner/Info.plist`에 다음 추가 (필요한 경우):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 📝 API 서버 주소 설정

macOS 앱도 서버에 연결하려면 `lib/utils/api_client.dart`에서 서버 주소를 확인하세요:

```dart
static const String baseUrl = 'http://192.168.1.102';
```

## 🍎 App Store 배포 (선택사항)

### 1. 코드 서명 설정

1. Xcode에서 `macos/Runner.xcworkspace` 열기
2. Runner 타겟 선택
3. Signing & Capabilities 탭에서:
   - Team 선택 (Apple Developer 계정 필요)
   - Automatically manage signing 체크

### 2. 앱 아카이브 생성

```bash
flutter build macos --release
```

### 3. Xcode에서 아카이브

1. Xcode에서 Product > Archive
2. Organizer에서 Distribute App 선택
3. App Store Connect 또는 직접 배포 선택

## 🔍 문제 해결

### CocoaPods 오류

```bash
cd macos
pod deintegrate
pod install
cd ..
```

### 빌드 오류

```bash
flutter clean
flutter pub get
cd macos && pod install && cd ..
flutter build macos
```

### 네트워크 연결 오류

1. macOS 방화벽 설정 확인
2. Entitlements 파일에 네트워크 권한 확인
3. 서버 주소가 올바른지 확인

## 📋 체크리스트

- [ ] macOS 개발 환경 설정 (Xcode, Flutter)
- [ ] CocoaPods 설치 및 의존성 설치
- [ ] API 서버 주소 설정 (`api_client.dart`)
- [ ] 네트워크 권한 설정 (Entitlements)
- [ ] 앱 실행 테스트 (`flutter run -d macos`)
- [ ] 릴리스 빌드 테스트 (`flutter build macos --release`)

## 💡 참고사항

1. **Windows와 동일한 코드 사용**: Flutter는 같은 코드베이스로 Windows, macOS, Linux 모두 빌드 가능
2. **서버 주소**: macOS 앱도 같은 서버(`192.168.1.102`)에 연결
3. **데이터 공유**: Windows와 macOS 앱이 같은 서버를 사용하므로 데이터가 공유됨

## 🎯 요약

- ✅ macOS 배포 가능
- ✅ 현재 프로젝트에 macOS 설정 포함됨
- ✅ Windows와 동일한 코드 사용
- ✅ 같은 서버에 연결하여 데이터 공유

macOS에서 `flutter run -d macos` 명령어로 실행하면 됩니다!
