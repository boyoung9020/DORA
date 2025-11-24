import '../models/notification.dart';
import '../utils/api_client.dart';

/// 알림 서비스
/// 백엔드 API를 통해 알림을 가져오고 관리합니다.
class NotificationService {
  /// 사용자의 모든 알림 가져오기
  Future<List<Notification>> getNotifications({String? userId}) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null) {
        queryParams['user_id'] = userId;
      }

      final response = await ApiClient.get(
        '/api/notifications',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final data = ApiClient.handleListResponse(response);
        return data.map((json) => Notification.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('알림을 불러오는 중 오류가 발생했습니다: ${response.statusCode}');
      }
    } catch (e) {
      // 백엔드 API가 아직 구현되지 않은 경우 빈 리스트 반환
      print('[NotificationService] 알림 API 호출 실패 (백엔드 미구현 가능): $e');
      return [];
    }
  }

  /// 읽지 않은 알림 개수 가져오기
  Future<int> getUnreadCount({String? userId}) async {
    try {
      final queryParams = <String, String>{
        'unread_only': 'true',
      };
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
      final response = await ApiClient.delete('/api/notifications/$notificationId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('[NotificationService] 알림 삭제 실패: $e');
      return false;
    }
  }
}

