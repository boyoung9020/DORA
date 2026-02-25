import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../utils/api_client.dart';

class ChatService {
  Future<List<ChatRoom>> getRooms({String? workspaceId}) async {
    try {
      final queryParams = <String, String>{};
      if (workspaceId != null) {
        queryParams['workspace_id'] = workspaceId;
      }

      final response = await ApiClient.get(
        '/api/chat/rooms',
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final data = ApiClient.handleListResponse(response);
        return data
            .map((json) => ChatRoom.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to load chat rooms: ${response.statusCode}');
    } catch (e) {
      print('[ChatService] getRooms failed: $e');
      return [];
    }
  }

  Future<ChatRoom?> createRoom({
    required String type,
    required List<String> memberIds,
    String? name,
    String? projectId,
    String? workspaceId,
  }) async {
    try {
      final body = <String, dynamic>{'type': type, 'member_ids': memberIds};
      if (name != null) body['name'] = name;
      if (projectId != null) body['project_id'] = projectId;
      if (workspaceId != null) body['workspace_id'] = workspaceId;

      final response = await ApiClient.post('/api/chat/rooms', body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = ApiClient.handleResponse(response);
        return ChatRoom.fromJson(data);
      }

      throw Exception('Failed to create chat room: ${response.statusCode}');
    } catch (e) {
      print('[ChatService] createRoom failed: $e');
      return null;
    }
  }

  Future<List<ChatMessage>> getMessages(
    String roomId, {
    String? beforeId,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (beforeId != null) {
        queryParams['before_id'] = beforeId;
      }

      final response = await ApiClient.get(
        '/api/chat/rooms/$roomId/messages',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = ApiClient.handleListResponse(response);
        return data
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to load messages: ${response.statusCode}');
    } catch (e) {
      print('[ChatService] getMessages failed: $e');
      return [];
    }
  }

  Future<ChatMessage?> sendMessage(
    String roomId, {
    required String content,
    List<String>? imageUrls,
    List<String>? fileUrls,
  }) async {
    try {
      final body = <String, dynamic>{'content': content};
      if (imageUrls != null && imageUrls.isNotEmpty) {
        body['image_urls'] = imageUrls;
      }
      if (fileUrls != null && fileUrls.isNotEmpty) {
        body['file_urls'] = fileUrls;
      }

      final response = await ApiClient.post(
        '/api/chat/rooms/$roomId/messages',
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = ApiClient.handleResponse(response);
        return ChatMessage.fromJson(data);
      }

      throw Exception('Failed to send message: ${response.statusCode}');
    } catch (e) {
      print('[ChatService] sendMessage failed: $e');
      return null;
    }
  }

  Future<ChatMessage?> updateMessage(
    String roomId,
    String messageId,
    String content,
  ) async {
    try {
      final response = await ApiClient.patch(
        '/api/chat/rooms/$roomId/messages/$messageId',
        body: {'content': content},
      );
      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        return ChatMessage.fromJson(data);
      }

      throw Exception('Failed to update message: ${response.statusCode}');
    } catch (e) {
      print('[ChatService] updateMessage failed: $e');
      return null;
    }
  }

  Future<bool> deleteMessage(String roomId, String messageId) async {
    try {
      final response = await ApiClient.delete(
        '/api/chat/rooms/$roomId/messages/$messageId',
      );
      return response.statusCode == 204;
    } catch (e) {
      print('[ChatService] deleteMessage failed: $e');
      return false;
    }
  }

  Future<Map<String, List<String>>> toggleReaction(
    String roomId,
    String messageId,
    String emoji,
  ) async {
    try {
      final response = await ApiClient.post(
        '/api/chat/rooms/$roomId/messages/$messageId/reactions',
        body: {'emoji': emoji},
      );
      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        final raw = data['reactions'] as Map<String, dynamic>? ?? {};
        final parsed = <String, List<String>>{};
        raw.forEach((key, value) {
          parsed[key] =
              (value as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [];
        });
        return parsed;
      }
      throw Exception('Failed to toggle reaction: ${response.statusCode}');
    } catch (e) {
      print('[ChatService] toggleReaction failed: $e');
      return {};
    }
  }

  Future<bool> markAsRead(String roomId) async {
    try {
      final response = await ApiClient.patch(
        '/api/chat/rooms/$roomId/read',
        body: {},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[ChatService] markAsRead failed: $e');
      return false;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await ApiClient.get('/api/chat/rooms/unread-count');
      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        return data['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      print('[ChatService] getUnreadCount failed: $e');
      return 0;
    }
  }
}
