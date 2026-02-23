/// Windows 네이티브 알림 구현 (MethodChannel)
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'platform_notification_service.dart';

/// Windows 네이티브 알림 서비스
class NativeNotificationService extends PlatformNotificationService {
  static const MethodChannel _channel = MethodChannel('com.dora/notifications');
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // Windows 플랫폼인지 확인
    if (!Platform.isWindows) {
      if (kDebugMode) {
        print('[NativeNotification] Windows 플랫폼이 아닙니다.');
      }
      return;
    }

    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      _initialized = result ?? false;

      if (kDebugMode) {
        print('[NativeNotification] 초기화 완료: $_initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NativeNotification] 초기화 실패: $e');
      }
    }
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      if (kDebugMode) {
        print('[NativeNotification] 초기화되지 않아 알림을 표시할 수 없습니다.');
      }
      return;
    }

    if (!Platform.isWindows) {
      if (kDebugMode) {
        print('[NativeNotification] Windows 플랫폼이 아닙니다.');
      }
      return;
    }

    try {
      await _channel.invokeMethod('showNotification', {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'message': body,
      });

      if (kDebugMode) {
        print('[NativeNotification] 알림 표시: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NativeNotification] 알림 표시 실패: $e');
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    // Windows는 별도 권한 요청이 필요 없음
    if (kDebugMode) {
      print('[NativeNotification] Windows는 알림 권한 요청이 필요 없습니다.');
    }
    return true;
  }
}

/// 네이티브 알림 서비스 생성 함수
PlatformNotificationService createPlatformNotificationService() {
  return NativeNotificationService();
}
