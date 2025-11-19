import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

/// 유저 아바타 색상 생성 유틸리티
class AvatarColor {
  /// 미리 정의된 색상 팔레트
  static const List<Color> _colorPalette = [
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF2196F3), // Blue
    Color(0xFF03A9F4), // Light Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFF8BC34A), // Light Green
    Color(0xFFCDDC39), // Lime
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFFC107), // Amber
    Color(0xFFFF9800), // Orange
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFF44336), // Red
  ];

  /// 유저 ID나 유저명을 기반으로 색상 반환
  /// 같은 유저는 항상 같은 색상을 반환합니다.
  static Color getColorForUser(String userIdOrUsername) {
    if (userIdOrUsername.isEmpty) {
      return _colorPalette[0];
    }

    // 문자열의 해시 코드를 사용하여 색상 인덱스 생성
    int hash = userIdOrUsername.hashCode;
    int index = hash.abs() % _colorPalette.length;
    return _colorPalette[index];
  }

  /// 유저명을 기반으로 단일 이니셜 반환
  static String getInitial(String? name) {
    if (name == null) return '?';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final firstChar = trimmed.characters.first;
    return firstChar.toUpperCase();
  }
}

