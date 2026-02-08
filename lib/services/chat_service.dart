import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../utils/api_client.dart';

/// 채팅 서비스
class ChatService {
  /// 채팅방 목록 가져오기
  Future<List<ChatRoom>> getRooms() async {
    try {
      final response = await ApiClient.get('/api/chat/rooms');
      if (response.statusCode == 200) {
        final data = ApiClient.handleListResponse(response);
        return data.map((json) => ChatRoom.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('채팅방 목록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatService] 채팅방 목록 조회 실패: $e');
      return [];
    }
  }

  /// 채팅방 생성
  Future<ChatRoom?> createRoom({
    required String type,
    required List<String> memberIds,
    String? name,
    String? projectId,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': type,
        'member_ids': memberIds,
      };
      if (name != null) body['name'] = name;
      if (projectId != null) body['project_id'] = projectId;

      final response = await ApiClient.post('/api/chat/rooms', body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = ApiClient.handleResponse(response);
        return ChatRoom.fromJson(data);
      } else {
        throw Exception('채팅방 생성 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatService] 채팅방 생성 실패: $e');
      return null;
    }
  }

  /// 메시지 목록 가져오기 (커서 기반 페이지네이션)
  Future<List<ChatMessage>> getMessages(String roomId, {String? beforeId, int limit = 50}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (beforeId != null) {
        queryParams['before_id'] = beforeId;
      }

      final response = await ApiClient.get(
        '/api/chat/rooms/$roomId/messages',
        queryParams: queryParams,
      );
      if (response.statusCode == 200) {
        final data = ApiClient.handleListResponse(response);
        return data.map((json) => ChatMessage.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('메시지 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatService] 메시지 조회 실패: $e');
      return [];
    }
  }

  /// 메시지 전송
  Future<ChatMessage?> sendMessage(String roomId, {required String content, List<String>? imageUrls, List<String>? fileUrls}) async {
    try {
      final body = <String, dynamic>{
        'content': content,
      };
      if (imageUrls != null && imageUrls.isNotEmpty) {
        body['image_urls'] = imageUrls;
      }
      if (fileUrls != null && fileUrls.isNotEmpty) {
        body['file_urls'] = fileUrls;
      }

      final response = await ApiClient.post('/api/chat/rooms/$roomId/messages', body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = ApiClient.handleResponse(response);
        return ChatMessage.fromJson(data);
      } else {
        throw Exception('메시지 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatService] 메시지 전송 실패: $e');
      return null;
    }
  }

  /// 채팅방 읽음 처리
  Future<bool> markAsRead(String roomId) async {
    try {
      final response = await ApiClient.patch('/api/chat/rooms/$roomId/read', body: {});
      return response.statusCode == 200;
    } catch (e) {
      print('[ChatService] 읽음 처리 실패: $e');
      return false;
    }
  }

  /// 전체 안읽은 메시지 수
  Future<int> getUnreadCount() async {
    try {
      final response = await ApiClient.get('/api/chat/rooms/unread-count');
      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        return data['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      print('[ChatService] 안읽은 수 조회 실패: $e');
      return 0;
    }
  }
}
