# 다크 팔레트 3종 (GitHub / Neutral / Mild) 라이브 토글

| 속성 | 값 |
|------|-----|
| 유형 | feat+ui |
| 영역 | frontend/providers, frontend/utils, frontend/screens |
| 날짜 | 2026-04-29 |
| 상태 | done |
| 관련 | theme_provider, accent_palette, main_layout |

## 요청 내용

다크 모드 색조합이 muddy(warm-on-warm) 한 문제 해결. 3개 후보 팔레트를 모두 구현해 설정에서 라이브 토글하며 비교 → 사용자 최종 결정.

## 배경

`AccentPalette._derive(L, sat=0.18-0.20)` 가 모든 표면/텍스트에 accent hue (orange ~22°) 를 입혀 본문/배경/카드/코드블록이 같은 warm hue 가 됨. hue 대비 0 → 휘도만 남음 → 코드/표 가독성 저하.

산업 표준 (GitHub, Linear, Vercel, Tailwind slate) = content 표면/텍스트는 뉴트럴 또는 살짝 cool, accent 는 primary/배지 같은 좁은 슬롯에만.

## ASCII 다이어그램

설정 다이얼로그 (다크 팔레트 섹션 추가):

```
┌────────────────────────────────────────────────┐
│  글자 크기                                     │  (기존)
│  ─────●─────────────                           │
│                                                │
│  포인트 색상                                   │  (기존)
│  ● ● ● ● ●                                     │
│                                                │
│  다크 팔레트 (다크 모드에서 적용됨)            │  (신규)
│  ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │█▓▓▒▒░░░░ │ │█▓▓▒▒░░░░ │ │█▓▓▒▒░░░░ │       │
│  │ GitHub   │ │ Neutral  │ │ Mild     │       │
│  │   ✓      │ │          │ │          │       │
│  └──────────┘ └──────────┘ └──────────┘       │
│  cool blue    pure gray    warm tint           │
└────────────────────────────────────────────────┘
```

## 시안 hex 요약

| 슬롯 | A. GitHub | B. Neutral | C. Mild (orange accent 기준) |
|---|---|---|---|
| `contentBackground` | `#0D1117` | `#0A0A0A` | `_derive(0.10, 0.04)` ≈ `#14110F` |
| `contentSurface` | `#21262D` | `#1F1F1F` | `_derive(0.16, 0.04)` ≈ `#211E1B` |
| `contentSurfaceHighest` | `#373E47` | `#2F2F2F` | `_derive(0.24, 0.04)` ≈ `#322E2A` |
| `contentOnSurface` | `#E6EDF3` | `#EDEDED` | `_derive(0.92, 0.04)` ≈ `#E9E7E5` |
| `contentOnSurfaceVariant` | `#8B949E` | `#A3A3A3` | `_derive(0.78, 0.04)` ≈ `#C2BCB6` |
| WCAG (text vs bg) | 15.3:1 (AAA) | 16.0:1 (AAA) | ~12:1 (AAA) |

## 작업 결과

- [x] `DarkPalettePreset` enum + 상태/persist (`theme_provider.dart`) — `_loadPreferences` 에서 복원, `setDarkPalette` 로 저장
- [x] `AccentPalette` 다크 분기를 preset switch 로 교체 (`accent_palette.dart`) — chrome 슬롯은 그대로, content 슬롯만 분기
- [x] `main.dart` MultiProvider 에서 `darkPreset: themeProvider.darkPalette` 주입
- [x] 설정 다이얼로그에 "다크 팔레트" 섹션 추가 (`main_layout.dart`)
  - 3개 카드 (`_DarkPaletteCard` 위젯) — 각 카드에 mini swatch (bg+surface+highest 4 layer 시안 + 가짜 본문 텍스트) + 라벨 + 부제 + 선택 표시
  - 클릭 시 즉시 `themeProvider.setDarkPalette` → 전체 리렌더
- [x] `flutter analyze` 통과 — 신규 에러 0 (35개 info/warning 모두 기존 패턴)
- [ ] 사용자 시나리오 검증 (배포 후)

## 참고 사항

- chrome (사이드바/워크스페이스 레일/타이틀바) 는 모든 preset 에서 동일 (accent 살린 톤 유지) — "내 색" 정체성
- content (본문/카드/코드블록) 만 preset 별로 분기
- 기본값: `github` (가장 검증된 cool 팔레트, 코드 친화)
- 라이트 모드는 영향 없음
- SharedPreferences 키: `theme_dark_palette` (`github` / `neutral` / `mild`)

## 비-목표

- 라이트 모드 팔레트 변경
- chrome 팔레트 변경
- 코드블록 monospace 폰트 명시
- OKLCH perceptual palette
