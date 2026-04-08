import '../models/notification.dart';
import '../utils/api_client.dart';

/// 페이지네이션된 알림 응답
class NotificationPage {
  final List<Notification> items;
  final int total;
  final bool hasMore;
  /// API가 반환한 원본 항목 수 (클라이언트 필터 전). 다음 [skip] 계산에 사용.
  final int rawReturnedCount;

  const NotificationPage({
    required this.items,
    required this.total,
    required this.hasMore,
    this.rawReturnedCount = 0,
  });
}

/// 알림 서비스
/// 백엔드 API를 통해 알림을 가져오고 관리합니다.
class NotificationService {
  /// 사용자의 알림 가져오기 (페이지네이션 지원)
  Future<NotificationPage> getNotifications({
    String? userId,
    int skip = 0,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (userId != null) {
        queryParams['user_id'] = userId;
      }
      if (unreadOnly) {
        queryParams['unread_only'] = 'true';
      }

      final response = await ApiClient.get(
        '/api/notifications/',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        final rawList = data['items'] as List<dynamic>? ?? [];
        final items = rawList
            .map((json) =>
                Notification.fromJson(json as Map<String, dynamic>))
            .toList();
        return NotificationPage(
          items: items,
          total: data['total'] as int? ?? items.length,
          hasMore: data['has_more'] as bool? ?? false,
          rawReturnedCount: rawList.length,
        );
      } else {
        throw Exception('알림을 불러오는 중 오류가 발생했습니다: ${response.statusCode}');
      }
    } catch (e) {
      print('[NotificationService] 알림 API 호출 실패 (백엔드 미구현 가능): $e');
      return NotificationPage(
        items: [],
        total: 0,
        hasMore: false,
        rawReturnedCount: 0,
      );
    }
  }

  /// 읽지 않은 알림 개수 가져오기
  Future<int> getUnreadCount({String? userId}) async {
    try {
      final queryParams = <String, String>{'unread_only': 'true'};
      if (userId != null) {
        queryParams['user_id'] = userId;
      }

      final response = await ApiClient.get(
        '/api/notifications/count',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        return data['count'] as int? ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      print('[NotificationService] 읽지 않은 알림 개수 조회 실패: $e');
      return 0;
    }
  }

  /// 알림을 읽음으로 표시
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await ApiClient.patch(
        '/api/notifications/$notificationId/read',
        body: {'is_read': true},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[NotificationService] 알림 읽음 표시 실패: $e');
      return false;
    }
  }

  /// 모든 알림을 읽음으로 표시
  Future<bool> markAllAsRead({String? userId}) async {
    try {
      final body = <String, dynamic>{'is_read': true};
      if (userId != null) {
        body['user_id'] = userId;
      }

      final response = await ApiClient.patch(
        '/api/notifications/read-all',
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[NotificationService] 모든 알림 읽음 표시 실패: $e');
      return false;
    }
  }

  /// 알림 삭제
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await ApiClient.delete(
        '/api/notifications/$notificationId',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('[NotificationService] 알림 삭제 실패: $e');
      return false;
    }
  }

  /// 모든 알림 삭제
  Future<bool> deleteAllNotifications() async {
    try {
      final response = await ApiClient.delete('/api/notifications/');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('[NotificationService] 모든 알림 삭제 실패: $e');
      return false;
    }
  }
}
