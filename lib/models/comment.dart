/// 댓글 모델 클래스
class Comment {
  final String id;
  final String taskId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Comment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.username,
    required this.content,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// JSON에서 Comment 객체 생성
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      taskId: json['taskId'],
      userId: json['userId'],
      username: json['username'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  /// 댓글을 수정한 복사본 생성
  Comment copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? username,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Comment(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

