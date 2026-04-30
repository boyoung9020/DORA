import 'package:flutter/material.dart';

import '../providers/theme_provider.dart' show DarkPalettePreset;

/// 좌측 네비게이션(셸/워크스페이스 레일/사이드바/타이틀바) 영역에서 사용할
/// **포인트 색상에서 파생된 톤 팔레트**.
///
/// 사용자가 설정 다이얼로그에서 고른 `ThemeProvider.accentColor` 를 입력으로 받아
/// HSL 변환을 거쳐 라이트/다크 모드 각각의 표면·텍스트 색을 계산한다.
///
/// 각 슬롯의 (lightness, saturation 배율) 은 brand orange 기준으로 튜닝되어,
/// 포인트 색이 orange 일 때 종전 hex 하드코딩 결과와 거의 동일한 룩을 보존하고,
/// 다른 색을 선택하면 해당 색의 hue 를 따라 톤이 자연스럽게 전환된다.
class AccentPalette {
  final Color accent;
  final Brightness brightness;
  final DarkPalettePreset darkPreset;

  // 좌측 네비게이션 영역
  late final Color shellBackground;
  late final Color workspaceRail;
  late final Color workspaceRailForeground;
  late final Color workspaceRailAccent;
  late final Color sidebarBackground;
  late final Color sidebarText;
  late final Color titleBarBackground;

  // 콘텐츠 영역 / 카드 (Material 3 tone scale)
  late final Color contentBackground;        // surface (페이지 bg)
  late final Color contentSurfaceLowest;     // surfaceContainerLowest (살짝 더 밝거나 어두움)
  late final Color contentSurfaceLow;        // surfaceContainerLow
  late final Color contentSurface;           // surfaceContainer (카드 기본)
  late final Color contentSurfaceHigh;       // surfaceContainerHigh (호버/선택)
  late final Color contentSurfaceHighest;    // surfaceContainerHighest (강조)
  late final Color contentOnSurface;         // onSurface (본문 텍스트)
  late final Color contentOnSurfaceVariant;  // onSurfaceVariant (보조 텍스트)
  late final Color contentOutline;           // outline (테두리)
  late final Color contentOutlineVariant;    // outlineVariant (얇은 구분선)

  AccentPalette({
    required this.accent,
    required this.brightness,
    this.darkPreset = DarkPalettePreset.github,
  }) {
    final isDark = brightness == Brightness.dark;
    // 디자인 원칙:
    //   - "Chrome"(사이드바·상단 정보 바·셸 페이지 바깥) = 한 톤으로 통일 (시각적으로 한 덩어리)
    //   - 워크스페이스 레일 = 시각적 깊이를 위해 chrome 보다 살짝 더 진한 톤
    //   - "Content"(본문 카드·페이지 표면) = 별도의 더 옅은(라이트) / 더 어두운(다크) 톤
    //   - chrome 은 항상 accent 에서 파생 (사용자 정체성 유지)
    //   - 다크 content 는 darkPreset 에 따라 분기 (warm hue 충돌 방지)
    if (isDark) {
      // 다크 모드: chrome + content 모두 preset 별로 분기
      // 각 preset 내부에서 workspaceRail(가장 깊음) → chrome(중간) → content bg(살짝 밝음) → surface 단계로 위계
      // 활성 워크스페이스 강조는 항상 흰색 (가독성 우선)
      workspaceRailAccent     = Colors.white;

      // 기본 공유 surface 패밀리 — github/neutral/mild 가 사용 (#383838 기반).
      // slack preset 은 자체 surface 사용 (case 안에서 재할당).
      const sharedSurfaceLowest  = Color(0xFF252525);
      const sharedSurfaceLow     = Color(0xFF303030);
      const sharedSurface        = Color(0xFF383838); // 카드 기본 (97곳 GlassContainer)
      const sharedSurfaceHigh    = Color(0xFF424242);
      const sharedSurfaceHighest = Color(0xFF4A4A4A);
      const sharedOutline        = Color(0xFF4A4A4A);
      const sharedOutlineVariant = Color(0xFF303030);

      switch (darkPreset) {
        case DarkPalettePreset.github:
          // GitHub Primer Dark — cool blue chrome / canvas, neutral surface
          workspaceRail           = const Color(0xFF0D1117);
          workspaceRailForeground = const Color(0xFF8B949E);
          sidebarBackground       = const Color(0xFF161B22);
          sidebarText             = const Color(0xFFC9D1D9);
          shellBackground         = sidebarBackground;
          titleBarBackground      = sidebarBackground;
          contentBackground       = const Color(0xFF161B22);
          contentOnSurface        = const Color(0xFFE6EDF3);
          contentOnSurfaceVariant = const Color(0xFF8B949E);
          contentSurfaceLowest    = sharedSurfaceLowest;
          contentSurfaceLow       = sharedSurfaceLow;
          contentSurface          = sharedSurface;
          contentSurfaceHigh      = sharedSurfaceHigh;
          contentSurfaceHighest   = sharedSurfaceHighest;
          contentOutline          = sharedOutline;
          contentOutlineVariant   = sharedOutlineVariant;
          break;
        case DarkPalettePreset.neutral:
          // Tailwind zinc — pure neutral chrome / canvas, neutral surface
          workspaceRail           = const Color(0xFF0F0F0F);
          workspaceRailForeground = const Color(0xFFA1A1AA);
          sidebarBackground       = const Color(0xFF18181B);
          sidebarText             = const Color(0xFFE4E4E7);
          shellBackground         = sidebarBackground;
          titleBarBackground      = sidebarBackground;
          contentBackground       = const Color(0xFF18181B);
          contentOnSurface        = const Color(0xFFFAFAFA);
          contentOnSurfaceVariant = const Color(0xFFA1A1AA);
          contentSurfaceLowest    = sharedSurfaceLowest;
          contentSurfaceLow       = sharedSurfaceLow;
          contentSurface          = sharedSurface;
          contentSurfaceHigh      = sharedSurfaceHigh;
          contentSurfaceHighest   = sharedSurfaceHighest;
          contentOutline          = sharedOutline;
          contentOutlineVariant   = sharedOutlineVariant;
          break;
        case DarkPalettePreset.mild:
          // Mild tint — accent hue 살짝 살린 chrome / canvas, neutral surface
          workspaceRail           = _derive(0.10, 0.04);
          workspaceRailForeground = _derive(0.78, 0.04);
          sidebarBackground       = _derive(0.13, 0.04);
          sidebarText             = _derive(0.85, 0.04);
          shellBackground         = sidebarBackground;
          titleBarBackground      = sidebarBackground;
          contentBackground       = _derive(0.13, 0.04);
          contentOnSurface        = _derive(0.92, 0.04);
          contentOnSurfaceVariant = _derive(0.78, 0.04);
          contentSurfaceLowest    = sharedSurfaceLowest;
          contentSurfaceLow       = sharedSurfaceLow;
          contentSurface          = sharedSurface;
          contentSurfaceHigh      = sharedSurfaceHigh;
          contentSurfaceHighest   = sharedSurfaceHighest;
          contentOutline          = sharedOutline;
          contentOutlineVariant   = sharedOutlineVariant;
          break;
        case DarkPalettePreset.slack:
          // Slack 다크 — very dark canvas (#19171D) + lifted card surface (#36373B)
          workspaceRail           = const Color(0xFF19171D);
          workspaceRailForeground = const Color(0xFFABABAD);
          sidebarBackground       = const Color(0xFF19171D);
          sidebarText             = const Color(0xFFD1D2D3);
          shellBackground         = sidebarBackground;
          titleBarBackground      = sidebarBackground;
          contentBackground       = const Color(0xFF19171D);
          contentOnSurface        = const Color(0xFFF8F8F8);
          contentOnSurfaceVariant = const Color(0xFFABABAD);
          // Slack 의 카드/표면은 캔버스보다 한 단 밝음 — 떠있는 느낌
          contentSurfaceLowest    = const Color(0xFF1F1D24);
          contentSurfaceLow       = const Color(0xFF2C2D31);
          contentSurface          = const Color(0xFF36373B); // 카드 기본
          contentSurfaceHigh      = const Color(0xFF40424A);
          contentSurfaceHighest   = const Color(0xFF4F5258);
          contentOutline          = const Color(0xFF4F5258);
          contentOutlineVariant   = const Color(0xFF2C2D31);
          break;
        case DarkPalettePreset.mattermost:
          // Mattermost 다크 — cool blue-gray rail / canvas + lifted card
          workspaceRail           = const Color(0xFF14171F); // 가장 깊음 (앱 그리드 레일)
          workspaceRailForeground = const Color(0xFF909295);
          sidebarBackground       = const Color(0xFF1B1D22); // 채널 사이드바
          sidebarText             = const Color(0xFFE4E5E8);
          shellBackground         = sidebarBackground;
          titleBarBackground      = sidebarBackground;
          contentBackground       = const Color(0xFF1F2126); // 메인 패널
          contentOnSurface        = const Color(0xFFF2F3F5);
          contentOnSurfaceVariant = const Color(0xFF909295);
          // 카드/표면 — 메인보다 한 단 밝아 thread row 가 또렷
          contentSurfaceLowest    = const Color(0xFF1B1D22);
          contentSurfaceLow       = const Color(0xFF22252B);
          contentSurface          = const Color(0xFF262830); // 카드 기본
          contentSurfaceHigh      = const Color(0xFF2D3038);
          contentSurfaceHighest   = const Color(0xFF383A43);
          contentOutline          = const Color(0xFF383A43);
          contentOutlineVariant   = const Color(0xFF262830);
          break;
      }
    } else {
      // Chrome 톤 (사이드바·상단·셸이 모두 동일 베이지)
      sidebarBackground       = _derive(0.92, 0.55);
      sidebarText             = _derive(0.36, 0.50);
      shellBackground         = sidebarBackground;
      titleBarBackground      = sidebarBackground;

      // 워크스페이스 레일 — chrome 보다 한 단계 진한 톤 (사용자 정체성 강조)
      workspaceRail           = _derive(0.73, 0.55);
      workspaceRailForeground = _derive(0.36, 0.50);
      workspaceRailAccent     = _derive(0.36, 0.50);

      // Content 톤 (본문 카드·페이지 표면) — chrome 위에 떠있는 듯한 거의 흰색
      contentBackground       = _derive(0.985, 0.55);
      contentSurfaceLowest    = _derive(0.995, 0.40);
      contentSurfaceLow       = _derive(0.97, 0.45);
      contentSurface          = _derive(0.95, 0.50);
      contentSurfaceHigh      = _derive(0.92, 0.55);
      contentSurfaceHighest   = _derive(0.88, 0.55);
      contentOnSurface        = _derive(0.18, 0.55);
      contentOnSurfaceVariant = _derive(0.40, 0.45);
      contentOutline          = _derive(0.78, 0.30);
      contentOutlineVariant   = _derive(0.86, 0.25);
    }
  }

  Color _derive(double lightness, double satMultiplier) {
    final hsl = HSLColor.fromColor(accent);
    return hsl
        .withLightness(lightness.clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * satMultiplier).clamp(0.0, 1.0))
        .toColor();
  }
}
