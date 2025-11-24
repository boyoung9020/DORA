import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification.dart' as app_notification;

/// Windows 시스템 알림 서비스
/// Windows 빌드일 경우 Windows 시스템 알림을 표시합니다.
class WindowsNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 초기화
  static Future<void> initialize() async {
    if (_initialized) return;

    // Windows 플랫폼인지 확인
    if (!Platform.isWindows) {
      if (kDebugMode) {
        print('[WindowsNotificationService] Windows 플랫폼이 아니므로 초기화하지 않습니다.');
      }
      return;
    }

    try {
      // 초기화 설정
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized != null && initialized) {
        _initialized = true;
        if (kDebugMode) {
          print('[WindowsNotificationService] Windows 알림 서비스 초기화 완료');
        }
      } else {
        if (kDebugMode) {
          print('[WindowsNotificationService] Windows 알림 서비스 초기화 실패');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WindowsNotificationService] 초기화 중 오류: $e');
      }
    }
  }

  /// 알림 클릭 시 콜백
  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('[WindowsNotificationService] 알림 클릭됨: ${response.payload}');
    }
    // 여기서 알림 화면으로 이동하거나 특정 작업을 수행할 수 있습니다.
  }

  /// 알림 표시
  /// Windows 빌드일 경우에만 시스템 알림을 표시합니다.
  static Future<void> showNotification(app_notification.Notification notification) async {
    // Windows 플랫폼이 아니면 알림을 표시하지 않음
    if (!Platform.isWindows) {
      return;
    }

    // 초기화되지 않았으면 초기화 시도
    if (!_initialized) {
      await initialize();
    }

    if (!_initialized) {
      if (kDebugMode) {
        print('[WindowsNotificationService] 초기화되지 않아 알림을 표시할 수 없습니다.');
      }
      return;
    }

    try {
      // 알림 설정 (Windows는 flutter_local_notifications가 자동으로 처리)
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'dora_notifications',
          'DORA 알림',
          channelDescription: 'DORA 프로젝트 관리 시스템 알림',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // 알림 표시
      await _notifications.show(
        notification.id.hashCode, // 고유 ID (음수 방지)
        notification.title,
        notification.message,
        notificationDetails,
        payload: notification.id, // 알림 클릭 시 전달할 데이터
      );

      if (kDebugMode) {
        print('[WindowsNotificationService] 알림 표시됨: ${notification.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WindowsNotificationService] 알림 표시 중 오류: $e');
      }
    }
  }

  /// 알림 취소
  static Future<void> cancelNotification(int notificationId) async {
    if (!Platform.isWindows || !_initialized) {
      return;
    }

    try {
      await _notifications.cancel(notificationId);
    } catch (e) {
      if (kDebugMode) {
        print('[WindowsNotificationService] 알림 취소 중 오류: $e');
      }
    }
  }

  /// 모든 알림 취소
  static Future<void> cancelAllNotifications() async {
    if (!Platform.isWindows || !_initialized) {
      return;
    }

    try {
      await _notifications.cancelAll();
    } catch (e) {
      if (kDebugMode) {
        print('[WindowsNotificationService] 모든 알림 취소 중 오류: $e');
      }
    }
  }
}

