/// 채팅 메시지 모델
class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String content;
  final List<String> imageUrls;
  final List<String> fileUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    this.imageUrls = const [],
    this.fileUrls = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roomIdKey = json.containsKey('room_id') ? 'room_id' : 'roomId';
    final senderIdKey = json.containsKey('sender_id') ? 'sender_id' : 'senderId';
    final senderUsernameKey = json.containsKey('sender_username') ? 'sender_username' : 'senderUsername';
    final imageUrlsKey = json.containsKey('image_urls') ? 'image_urls' : 'imageUrls';
    final fileUrlsKey = json.containsKey('file_urls') ? 'file_urls' : 'fileUrls';
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';
    final updatedAtKey = json.containsKey('updated_at') ? 'updated_at' : 'updatedAt';

    return ChatMessage(
      id: json['id'],
      roomId: json[roomIdKey],
      senderId: json[senderIdKey],
      senderUsername: json[senderUsernameKey] ?? '',
      content: json['content'] ?? '',
      imageUrls: (json[imageUrlsKey] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      fileUrls: (json[fileUrlsKey] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: DateTime.parse(json[createdAtKey]),
      updatedAt: json[updatedAtKey] != null ? DateTime.parse(json[updatedAtKey]) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'sender_username': senderUsername,
      'content': content,
      'image_urls': imageUrls,
      'file_urls': fileUrls,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderUsername,
    String? content,
    List<String>? imageUrls,
    List<String>? fileUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      fileUrls: fileUrls ?? this.fileUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
