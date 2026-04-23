# macOS ??諛고룷 ?꾩쟾 媛?대뱶

## ?벀 諛고룷 諛⑸쾿 醫낅쪟

1. **吏곸젒 諛고룷** - ???뚯씪??吏곸젒 蹂듭궗
2. **DMG ?뚯씪 諛고룷** - ?ㅼ튂 ?대?吏 ?뚯씪 ?앹꽦
3. **ZIP ?뚯씪 諛고룷** - ?뺤텞 ?뚯씪濡?諛고룷
4. **App Store 諛고룷** - 怨듭떇 ???ㅽ넗??諛고룷

---

## 諛⑸쾿 1: 吏곸젒 諛고룷 (媛??媛꾨떒)

### 1?④퀎: ??鍮뚮뱶

```bash
# ?꾨줈?앺듃 ?붾젆?좊━?먯꽌
flutter build macos --release
```

### 2?④퀎: ???뚯씪 李얘린

鍮뚮뱶?????꾩튂:
```
build/macos/Build/Products/Release/sync_project_manager.app
```

### 3?④퀎: ?ㅻⅨ 留μ쑝濡?蹂듭궗

#### ?듭뀡 A: USB ?쒕씪?대툕 ?ъ슜
```bash
# USB ?쒕씪?대툕??蹂듭궗
cp -R build/macos/Build/Products/Release/sync_project_manager.app /Volumes/USB?쒕씪?대툕?대쫫/
```

#### ?듭뀡 B: ?ㅽ듃?뚰겕 怨듭쑀 ?ъ슜
```bash
# ?쒕쾭???낅줈??(SCP ?ъ슜)
scp -r build/macos/Build/Products/Release/sync_project_manager.app user@server:/path/to/share/

# ?먮뒗 怨듭쑀 ?대뜑??蹂듭궗
cp -R build/macos/Build/Products/Release/sync_project_manager.app /Users/Shared/
```

#### ?듭뀡 C: AirDrop ?ъ슜
1. Finder?먯꽌 `build/macos/Build/Products/Release/` ?대뜑 ?닿린
2. `sync_project_manager.app` ?고겢由?
3. 怨듭쑀 > AirDrop ?좏깮
4. ???留??좏깮

### 4?④퀎: ???ㅽ뻾

?ㅻⅨ 留μ뿉??
1. ???뚯씪??Applications ?대뜑濡??대룞 (?좏깮?ы빆)
2. ???붾툝 ?대┃
3. "?뺤씤?섏? ?딆? 媛쒕컻?? 寃쎄퀬媛 ?섏삤硫?
   - ?쒖뒪???ㅼ젙 > 媛쒖씤?뺣낫 蹂댄샇 諛?蹂댁븞
   - "?뺤씤 ?놁씠 ?닿린" ?대┃

---

## 諛⑸쾿 2: DMG ?뚯씪 諛고룷 (沅뚯옣)

DMG ?뚯씪? macOS???쒖? ?ㅼ튂 ?대?吏 ?뺤떇?낅땲??

### 1?④퀎: DMG ?앹꽦 ?ㅽ겕由쏀듃 留뚮뱾湲?

`create_dmg.sh` ?뚯씪 ?앹꽦:

```bash
#!/bin/bash
# DMG ?뚯씪 ?앹꽦 ?ㅽ겕由쏀듃

APP_NAME="sync_project_manager"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}_v1.0.0"
DMG_PATH="build/${DMG_NAME}.dmg"
VOLUME_NAME="SYNC ?꾨줈?앺듃 愿由?

# ?깆씠 鍮뚮뱶?섏뼱 ?덈뒗吏 ?뺤씤
if [ ! -d "$APP_PATH" ]; then
    echo "???깆쓣 癒쇱? 鍮뚮뱶?댁＜?몄슂: flutter build macos --release"
    exit 1
fi

# ?꾩떆 DMG ?붾젆?좊━ ?앹꽦
TEMP_DIR="build/dmg_temp"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# ??蹂듭궗
cp -R "$APP_PATH" "$TEMP_DIR/"

# Applications ?대뜑 留곹겕 ?앹꽦 (?좏깮?ы빆)
ln -s /Applications "$TEMP_DIR/Applications"

# DMG ?뚯씪 ?앹꽦
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# ?꾩떆 ?붾젆?좊━ ??젣
rm -rf "$TEMP_DIR"

echo "??DMG ?뚯씪 ?앹꽦 ?꾨즺: $DMG_PATH"
echo "?벀 ?뚯씪 ?ш린: $(du -h "$DMG_PATH" | cut -f1)"
```

### 2?④퀎: DMG ?앹꽦

```bash
chmod +x create_dmg.sh
./create_dmg.sh
```

### 3?④퀎: DMG ?뚯씪 諛고룷

?앹꽦??DMG ?뚯씪 ?꾩튂:
```
build/sync_project_manager_v1.0.0.dmg
```

???뚯씪??
- ?대찓?쇰줈 ?꾩넚
- ?대씪?곕뱶 ?ㅽ넗由ъ????낅줈??(iCloud, Google Drive, Dropbox ??
- ?뱀궗?댄듃???낅줈??
- USB ?쒕씪?대툕濡?蹂듭궗

### 4?④퀎: ?ъ슜?먭? ?ㅼ튂

1. DMG ?뚯씪 ?붾툝 ?대┃
2. ?대┛ 李쎌뿉???깆쓣 Applications ?대뜑濡??쒕옒洹?
3. Applications ?대뜑?먯꽌 ???ㅽ뻾

---

## 諛⑸쾿 3: ZIP ?뚯씪 諛고룷

### 1?④퀎: ZIP ?뚯씪 ?앹꽦

```bash
cd build/macos/Build/Products/Release/
zip -r ../../../sync_project_manager.zip sync_project_manager.app
cd ../../../../..
```

?먮뒗 ?ㅽ겕由쏀듃濡?

```bash
#!/bin/bash
# ZIP ?뚯씪 ?앹꽦 ?ㅽ겕由쏀듃

APP_NAME="sync_project_manager"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
ZIP_PATH="build/${APP_NAME}.zip"

if [ ! -d "$APP_PATH" ]; then
    echo "???깆쓣 癒쇱? 鍮뚮뱶?댁＜?몄슂: flutter build macos --release"
    exit 1
fi

cd build/macos/Build/Products/Release/
zip -r "../../../../${ZIP_PATH}" "${APP_NAME}.app"
cd ../../../../..

echo "??ZIP ?뚯씪 ?앹꽦 ?꾨즺: $ZIP_PATH"
```

### 2?④퀎: ZIP ?뚯씪 諛고룷

?앹꽦??ZIP ?뚯씪??怨듭쑀?섎㈃ ?⑸땲??

---

## 諛⑸쾿 4: App Store 諛고룷 (怨듭떇 諛고룷)

### 1?④퀎: Apple Developer 怨꾩젙 ?꾩슂

- Apple Developer Program 媛??($99/??
- https://developer.apple.com ?먯꽌 媛??

### 2?④퀎: 肄붾뱶 ?쒕챸 ?ㅼ젙

#### Xcode?먯꽌 ?ㅼ젙:

1. `macos/Runner.xcworkspace` ?뚯씪??Xcode濡??닿린
2. Runner ?寃??좏깮
3. Signing & Capabilities ??
   - Team ?좏깮 (Apple Developer 怨꾩젙)
   - Automatically manage signing 泥댄겕
   - Bundle Identifier ?뺤씤 (?? `com.yourcompany.sync`)

### 3?④퀎: ???뺣낫 ?ㅼ젙

`macos/Runner/Configs/AppInfo.xcconfig` ?뚯씪 ?섏젙:

```
PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.sync
PRODUCT_NAME = SYNC
```

### 4?④퀎: ???꾩뭅?대툕 ?앹꽦

```bash
# 由대━??鍮뚮뱶
flutter build macos --release

# Xcode?먯꽌 ?꾩뭅?대툕
# 1. Xcode?먯꽌 Product > Archive
# 2. Organizer 李쎌뿉??Distribute App ?대┃
# 3. App Store Connect ?좏깮
# 4. ?낅줈???꾨즺
```

### 5?④퀎: App Store Connect?먯꽌 ?ㅼ젙

1. https://appstoreconnect.apple.com ?묒냽
2. ????異붽?
3. ???뺣낫 ?낅젰
4. 鍮뚮뱶 ?좏깮 諛??쒖텧

---

## ?뵩 諛고룷 ??泥댄겕由ъ뒪??

### ?꾩닔 ?뺤씤 ?ы빆

- [ ] ?깆씠 ?뺤긽?곸쑝濡?鍮뚮뱶?섎뒗吏 ?뺤씤
- [ ] API ?쒕쾭 二쇱냼媛 ?щ컮瑜몄? ?뺤씤 (`lib/utils/api_client.dart`)
- [ ] ???꾩씠肄??ㅼ젙 ?뺤씤
- [ ] ???대쫫 ?뺤씤 (`macos/Runner/Configs/AppInfo.xcconfig`)
- [ ] Bundle Identifier ?뺤씤
- [ ] ?ㅽ듃?뚰겕 沅뚰븳 ?뺤씤 (Entitlements ?뚯씪)

### ?뚯뒪????ぉ

- [ ] ???ㅽ뻾 ?뚯뒪??
- [ ] 濡쒓렇??湲곕뒫 ?뚯뒪??
- [ ] ?쒕쾭 ?곌껐 ?뚯뒪??
- [ ] 紐⑤뱺 湲곕뒫 ?숈옉 ?뺤씤

---

## ?뱥 鍮좊Ⅸ 諛고룷 ?ㅽ겕由쏀듃

### ?꾩껜 諛고룷 ?ㅽ겕由쏀듃 (`deploy_macos.sh`)

```bash
#!/bin/bash
# macOS ??鍮뚮뱶 諛?諛고룷 ?ㅽ겕由쏀듃

set -e

APP_NAME="sync_project_manager"
VERSION="1.0.0"

echo "=== SYNC macOS ??鍮뚮뱶 諛?諛고룷 ==="
echo ""

# 1. ?섏〈???ㅼ튂
echo "1. Flutter ?섏〈???ㅼ튂 以?.."
flutter pub get

# 2. macOS ?섏〈???ㅼ튂
echo "2. macOS ?섏〈???ㅼ튂 以?.."
cd macos
if command -v pod &> /dev/null; then
    pod install
else
    echo "?좑툘  CocoaPods媛 ?ㅼ튂?섏뼱 ?덉? ?딆뒿?덈떎."
fi
cd ..

# 3. ?대┛ 鍮뚮뱶
echo "3. ?대┛ 鍮뚮뱶 以?.."
flutter clean
flutter pub get

# 4. 由대━??鍮뚮뱶
echo "4. 由대━??鍮뚮뱶 以?.."
flutter build macos --release

# 5. 諛고룷 ?뚯씪 ?앹꽦
echo "5. 諛고룷 ?뚯씪 ?앹꽦 以?.."

APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
BUILD_DIR="build/deploy"

# 諛고룷 ?붾젆?좊━ ?앹꽦
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ??蹂듭궗
cp -R "$APP_PATH" "$BUILD_DIR/"

# ZIP ?뚯씪 ?앹꽦
cd "$BUILD_DIR"
zip -r "../${APP_NAME}_v${VERSION}.zip" "${APP_NAME}.app"
cd ../..

# DMG ?뚯씪 ?앹꽦 (?좏깮?ы빆)
if command -v hdiutil &> /dev/null; then
    echo "6. DMG ?뚯씪 ?앹꽦 以?.."
    TEMP_DMG="build/dmg_temp"
    rm -rf "$TEMP_DMG"
    mkdir -p "$TEMP_DMG"
    
    cp -R "$APP_PATH" "$TEMP_DMG/"
    ln -s /Applications "$TEMP_DMG/Applications"
    
    hdiutil create -volname "SYNC ?꾨줈?앺듃 愿由? \
        -srcfolder "$TEMP_DMG" \
        -ov -format UDZO \
        "build/${APP_NAME}_v${VERSION}.dmg"
    
    rm -rf "$TEMP_DMG"
fi

echo ""
echo "??諛고룷 以鍮??꾨즺!"
echo ""
echo "?벀 ?앹꽦???뚯씪:"
echo "   - ?? $APP_PATH"
echo "   - ZIP: build/${APP_NAME}_v${VERSION}.zip"
if [ -f "build/${APP_NAME}_v${VERSION}.dmg" ]; then
    echo "   - DMG: build/${APP_NAME}_v${VERSION}.dmg"
fi
echo ""
echo "?? 諛고룷 諛⑸쾿:"
echo "   1. ZIP ?먮뒗 DMG ?뚯씪??怨듭쑀"
echo "   2. ?ъ슜?먭? ?ㅼ슫濡쒕뱶 ???ㅼ튂"
echo "   3. Applications ?대뜑濡??대룞 ???ㅽ뻾"
```

---

## ?뵍 肄붾뱶 ?쒕챸 諛?怨듭쬆 (?좏깮?ы빆)

### 媛쒕컻??ID濡??쒕챸 (App Store ??諛고룷)

```bash
# 媛쒕컻??ID ?몄쬆???꾩슂
codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: Your Name" \
    build/macos/Build/Products/Release/sync_project_manager.app

# 怨듭쬆 (notarization)
xcrun notarytool submit \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "app-specific-password" \
    build/sync_project_manager_v1.0.0.dmg
```

---

## ?뱾 諛고룷 梨꾨꼸

### 1. ?대찓??
- ZIP ?먮뒗 DMG ?뚯씪 泥⑤?
- ?뚯씪 ?ш린 ?쒗븳 ?뺤씤 (?쇰컲?곸쑝濡?25MB)

### 2. ?대씪?곕뱶 ?ㅽ넗由ъ?
- iCloud Drive
- Google Drive
- Dropbox
- OneDrive

### 3. ?뱀궗?댄듃
- 吏곸젒 ?ㅼ슫濡쒕뱶 留곹겕 ?쒓났
- ?뚯씪 ?몄뒪???쒕퉬???ъ슜

### 4. ?대? ?ㅽ듃?뚰겕
- 怨듭쑀 ?대뜑??諛곗튂
- ?ㅽ듃?뚰겕 ?쒕씪?대툕 留덉슫??

---

## ?렞 沅뚯옣 諛고룷 諛⑸쾿

**?뚭퇋紐?諛고룷 (10紐??댄븯):**
- 吏곸젒 諛고룷 ?먮뒗 AirDrop

**以묎퇋紐?諛고룷 (10-100紐?:**
- DMG ?뚯씪 + ?대씪?곕뱶 ?ㅽ넗由ъ?

**?洹쒕え 諛고룷 (100紐??댁긽):**
- App Store 諛고룷 ?먮뒗 ?먯껜 ?낅뜲?댄듃 ?쒕쾭

---

## ??臾몄젣 ?닿껐

### "?뺤씤?섏? ?딆? 媛쒕컻?? 寃쎄퀬

?닿껐:
1. ?쒖뒪???ㅼ젙 > 媛쒖씤?뺣낫 蹂댄샇 諛?蹂댁븞
2. "?뺤씤 ?놁씠 ?닿린" ?대┃
3. ?먮뒗 媛쒕컻??ID濡?肄붾뱶 ?쒕챸

### ?깆씠 ?ㅽ뻾?섏? ?딆쓬

?뺤씤:
- macOS 踰꾩쟾 ?명솚??
- ?ㅽ듃?뚰겕 沅뚰븳
- ?쒕쾭 ?곌껐 媛???щ?

### 鍮뚮뱶 ?ㅻ쪟

```bash
flutter clean
rm -rf macos/Pods macos/Podfile.lock
cd macos && pod install && cd ..
flutter build macos --release
```

---

## ?뱷 ?붿빟

媛??媛꾨떒??諛고룷 諛⑸쾿:
1. `flutter build macos --release`
2. `build/macos/Build/Products/Release/sync_project_manager.app` 蹂듭궗
3. ?ㅻⅨ 留μ쑝濡??꾩넚
4. Applications ?대뜑濡??대룞 ???ㅽ뻾

???꾨Ц?곸씤 諛고룷:
1. DMG ?뚯씪 ?앹꽦
2. 肄붾뱶 ?쒕챸 (?좏깮?ы빆)
3. ?대씪?곕뱶 ?ㅽ넗由ъ????낅줈??
4. ?ㅼ슫濡쒕뱶 留곹겕 怨듭쑀

