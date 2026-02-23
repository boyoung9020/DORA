/// 플랫폼별 알림 서비스 인터페이스
/// 웹과 네이티브 플랫폼에서 각각 다른 구현을 사용
import 'platform_notification_stub.dart'
    if (dart.library.html) 'platform_notification_web.dart'
    if (dart.library.io) 'platform_notification_native.dart';

/// 플랫폼별 알림 서비스 추상 클래스
abstract class PlatformNotificationService {
  static PlatformNotificationService? _instance;

  /// 싱글톤 인스턴스
  static PlatformNotificationService get instance {
    _instance ??= createPlatformNotificationService();
    return _instance!;
  }

  /// 알림 서비스 초기화
  Future<void> initialize();

  /// 알림 표시
  Future<void> showNotification({
    required String title,
    required String body,
  });

  /// 알림 권한 요청 (웹에서만 필요)
  Future<bool> requestPermission();
}
