import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../services/windows_notification_service.dart';

/// 알림 상태 관리 Provider
class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  List<Notification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadCount = 0;

  List<Notification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;

  /// 읽지 않은 알림만 가져오기
  List<Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// 초기화 및 알림 로드
  Future<void> loadNotifications({String? userId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final previousUnreadCount = _unreadCount;
      final previousNotificationIds = _notifications.map((n) => n.id).toSet();
      
      _notifications = await _notificationService.getNotifications(userId: userId);
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 최신순 정렬
      _errorMessage = null;
      
      // 읽지 않은 알림 개수 업데이트
      await _updateUnreadCount(userId: userId);
      
      // 새로 추가된 읽지 않은 알림이 있으면 Windows 알림 표시
      final newNotifications = _notifications.where((n) => 
        !n.isRead && !previousNotificationIds.contains(n.id)
      ).toList();
      
      for (final notification in newNotifications) {
        WindowsNotificationService.showNotification(notification);
      }
    } catch (e) {
      _errorMessage = '알림을 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 읽지 않은 알림 개수 업데이트
  Future<void> _updateUnreadCount({String? userId}) async {
    try {
      _unreadCount = await _notificationService.getUnreadCount(userId: userId);
    } catch (e) {
      // 읽지 않은 알림 개수를 직접 계산
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    }
    notifyListeners();
  }

  /// 알림을 읽음으로 표시
  Future<bool> markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);
      if (success) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          await _updateUnreadCount();
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _errorMessage = '알림 읽음 표시 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 모든 알림을 읽음으로 표시
  Future<bool> markAllAsRead({String? userId}) async {
    try {
      final success = await _notificationService.markAllAsRead(userId: userId);
      if (success) {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        _unreadCount = 0;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = '모든 알림 읽음 표시 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 알림 삭제
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final success = await _notificationService.deleteNotification(notificationId);
      if (success) {
        _notifications.removeWhere((n) => n.id == notificationId);
        await _updateUnreadCount();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = '알림 삭제 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 새 알림 추가 (로컬에서만, 백엔드 동기화는 별도로)
  void addNotification(Notification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
    
    // Windows 빌드일 경우 Windows 시스템 알림 표시
    WindowsNotificationService.showNotification(notification);
  }

  /// 읽지 않은 알림 개수 새로고침
  Future<void> refreshUnreadCount({String? userId}) async {
    await _updateUnreadCount(userId: userId);
  }
}
