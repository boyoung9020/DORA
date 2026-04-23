# Windows EXE ?뚯씪 諛고룷 媛?대뱶

## ??Windows 諛고룷 媛???щ?

**?? Windows?먮룄 諛고룷 媛?ν빀?덈떎!** Flutter??Windows ?깆쓣 鍮뚮뱶?????덉쑝硫? `.exe` ?뚯씪濡?諛고룷?????덉뒿?덈떎.

?꾩옱 ?꾨줈?앺듃?먮뒗 ?대? Windows ?ㅼ젙???ы븿?섏뼱 ?덉뒿?덈떎:
- ??`windows/` ?대뜑 議댁옱
- ??CMake ?ㅼ젙 ?꾨즺
- ?????꾩씠肄??ㅼ젙 ?꾨즺

## ?? Windows?먯꽌 ?ㅽ뻾 諛⑸쾿

### 1. Windows 媛쒕컻 ?섍꼍 ?붽뎄?ы빆

- Windows 10 ?댁긽
- Visual Studio 2022 (Community 踰꾩쟾 ?댁긽)
  - "Desktop development with C++" ?뚰겕濡쒕뱶 ?ㅼ튂 ?꾩슂
- Flutter SDK
- Git

### 2. Visual Studio ?ㅼ튂

1. [Visual Studio 2022 Community](https://visualstudio.microsoft.com/downloads/) ?ㅼ슫濡쒕뱶
2. ?ㅼ튂 ???ㅼ쓬 ?뚰겕濡쒕뱶 ?좏깮:
   - **Desktop development with C++**
   - **Windows 10/11 SDK** (理쒖떊 踰꾩쟾)

### 3. Flutter Windows 吏???뺤씤

```bash
flutter doctor
```

?ㅼ쓬 ??ぉ??泥댄겕?섏뼱???⑸땲??
- ??Windows toolchain
- ??Visual Studio

### 4. ???ㅽ뻾

```bash
# 媛쒕컻 紐⑤뱶濡??ㅽ뻾
flutter run -d windows

# ?먮뒗 ?뱀젙 ?붾컮?댁뒪 ?좏깮
flutter devices  # ?ъ슜 媛?ν븳 ?붾컮?댁뒪 ?뺤씤
flutter run -d windows
```

## ?벀 Windows ??鍮뚮뱶

### 媛쒕컻 鍮뚮뱶

```bash
flutter build windows
```

鍮뚮뱶 寃곌낵臾??꾩튂: `build/windows/x64/runner/Debug/sync_project_manager.exe`

### 由대━??鍮뚮뱶 (諛고룷??

```bash
flutter build windows --release
```

鍮뚮뱶 寃곌낵臾??꾩튂: `build/windows/x64/runner/Release/sync_project_manager.exe`

## ?뱥 鍮뚮뱶 寃곌낵臾?援ъ“

由대━??鍮뚮뱶 ???ㅼ쓬 ?뚯씪?ㅼ씠 ?앹꽦?⑸땲??

```
build/windows/x64/runner/Release/
?쒋?? sync_project_manager.exe          # ?ㅽ뻾 ?뚯씪
?쒋?? flutter_windows.dll              # Flutter ?고???
?쒋?? data/                            # ???곗씠??
??  ?붴?? flutter_assets/              # 由ъ냼???뚯씪
?붴?? [湲고? DLL ?뚯씪??                 # ?섏〈???쇱씠釉뚮윭由?
```

## ?렞 EXE ?뚯씪 諛고룷 諛⑸쾿

### 諛⑸쾿 1: ?꾩껜 ?대뜑 諛고룷 (沅뚯옣)

由대━??鍮뚮뱶 ??`Release` ?대뜑 ?꾩껜瑜?諛고룷:

```bash
# 鍮뚮뱶
flutter build windows --release

# 諛고룷 ?대뜑 ?앹꽦
mkdir build/deploy/windows
cp -r build/windows/x64/runner/Release/* build/deploy/windows/
```

**諛고룷 諛⑸쾿:**
- ZIP ?뚯씪濡??뺤텞
- USB ?쒕씪?대툕濡?蹂듭궗
- ?ㅽ듃?뚰겕 怨듭쑀 ?대뜑??諛곗튂
- ?대씪?곕뱶 ?ㅽ넗由ъ????낅줈??

### 諛⑸쾿 2: ?⑥씪 EXE ?뚯씪 (怨좉툒)

紐⑤뱺 ?섏〈?깆쓣 EXE???ы븿?섎젮硫?異붽? ?ㅼ젙???꾩슂?⑸땲?? (沅뚯옣?섏? ?딆쓬)

## ?뵩 Windows ?ㅼ젙 ?뺤씤

### 1. ???대쫫 ?뺤씤

`windows/CMakeLists.txt` ?뚯씪?먯꽌:
```
set(BINARY_NAME "sync_project_manager")
```

### 2. ???꾩씠肄??뺤씤

`windows/runner/resources/app_icon.ico` ?뚯씪???덈뒗吏 ?뺤씤

### 3. 理쒖냼 Windows 踰꾩쟾 ?뺤씤

`windows/CMakeLists.txt`?먯꽌 Windows SDK 踰꾩쟾 ?뺤씤

## ?뱷 API ?쒕쾭 二쇱냼 ?ㅼ젙

Windows ?깅룄 ?쒕쾭???곌껐?섎젮硫?`lib/utils/api_client.dart`?먯꽌 ?쒕쾭 二쇱냼瑜??뺤씤?섏꽭??

```dart
static const String baseUrl = 'http://192.168.1.102';
```

## ?? 鍮좊Ⅸ 諛고룷 ?ㅽ겕由쏀듃

### PowerShell ?ㅽ겕由쏀듃 (`build_windows.ps1`)

```powershell
# Windows ??鍮뚮뱶 諛?諛고룷 ?ㅽ겕由쏀듃

$APP_NAME = "sync_project_manager"
$VERSION = "1.0.0"

Write-Host "=== SYNC Windows ??鍮뚮뱶 諛?諛고룷 ===" -ForegroundColor Green
Write-Host ""

# 1. ?섏〈???ㅼ튂
Write-Host "1. Flutter ?섏〈???ㅼ튂 以?.." -ForegroundColor Yellow
flutter pub get

# 2. ?대┛ 鍮뚮뱶
Write-Host "2. ?대┛ 鍮뚮뱶 以?.." -ForegroundColor Yellow
flutter clean
flutter pub get

# 3. 由대━??鍮뚮뱶
Write-Host "3. 由대━??鍮뚮뱶 以?.." -ForegroundColor Yellow
flutter build windows --release

# 4. 諛고룷 ?뚯씪 ?앹꽦
Write-Host "4. 諛고룷 ?뚯씪 ?앹꽦 以?.." -ForegroundColor Yellow

$BUILD_DIR = "build\deploy\windows"
$RELEASE_DIR = "build\windows\x64\runner\Release"

# 諛고룷 ?붾젆?좊━ ?앹꽦
if (Test-Path $BUILD_DIR) {
    Remove-Item -Recurse -Force $BUILD_DIR
}
New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null

# ?뚯씪 蹂듭궗
Copy-Item -Path "$RELEASE_DIR\*" -Destination $BUILD_DIR -Recurse -Force

Write-Host "???뚯씪 蹂듭궗 ?꾨즺: $BUILD_DIR" -ForegroundColor Green

# ZIP ?뚯씪 ?앹꽦
Write-Host "5. ZIP ?뚯씪 ?앹꽦 以?.." -ForegroundColor Yellow
$ZIP_PATH = "build\${APP_NAME}_v${VERSION}_windows.zip"
Compress-Archive -Path "$BUILD_DIR\*" -DestinationPath $ZIP_PATH -Force

Write-Host ""
Write-Host "??諛고룷 以鍮??꾨즺!" -ForegroundColor Green
Write-Host ""
Write-Host "?벀 ?앹꽦???뚯씪:" -ForegroundColor Cyan
Write-Host "   - EXE: $RELEASE_DIR\sync_project_manager.exe"
Write-Host "   - 諛고룷 ?대뜑: $BUILD_DIR"
Write-Host "   - ZIP: $ZIP_PATH"
Write-Host ""
Write-Host "?? 諛고룷 諛⑸쾿:" -ForegroundColor Cyan
Write-Host "   1. $BUILD_DIR ?대뜑 ?꾩껜瑜?蹂듭궗"
Write-Host "   2. ?먮뒗 ZIP ?뚯씪??怨듭쑀"
Write-Host "   3. ?ъ슜?먭? ?뺤텞 ?댁젣 ??sync_project_manager.exe ?ㅽ뻾"
```

## ?뵇 臾몄젣 ?닿껐

### 鍮뚮뱶 ?ㅻ쪟

```bash
flutter clean
flutter pub get
flutter build windows --release
```

### Visual Studio ?ㅻ쪟

- Visual Studio 2022媛 ?ㅼ튂?섏뼱 ?덈뒗吏 ?뺤씤
- "Desktop development with C++" ?뚰겕濡쒕뱶媛 ?ㅼ튂?섏뼱 ?덈뒗吏 ?뺤씤
- Windows SDK媛 ?ㅼ튂?섏뼱 ?덈뒗吏 ?뺤씤

### ?ㅽ뻾 ?ㅻ쪟

- 紐⑤뱺 DLL ?뚯씪??EXE? 媛숈? ?대뜑???덈뒗吏 ?뺤씤
- `data/flutter_assets` ?대뜑媛 ?덈뒗吏 ?뺤씤
- Windows Defender??諛깆떊 ?꾨줈洹몃옩??李⑤떒?섏? ?딅뒗吏 ?뺤씤

## ?뱥 泥댄겕由ъ뒪??

- [ ] Windows 媛쒕컻 ?섍꼍 ?ㅼ젙 (Visual Studio, Flutter)
- [ ] API ?쒕쾭 二쇱냼 ?ㅼ젙 (`api_client.dart`)
- [ ] ???ㅽ뻾 ?뚯뒪??(`flutter run -d windows`)
- [ ] 由대━??鍮뚮뱶 ?뚯뒪??(`flutter build windows --release`)
- [ ] ?ㅻⅨ Windows PC?먯꽌 ?ㅽ뻾 ?뚯뒪??

## ?뮕 李멸퀬?ы빆

1. **Windows? ?숈씪??肄붾뱶 ?ъ슜**: Flutter??媛숈? 肄붾뱶踰좎씠?ㅻ줈 Windows, macOS, Linux 紐⑤몢 鍮뚮뱶 媛??
2. **?쒕쾭 二쇱냼**: Windows ?깅룄 媛숈? ?쒕쾭(`192.168.1.102`)???곌껐
3. **?곗씠??怨듭쑀**: Windows? macOS ?깆씠 媛숈? ?쒕쾭瑜??ъ슜?섎?濡??곗씠?곌? 怨듭쑀??
4. **?섏〈???뚯씪**: EXE ?뚯씪留?諛고룷?섎㈃ ???섍퀬, 紐⑤뱺 DLL怨??곗씠???대뜑瑜??④퍡 諛고룷?댁빞 ??

## ?렞 ?붿빟

- ??Windows 諛고룷 媛??
- ???꾩옱 ?꾨줈?앺듃??Windows ?ㅼ젙 ?ы븿??
- ??macOS? ?숈씪??肄붾뱶 ?ъ슜
- ??媛숈? ?쒕쾭???곌껐?섏뿬 ?곗씠??怨듭쑀

Windows?먯꽌 `flutter build windows --release` 紐낅졊?대줈 鍮뚮뱶?섎㈃ ?⑸땲??

