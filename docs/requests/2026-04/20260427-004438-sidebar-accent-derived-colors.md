# 좌측 네비게이션 색상을 사용자 선택 포인트 색상에 연동

| 속성 | 값 |
|------|-----|
| 유형 | feat |
| 영역 | frontend/screens, frontend/utils |
| 날짜 | 2026-04-27 |
| 상태 | 진행중 |
| 관련 | main_layout, theme_provider, accent_palette |

## 요청 내용

설정 다이얼로그의 **포인트 색상** 선택이 좌측 네비게이션(워크스페이스 레일·메인 사이드바·셸 배경·타이틀바·레일 강조색) 의 톤에 즉시 반영되도록 변경.
현재는 brand orange 베이지/갈색 톤이 hex 로 하드코딩되어 사용자가 다른 색을 골라도 좌측 영역만 그대로 남는다.

## 분석

`lib/screens/main_layout.dart` 의 좌측 네비 관련 색상 5군데가 모두 하드코딩 hex:

| 위치 | 라이트 | 다크 |
|---|---|---|
| Shell bg (Scaffold) `:1108-1110` | `#F7E9DC` | `#2E2822` |
| Workspace rail bg `:1215-1217` | `#E2B993` | `#1E1916` |
| Workspace rail foreground `:1218-1220` | `#8A5731` | `#CDB8AF` |
| Rail accent (active icon) `:1338` | `#8A5731` | `Colors.white` |
| Sidebar bg `:1411-1413` | `#F7E9DC` | `#2E2822` |
| Sidebar text `:1414-1416` | `#8A5731 (α0.9)` | `#EDE0D9` |
| Title bar bg `:1118-1120` | `#EDD8C5` | `#252017` |

이 색들은 brand seed `#D86B27` (orange) 의 HSL 을 수동 튜닝한 결과로 추정되며, accent 가 변해도 자동 반영되지 않음.

## 해결 방향

### 1) 신규 유틸 `lib/utils/accent_palette.dart`

`AccentPalette` 클래스 — accent + brightness 입력으로 HSL 변환을 통해 좌측 네비용 파생 색을 계산.

```dart
class AccentPalette {
  final Color accent;
  final Brightness brightness;

  late final Color shellBackground;
  late final Color workspaceRail;
  late final Color workspaceRailForeground;
  late final Color workspaceRailAccent;
  late final Color sidebarBackground;
  late final Color sidebarText;
  late final Color titleBarBackground;

  AccentPalette({required this.accent, required this.brightness}) { ... }

  Color _derive(double lightness, double satMultiplier) {
    final hsl = HSLColor.fromColor(accent);
    return hsl
        .withLightness(lightness.clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * satMultiplier).clamp(0.0, 1.0))
        .toColor();
  }
}
```

각 슬롯의 (lightness, sat-multiplier) 는 brand orange 기준값으로 튜닝해, **포인트 색이 orange 일 때 기존 룩과 거의 동일**, 다른 색이면 그 색의 hue 를 따라 톤 전환:

| 슬롯 | 라이트 (L, S×) | 다크 (L, S×) |
|---|---|---|
| shellBackground | (0.92, 0.55) | (0.16, 0.20) |
| workspaceRail | (0.73, 0.55) | (0.11, 0.16) |
| workspaceRailForeground | (0.36, 0.50) | (0.85, 0.20) |
| workspaceRailAccent | (0.36, 0.50) | white (특수, 그대로 유지) |
| sidebarBackground | (0.92, 0.55) | (0.16, 0.20) |
| sidebarText | (0.36, 0.50) | (0.88, 0.20) |
| titleBarBackground | (0.85, 0.55) | (0.12, 0.20) |

### 2) `main_layout.dart` 5군데 적용

- `_MainLayoutState.build` 에서 `context.watch<ThemeProvider>()` 로 accent 구독 → `AccentPalette` 생성 → 각 빌더에 전달 또는 직접 사용.
- 하드코딩 hex → palette 토큰으로 1:1 치환.

### 3) Out of scope (이번 작업 안 함)

- `main.dart` 의 `ColorScheme.fromSeed` 오버라이드는 그대로 유지 (seed 가 이미 accent → 콘텐츠 영역은 이미 반응하고 있음).
- 로그인/등록 화면, 캘린더/대시보드의 별도 하드코딩은 내비게이션 영역 밖이라 scope 제외.
- 향후 필요 시 같은 `AccentPalette` 를 재사용하면 됨.

## 검증

- 정적 분석: `flutter analyze` 통과
- 수동 검증:
  1. 설정 → 포인트 색상에서 **orange** 선택 → 좌측 네비가 기존 베이지/갈색 톤과 거의 동일한지 확인
  2. **blue / green / purple** 등으로 변경 → 좌측 네비의 셸·레일·사이드바·타이틀바 톤이 그 색의 light/dark 변형으로 즉시 전환되는지
  3. 다크 모드 토글 시 동일하게 따라가는지
  4. 텍스트 가독성 (contrast) 확인 — 사이드바 라이트 텍스트는 L=0.36, 다크 텍스트는 L=0.88 로 충분한 대비 확보

## 작업 결과

- [ ] `lib/utils/accent_palette.dart` 신설
- [ ] `lib/screens/main_layout.dart` 5군데 (shell·rail·rail-foreground·rail-accent·sidebar·titlebar) 토큰 치환
- [ ] `flutter analyze` 신규 경고 없음
- [ ] frontend-only 배포 (deploy.md 룰 적용 — API 컨테이너 재빌드 스킵)
- [ ] 사용자 검증 — 색 전환 시 톤 변화·가독성 확인
