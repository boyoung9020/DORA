import 'package:flutter/foundation.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

/// 채팅 상태 관리 Provider
class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<ChatRoom> _rooms = [];
  final Map<String, List<ChatMessage>> _messagesByRoom = {};
  final Map<String, bool> _hasMoreMessages = {};
  String? _currentRoomId;
  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _errorMessage;
  int _totalUnreadCount = 0;

  List<ChatRoom> get rooms => _rooms;
  String? get currentRoomId => _currentRoomId;
  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  int get totalUnreadCount => _totalUnreadCount;

  List<ChatMessage> get currentMessages =>
      _messagesByRoom[_currentRoomId] ?? [];

  ChatRoom? get currentRoom {
    if (_currentRoomId == null) return null;
    try {
      return _rooms.firstWhere((r) => r.id == _currentRoomId);
    } catch (_) {
      return null;
    }
  }

  bool hasMoreMessages(String roomId) => _hasMoreMessages[roomId] ?? true;

  /// 채팅방 목록 로드
  Future<void> loadRooms() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rooms = await _chatService.getRooms();
      _totalUnreadCount = _rooms.fold(0, (sum, r) => sum + r.unreadCount);
    } catch (e) {
      _errorMessage = '채팅방 목록 로드 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 채팅방 선택
  void selectRoom(String roomId) {
    _currentRoomId = roomId;
    notifyListeners();

    // 메시지가 캐시에 없으면 로드
    if (!_messagesByRoom.containsKey(roomId)) {
      loadMessages(roomId);
    }

    // 읽음 처리
    markRoomAsRead(roomId);
  }

  /// 메시지 로드 (초기 + 무한 스크롤)
  Future<void> loadMessages(String roomId, {bool loadMore = false}) async {
    if (_isLoadingMessages) return;

    _isLoadingMessages = true;
    notifyListeners();

    try {
      String? beforeId;
      if (loadMore) {
        final existing = _messagesByRoom[roomId];
        if (existing != null && existing.isNotEmpty) {
          beforeId = existing.first.id; // 가장 오래된 메시지
        }
      }

      final messages = await _chatService.getMessages(
        roomId,
        beforeId: beforeId,
        limit: 50,
      );

      if (loadMore) {
        // 이전 메시지를 앞에 추가
        final existing = _messagesByRoom[roomId] ?? [];
        _messagesByRoom[roomId] = [...messages, ...existing];
      } else {
        _messagesByRoom[roomId] = messages;
      }

      _hasMoreMessages[roomId] = messages.length >= 50;
    } catch (e) {
      _errorMessage = '메시지 로드 실패: $e';
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// 메시지 전송
  Future<bool> sendMessage(String content, {List<String>? imageUrls, List<String>? fileUrls}) async {
    if (_currentRoomId == null) return false;
    _isSending = true;
    notifyListeners();

    try {
      final message = await _chatService.sendMessage(
        _currentRoomId!,
        content: content,
        imageUrls: imageUrls,
        fileUrls: fileUrls,
      );

      if (message != null) {
        // 로컬 메시지 리스트에 추가
        final existing = _messagesByRoom[_currentRoomId] ?? [];
        _messagesByRoom[_currentRoomId!] = [...existing, message];

        // 채팅방 마지막 메시지 업데이트 (첨부만 있으면 '이미지'/'파일' 표시)
        _updateRoomLastMessage(
          _currentRoomId!,
          message.content,
          message.senderUsername,
          message.createdAt,
          imageUrls: message.imageUrls,
          fileUrls: message.fileUrls,
        );

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = '메시지 전송 실패: $e';
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// WebSocket으로 수신된 메시지 처리
  void handleIncomingMessage(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    if (roomId == null) return;

    final message = ChatMessage(
      id: data['message_id'] ?? '',
      roomId: roomId,
      senderId: data['sender_id'] ?? '',
      senderUsername: data['sender_username'] ?? '',
      content: data['content'] ?? '',
      imageUrls: (data['image_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fileUrls: (data['file_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
    );

    // 메시지 캐시에 추가
    final existing = _messagesByRoom[roomId] ?? [];
    _messagesByRoom[roomId] = [...existing, message];

    // 채팅방 마지막 메시지 업데이트 (첨부만 있으면 '이미지'/'파일' 표시)
    _updateRoomLastMessage(
      roomId,
      message.content,
      message.senderUsername,
      message.createdAt,
      imageUrls: message.imageUrls,
      fileUrls: message.fileUrls,
    );

    // 현재 보고 있는 방이 아니면 안읽은 수 증가
    if (_currentRoomId != roomId) {
      final idx = _rooms.indexWhere((r) => r.id == roomId);
      if (idx != -1) {
        _rooms[idx] = _rooms[idx].copyWith(
          unreadCount: _rooms[idx].unreadCount + 1,
        );
        _totalUnreadCount++;
      }
    } else {
      // 현재 방이면 바로 읽음 처리
      markRoomAsRead(roomId);
    }

    notifyListeners();
  }

  /// 새 채팅방 생성 이벤트 처리
  void handleRoomCreated(Map<String, dynamic> data) {
    // 채팅방 목록 새로고침
    loadRooms();
  }

  /// 읽음 처리
  Future<void> markRoomAsRead(String roomId) async {
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx != -1 && _rooms[idx].unreadCount > 0) {
      _totalUnreadCount -= _rooms[idx].unreadCount;
      if (_totalUnreadCount < 0) _totalUnreadCount = 0;
      _rooms[idx] = _rooms[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
    await _chatService.markAsRead(roomId);
  }

  /// 안읽은 수 새로고침
  Future<void> refreshUnreadCount() async {
    _totalUnreadCount = await _chatService.getUnreadCount();
    notifyListeners();
  }

  /// DM 채팅방 생성 또는 기존 반환
  Future<ChatRoom?> getOrCreateDMRoom(String otherUserId) async {
    final room = await _chatService.createRoom(
      type: 'dm',
      memberIds: [otherUserId],
    );
    if (room != null) {
      // 로컬 목록에 없으면 추가
      final exists = _rooms.any((r) => r.id == room.id);
      if (!exists) {
        _rooms.insert(0, room);
        notifyListeners();
      }
    }
    return room;
  }

  /// 그룹 채팅방 생성
  Future<ChatRoom?> createGroupRoom({
    required String name,
    required List<String> memberIds,
    String? projectId,
  }) async {
    final room = await _chatService.createRoom(
      type: 'group',
      memberIds: memberIds,
      name: name,
      projectId: projectId,
    );
    if (room != null) {
      _rooms.insert(0, room);
      notifyListeners();
    }
    return room;
  }

  void _updateRoomLastMessage(
    String roomId,
    String content,
    String sender,
    DateTime at, {
    List<String>? imageUrls,
    List<String>? fileUrls,
  }) {
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) return;
    final contentTrim = content.trim();
    String preview = contentTrim;
    if (contentTrim.isEmpty || contentTrim == ' ') {
      if ((imageUrls ?? []).isNotEmpty) {
        preview = '이미지';
      } else if ((fileUrls ?? []).isNotEmpty) {
        preview = '파일';
      }
    }
    _rooms[idx] = _rooms[idx].copyWith(
      lastMessageContent: preview.isEmpty ? null : preview,
      lastMessageSender: sender,
      lastMessageAt: at,
    );
    final room = _rooms.removeAt(idx);
    _rooms.insert(0, room);
  }
}
