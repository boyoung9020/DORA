import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 다크 모드 본문 표면/텍스트 톤 프리셋.
/// chrome (사이드바/타이틀바) 은 항상 accent 파생 톤이며 preset 영향 받지 않음.
enum DarkPalettePreset {
  github,   // GitHub Primer Dark — cool blue, sharp (default)
  neutral,  // Vercel Geist — pure neutral, minimal
  mild,     // Mild Tint — accent hue 1/4 saturation, current 정체성 유지
  slack,    // Slack 다크 테마 — very dark canvas + lifted card surface
}

/// 테마 모드 + 글자 크기 + 포인트(브랜드) 색 + 다크 팔레트 프리셋 Provider
class ThemeProvider with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _textScaleKey = 'theme_text_scale';
  static const String _accentKey = 'theme_accent_color';
  static const String _darkPaletteKey = 'theme_dark_palette';

  ThemeMode _themeMode = ThemeMode.light;
  double _textScale = 1.0;
  Color _accentColor = const Color(0xFFD86B27);
  DarkPalettePreset _darkPalette = DarkPalettePreset.github;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// 앱 내 글자 배율 (0.85 ~ 1.25). MaterialApp builder에서 적용.
  double get textScale => _textScale;

  /// ColorScheme.fromSeed / primary 등에 사용
  Color get accentColor => _accentColor;

  /// 다크 모드 본문 표면/텍스트 프리셋 (chrome 은 항상 accent 파생, 영향 없음)
  DarkPalettePreset get darkPalette => _darkPalette;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeModeKey) ?? 'light';
    _themeMode = themeModeString == 'dark' ? ThemeMode.dark : ThemeMode.light;

    final ts = prefs.getDouble(_textScaleKey);
    if (ts != null && ts >= 0.85 && ts <= 1.25) {
      _textScale = ts;
    }

    final accentValue = prefs.getInt(_accentKey);
    if (accentValue != null && accentValue != 0) {
      _accentColor = Color(accentValue);
    }

    final paletteName = prefs.getString(_darkPaletteKey);
    if (paletteName != null) {
      _darkPalette = DarkPalettePreset.values.firstWhere(
        (p) => p.name == paletteName,
        orElse: () => DarkPalettePreset.github,
      );
    }

    notifyListeners();
  }

  /// 테마 모드 변경
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setLightMode() => setThemeMode(ThemeMode.light);
  Future<void> setDarkMode() => setThemeMode(ThemeMode.dark);

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setDarkMode();
    } else {
      await setLightMode();
    }
  }

  /// 0.85 ~ 1.25
  Future<void> setTextScale(double value) async {
    final v = value.clamp(0.85, 1.25);
    _textScale = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, v);
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.toARGB32());
  }

  Future<void> setDarkPalette(DarkPalettePreset preset) async {
    if (_darkPalette == preset) return;
    _darkPalette = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_darkPaletteKey, preset.name);
  }
}
