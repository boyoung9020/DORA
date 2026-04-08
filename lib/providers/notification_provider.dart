import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../services/windows_notification_service.dart';

/// 알림 상태 관리 Provider
class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  List<Notification> _notifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _unreadCount = 0;
  int _totalCount = 0;
  bool _hasMore = false;
  String? _currentUsernameForFilter;
  String? _currentUserIdForSync;
  /// 다음 API 요청 시 사용할 skip (서버 기준, 필터와 무관)
  int _nextApiSkip = 0;

  List<Notification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;
  int get totalCount => _totalCount;
  bool get hasMore => _hasMore;

  /// 읽지 않은 알림만 가져오기
  List<Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  bool _isSelfTriggeredNotification(Notification notification) {
    final username = _currentUsernameForFilter;
    if (username == null || username.trim().isEmpty) return false;
    final actorPrefix = '${username.trim()}님이';
    return notification.message.trimLeft().startsWith(actorPrefix);
  }

  List<Notification> _applySelfTriggeredFilter(List<Notification> source) {
    if (_currentUsernameForFilter == null ||
        _currentUsernameForFilter!.isEmpty) {
      return source;
    }
    return source.where((n) => !_isSelfTriggeredNotification(n)).toList();
  }

  /// 초기화 및 알림 로드
  Future<void> loadNotifications({
    String? userId,
    String? currentUsername,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _currentUsernameForFilter = currentUsername;
    _currentUserIdForSync = userId;
    _nextApiSkip = 0;
    notifyListeners();

    try {
      final previousNotificationIds = _notifications.map((n) => n.id).toSet();

      final page = await _notificationService.getNotifications(
        userId: userId,
        skip: 0,
        limit: 50,
      );
      _notifications = _applySelfTriggeredFilter(page.items);
      _notifications.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      ); // 최신순 정렬
      _totalCount = page.total;
      _hasMore = page.hasMore;
      _nextApiSkip = page.rawReturnedCount;
      _errorMessage = null;

      // 배지: 목록과 동일하게 '본인 행위 알림'을 제외한 미읽음 개수 (서버 전체 미읽음과 불일치 방지)
      await _syncUnreadCountVisibleToUser(userId: userId);

      // 새로 추가된 읽지 않은 알림이 있으면 Windows 알림 표시
      final newNotifications = _notifications
          .where((n) => !n.isRead && !previousNotificationIds.contains(n.id))
          .toList();

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

  /// 추가 알림 로드 (무한 스크롤)
  Future<void> loadMoreNotifications({String? userId}) async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _notificationService.getNotifications(
        userId: userId,
        skip: _nextApiSkip,
        limit: 50,
      );
      final filtered = _applySelfTriggeredFilter(page.items);
      _notifications.addAll(filtered);
      _totalCount = page.total;
      _hasMore = page.hasMore;
      _nextApiSkip += page.rawReturnedCount;
    } catch (e) {
      _errorMessage = '추가 알림을 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 읽지 않은 알림 개수 업데이트 (현재 로드된 목록 기준)
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  /// 미읽음만 페이지로 가져와, 목록과 같은 규칙으로 필터한 뒤 개수 합산
  Future<void> _syncUnreadCountVisibleToUser({String? userId}) async {
    final uid = userId ?? _currentUserIdForSync;
    if (uid == null) {
      _updateUnreadCount();
      return;
    }
    try {
      var sum = 0;
      var skip = 0;
      const limit = 100;
      const maxSkip = 50000;
      while (skip <= maxSkip) {
        final page = await _notificationService.getNotifications(
          userId: uid,
          skip: skip,
          limit: limit,
          unreadOnly: true,
        );
        sum += _applySelfTriggeredFilter(page.items).length;
        if (!page.hasMore) break;
        skip += page.rawReturnedCount;
        if (page.rawReturnedCount == 0) break;
      }
      _unreadCount = sum;
      notifyListeners();
    } catch (_) {
      _updateUnreadCount();
    }
  }

  /// 다른 화면에서 배지만 갱신할 때 (로그인 사용자 id 유지 가정)
  Future<void> refreshBadgeUnreadCount() async {
    await _syncUnreadCountVisibleToUser(userId: _currentUserIdForSync);
  }

  /// 알림을 읽음으로 표시
  Future<bool> markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);
      if (success) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          final wasUnread = !_notifications[index].isRead;
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          if (wasUnread && _unreadCount > 0) {
            _unreadCount--;
          }
          notifyListeners();
        } else {
          await _syncUnreadCountVisibleToUser(userId: _currentUserIdForSync);
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
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        await _syncUnreadCountVisibleToUser(userId: userId);
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
      final success = await _notificationService.deleteNotification(
        notificationId,
      );
      if (success) {
        final idx = _notifications.indexWhere((n) => n.id == notificationId);
        if (idx != -1) {
          final wasUnread = !_notifications[idx].isRead;
          _notifications.removeAt(idx);
          if (wasUnread && _unreadCount > 0) {
            _unreadCount--;
          }
          notifyListeners();
        } else {
          await _syncUnreadCountVisibleToUser(userId: _currentUserIdForSync);
        }
      }
      return success;
    } catch (e) {
      _errorMessage = '알림 삭제 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 모든 알림 삭제
  Future<bool> deleteAllNotifications() async {
    try {
      final success = await _notificationService.deleteAllNotifications();
      if (success) {
        _notifications = [];
        _unreadCount = 0;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = '모든 알림 삭제 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 새 알림 추가 (로컬에서만, 백엔드 동기화는 별도로)
  void addNotification(Notification notification) {
    if (_isSelfTriggeredNotification(notification)) {
      return;
    }
    if (_notifications.any((n) => n.id == notification.id)) {
      return;
    }
    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();

    // Windows 빌드일 경우 Windows 시스템 알림 표시
    WindowsNotificationService.showNotification(notification);
  }

  /// 읽지 않은 알림 개수 새로고침
  Future<void> refreshUnreadCount({String? currentUsername}) async {
    if (currentUsername != null) {
      _currentUsernameForFilter = currentUsername;
      _notifications = _applySelfTriggeredFilter(_notifications);
    }
    _updateUnreadCount();
  }
}
