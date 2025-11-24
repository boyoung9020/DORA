import 'dart:io';
import 'package:flutter/services.dart';
import '../models/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('com.dora/notifications');
  bool _isInitialized = false;

  /// 알림 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (Platform.isWindows) {
      try {
        await _channel.invokeMethod('initialize');
        _isInitialized = true;
      } catch (e) {
        print('[Notification] 초기화 실패: $e');
      }
    } else {
      _isInitialized = true;
    }
  }

  /// Windows 알림 표시
  Future<void> showNotification(AppNotification notification) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (Platform.isWindows) {
      try {
        await _channel.invokeMethod('showNotification', {
          'id': notification.id,
          'title': notification.title,
          'message': notification.message,
        });
      } catch (e) {
        print('[Notification] 알림 표시 실패: $e');
      }
    } else {
      // 다른 플랫폼에서는 콘솔에 출력
      print('[Notification] ${notification.title}: ${notification.message}');
    }
  }

  /// 알림 취소
  Future<void> cancelNotification(String notificationId) async {
    if (Platform.isWindows) {
      try {
        await _channel.invokeMethod('cancelNotification', {'id': notificationId});
      } catch (e) {
        print('[Notification] 알림 취소 실패: $e');
      }
    }
  }

  /// 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    if (Platform.isWindows) {
      try {
        await _channel.invokeMethod('cancelAllNotifications');
      } catch (e) {
        print('[Notification] 모든 알림 취소 실패: $e');
      }
    }
  }
}
