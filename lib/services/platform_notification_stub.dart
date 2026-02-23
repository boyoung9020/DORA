/// Stub 구현 - 지원되지 않는 플랫폼용 기본 구현
import 'package:flutter/foundation.dart';
import 'platform_notification_service.dart';

/// Stub 알림 서비스 (아무것도 하지 않음)
class StubNotificationService extends PlatformNotificationService {
  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      print('[PlatformNotification] Stub - 지원되지 않는 플랫폼입니다.');
    }
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (kDebugMode) {
      print('[PlatformNotification] Stub - 알림: $title - $body');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kDebugMode) {
      print('[PlatformNotification] Stub - 권한 요청 (자동 승인)');
    }
    return true;
  }
}

/// Stub 서비스 생성 함수
PlatformNotificationService createPlatformNotificationService() {
  return StubNotificationService();
}
