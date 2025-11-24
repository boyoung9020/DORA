import 'package:flutter/material.dart';
import '../models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;

  /// 알림 추가
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification); // 최신 알림을 맨 위에
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
  }

  /// 알림 읽음 처리
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCount--;
      notifyListeners();
    }
  }

  /// 모든 알림 읽음 처리
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _unreadCount = 0;
    notifyListeners();
  }

  /// 알림 삭제
  void removeNotification(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      if (!_notifications[index].isRead) {
        _unreadCount--;
      }
      _notifications.removeAt(index);
      notifyListeners();
    }
  }

  /// 모든 알림 삭제
  void clearAll() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  /// 읽지 않은 알림만 필터링
  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }
}

