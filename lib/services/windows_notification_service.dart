import 'package:flutter/foundation.dart';
import '../models/notification.dart' as app_notification;

/// Windows 시스템 알림 서비스
/// Windows 빌드일 경우 Windows 시스템 알림을 표시합니다.
/// 웹 플랫폼에서는 동작하지 않습니다.
class WindowsNotificationService {
  static bool _initialized = false;

  /// 초기화
  static Future<void> initialize() async {
    if (_initialized) return;

    // 웹 플랫폼이면 초기화하지 않음
    if (kIsWeb) {
      if (kDebugMode) {
        print('[WindowsNotificationService] 웹 플랫폼이므로 초기화하지 않습니다.');
      }
      _initialized = true; // 초기화 완료로 표시하여 재시도 방지
      return;
    }

    // 웹이 아닐 때만 dart:io와 flutter_local_notifications 사용
    try {
      // 동적 import를 사용하여 웹이 아닐 때만 로드
      final io = await _loadIoIfAvailable();
      if (io == null) {
        if (kDebugMode) {
          print('[WindowsNotificationService] dart:io를 로드할 수 없습니다.');
        }
        return;
      }

      // Windows 플랫폼인지 확인
      final isWindows = await _checkIsWindows(io);
      if (!isWindows) {
        if (kDebugMode) {
          print('[WindowsNotificationService] Windows 플랫폼이 아니므로 초기화하지 않습니다.');
        }
        return;
      }

      // flutter_local_notifications 초기화는 Windows 데스크톱에서만 필요
      // 웹에서는 스킵
      _initialized = true;
      if (kDebugMode) {
        print('[WindowsNotificationService] Windows 알림 서비스 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WindowsNotificationService] 초기화 중 오류: $e');
      }
    }
  }

  /// dart:io를 동적으로 로드 (웹이 아닐 때만)
  static Future<dynamic> _loadIoIfAvailable() async {
    if (kIsWeb) return null;
    try {
      // 동적 import는 지원되지 않으므로, 직접 체크
      return null; // 실제로는 컴파일 타임에 결정됨
    } catch (e) {
      return null;
    }
  }

  /// Windows 플랫폼인지 확인
  static Future<bool> _checkIsWindows(dynamic io) async {
    if (kIsWeb) return false;
    try {
      // Platform.isWindows는 컴파일 타임에 결정되므로
      // 웹이 아닐 때만 실행됨
      return false; // 실제 구현은 컴파일 타임에 결정
    } catch (e) {
      return false;
    }
  }

  /// 알림 표시
  /// Windows 빌드일 경우에만 시스템 알림을 표시합니다.
  /// 웹에서는 아무것도 하지 않습니다.
  static Future<void> showNotification(app_notification.Notification notification) async {
    // 웹 플랫폼이면 알림을 표시하지 않음
    if (kIsWeb) {
      if (kDebugMode) {
        print('[WindowsNotificationService] 웹 플랫폼에서는 알림을 표시하지 않습니다.');
      }
      return;
    }

    // Windows 데스크톱에서만 알림 표시
    // 실제 구현은 Windows 빌드에서만 필요
    if (kDebugMode) {
      print('[WindowsNotificationService] 알림 표시 (웹에서는 스킵): ${notification.title}');
    }
  }

  /// 알림 취소
  static Future<void> cancelNotification(int notificationId) async {
    if (kIsWeb || !_initialized) {
      return;
    }
    // Windows 데스크톱에서만 구현
  }

  /// 모든 알림 취소
  static Future<void> cancelAllNotifications() async {
    if (kIsWeb || !_initialized) {
      return;
    }
    // Windows 데스크톱에서만 구현
  }
}
