import '../utils/date_utils.dart';

/// 채팅방 타입
enum ChatRoomType { dm, group }

/// 채팅방 모델
class ChatRoom {
  final String id;
  final ChatRoomType type;
  final String? name;
  final String? projectId;
  final List<String> memberIds;
  final String? lastMessageContent;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatRoom({
    required this.id,
    required this.type,
    this.name,
    this.projectId,
    this.memberIds = const [],
    this.lastMessageContent,
    this.lastMessageSender,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final projectIdKey = json.containsKey('project_id') ? 'project_id' : 'projectId';
    final memberIdsKey = json.containsKey('member_ids') ? 'member_ids' : 'memberIds';
    final lastMsgContentKey = json.containsKey('last_message_content') ? 'last_message_content' : 'lastMessageContent';
    final lastMsgSenderKey = json.containsKey('last_message_sender') ? 'last_message_sender' : 'lastMessageSender';
    final lastMsgAtKey = json.containsKey('last_message_at') ? 'last_message_at' : 'lastMessageAt';
    final unreadCountKey = json.containsKey('unread_count') ? 'unread_count' : 'unreadCount';
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';
    final updatedAtKey = json.containsKey('updated_at') ? 'updated_at' : 'updatedAt';

    return ChatRoom(
      id: json['id'],
      type: json['type'] == 'dm' ? ChatRoomType.dm : ChatRoomType.group,
      name: json['name'],
      projectId: json[projectIdKey],
      memberIds: (json[memberIdsKey] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      lastMessageContent: json[lastMsgContentKey],
      lastMessageSender: json[lastMsgSenderKey],
      lastMessageAt: parseUtcToLocalOrNull(json[lastMsgAtKey]),
      unreadCount: json[unreadCountKey] ?? 0,
      createdAt: parseUtcToLocal(json[createdAtKey]),
      updatedAt: parseUtcToLocal(json[updatedAtKey]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'project_id': projectId,
      'member_ids': memberIds,
      'last_message_content': lastMessageContent,
      'last_message_sender': lastMessageSender,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ChatRoom copyWith({
    String? id,
    ChatRoomType? type,
    String? name,
    String? projectId,
    List<String>? memberIds,
    String? lastMessageContent,
    String? lastMessageSender,
    DateTime? lastMessageAt,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      memberIds: memberIds ?? this.memberIds,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
