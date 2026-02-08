import '../utils/date_utils.dart';

/// 댓글 모델 클래스
class Comment {
  final String id;
  final String taskId;
  final String userId;
  final String username;
  final String content;
  final List<String> imageUrls;  // 이미지 URL 배열
  final DateTime createdAt;
  final DateTime? updatedAt;

  Comment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.username,
    required this.content,
    this.imageUrls = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// JSON으로 변환 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'username': username,
      'content': content,
      'image_urls': imageUrls,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// JSON에서 Comment 객체 생성
  factory Comment.fromJson(Map<String, dynamic> json) {
    // API 응답은 snake_case, 로컬 저장은 camelCase 지원
    final taskIdKey = json.containsKey('task_id') ? 'task_id' : 'taskId';
    final userIdKey = json.containsKey('user_id') ? 'user_id' : 'userId';
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';
    final updatedAtKey = json.containsKey('updated_at') ? 'updated_at' : 'updatedAt';
    final imageUrlsKey = json.containsKey('image_urls') ? 'image_urls' : 'imageUrls';
    
    return Comment(
      id: json['id'],
      taskId: json[taskIdKey],
      userId: json[userIdKey],
      username: json['username'],
      content: json['content'],
      imageUrls: json[imageUrlsKey] != null 
          ? List<String>.from(json[imageUrlsKey])
          : [],
      createdAt: parseUtcToLocal(json[createdAtKey]),
      updatedAt: parseUtcToLocalOrNull(json[updatedAtKey]),
    );
  }

  /// 댓글을 수정한 복사본 생성
  Comment copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? username,
    String? content,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Comment(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

