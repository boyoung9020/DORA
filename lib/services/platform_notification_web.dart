/// 웹 브라우저 Notification API 구현
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'platform_notification_service.dart';

/// 웹 브라우저 알림 서비스
class WebNotificationService extends PlatformNotificationService {
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // 브라우저가 Notification API를 지원하는지 확인
    if (!_isNotificationSupported()) {
      if (kDebugMode) {
        print('[WebNotification] 브라우저가 Notification API를 지원하지 않습니다.');
      }
      return;
    }

    _initialized = true;
    if (kDebugMode) {
      print('[WebNotification] 초기화 완료');
    }
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized || !_isNotificationSupported()) {
      if (kDebugMode) {
        print('[WebNotification] 알림을 표시할 수 없습니다 (초기화되지 않음 또는 지원되지 않음)');
      }
      return;
    }

    // 권한 확인
    final permission = web.Notification.permission;
    if (permission != 'granted') {
      if (kDebugMode) {
        print('[WebNotification] 알림 권한이 없습니다: $permission');
      }
      return;
    }

    try {
      // 브라우저 알림 생성
      final options = web.NotificationOptions(
        body: body,
        icon: '/favicon.png', // 앱 아이콘 (선택사항)
        tag: 'dora-chat', // 같은 태그의 알림은 하나만 표시
      );

      web.Notification(title, options);

      if (kDebugMode) {
        print('[WebNotification] 알림 표시: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WebNotification] 알림 표시 실패: $e');
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_isNotificationSupported()) {
      if (kDebugMode) {
        print('[WebNotification] Notification API를 지원하지 않습니다.');
      }
      return false;
    }

    try {
      // 현재 권한 상태 확인
      final currentPermission = web.Notification.permission;
      if (currentPermission == 'granted') {
        if (kDebugMode) {
          print('[WebNotification] 이미 알림 권한이 허용되어 있습니다.');
        }
        return true;
      } else if (currentPermission == 'denied') {
        if (kDebugMode) {
          print('[WebNotification] 알림 권한이 거부되었습니다.');
        }
        return false;
      }

      // 권한 요청 (사용자에게 팝업 표시)
      final permission = await web.Notification.requestPermission().toDart;
      final granted = permission == 'granted';

      if (kDebugMode) {
        print('[WebNotification] 알림 권한 요청 결과: $permission');
      }

      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('[WebNotification] 권한 요청 실패: $e');
      }
      return false;
    }
  }

  /// 브라우저가 Notification API를 지원하는지 확인
  bool _isNotificationSupported() {
    try {
      // Notification API가 존재하는지 확인
      // permission 속성이 null이 아니면 지원함
      return web.Notification.permission != null;
    } catch (e) {
      return false;
    }
  }
}

/// 웹 알림 서비스 생성 함수
PlatformNotificationService createPlatformNotificationService() {
  return WebNotificationService();
}
