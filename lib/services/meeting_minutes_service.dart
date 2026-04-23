import '../models/meeting_minutes.dart';
import '../utils/api_client.dart';

/// 회의록 서비스 클래스
class MeetingMinutesService {
  /// 회의록 목록 조회
  Future<List<MeetingMinutes>> getAll({
    required String workspaceId,
    String? category,
  }) async {
    try {
      final queryParams = <String, String>{
        'workspace_id': workspaceId,
      };
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      final response = await ApiClient.get(
        '/api/meeting-minutes/',
        queryParams: queryParams,
      );
      final data = ApiClient.handleListResponse(response);
      return data
          .map((json) => MeetingMinutes.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('회의록 목록 가져오기 실패: $e');
    }
  }

  /// 카테고리 목록 조회
  Future<List<String>> getCategories({required String workspaceId}) async {
    try {
      final response = await ApiClient.get(
        '/api/meeting-minutes/categories',
        queryParams: {'workspace_id': workspaceId},
      );
      final data = ApiClient.handleListResponse(response);
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      throw Exception('카테고리 목록 가져오기 실패: $e');
    }
  }

  /// 회의록 상세 조회
  Future<MeetingMinutes> getById(String id) async {
    try {
      final response = await ApiClient.get('/api/meeting-minutes/$id');
      final data = ApiClient.handleResponse(response);
      return MeetingMinutes.fromJson(data);
    } catch (e) {
      throw Exception('회의록 조회 실패: $e');
    }
  }

  /// 회의록 생성
  Future<MeetingMinutes> create({
    required String workspaceId,
    required String title,
    String content = '',
    String category = '',
    required DateTime meetingDate,
    List<String> attendeeIds = const [],
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/meeting-minutes/',
        body: {
          'workspace_id': workspaceId,
          'title': title,
          'content': content,
          'category': category,
          'meeting_date': meetingDate.toIso8601String().split('T').first,
          'attendee_ids': attendeeIds,
        },
      );
      final data = ApiClient.handleResponse(response);
      return MeetingMinutes.fromJson(data);
    } catch (e) {
      throw Exception('회의록 생성 실패: $e');
    }
  }

  /// 회의록 수정
  Future<MeetingMinutes> update(
    String id, {
    String? title,
    String? content,
    String? category,
    DateTime? meetingDate,
    List<String>? attendeeIds,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (content != null) body['content'] = content;
      if (category != null) body['category'] = category;
      if (meetingDate != null) {
        body['meeting_date'] = meetingDate.toIso8601String().split('T').first;
      }
      if (attendeeIds != null) body['attendee_ids'] = attendeeIds;

      final response = await ApiClient.patch(
        '/api/meeting-minutes/$id',
        body: body,
      );
      final data = ApiClient.handleResponse(response);
      return MeetingMinutes.fromJson(data);
    } catch (e) {
      throw Exception('회의록 수정 실패: $e');
    }
  }

  /// 회의록 삭제
  Future<void> delete(String id) async {
    try {
      await ApiClient.delete('/api/meeting-minutes/$id');
    } catch (e) {
      throw Exception('회의록 삭제 실패: $e');
    }
  }
}
