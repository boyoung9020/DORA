import '../utils/date_utils.dart';

enum NotificationType {
  projectMemberAdded,
  taskAssigned,
  taskOptionChanged,
  taskCommentAdded,
  taskMentioned,
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.projectMemberAdded:
        return '프로젝트 멤버 추가';
      case NotificationType.taskAssigned:
        return '작업 할당';
      case NotificationType.taskOptionChanged:
        return '작업 옵션 변경';
      case NotificationType.taskCommentAdded:
        return '작업 댓글';
      case NotificationType.taskMentioned:
        return '멘션';
    }
  }

  String get description {
    switch (this) {
      case NotificationType.projectMemberAdded:
        return '프로젝트 팀원으로 추가되었습니다';
      case NotificationType.taskAssigned:
        return '작업 담당자로 지정되었습니다';
      case NotificationType.taskOptionChanged:
        return '작업 옵션이 변경되었습니다';
      case NotificationType.taskCommentAdded:
        return '작업에 새 댓글이 추가되었습니다';
      case NotificationType.taskMentioned:
        return '댓글에서 멘션되었습니다';
    }
  }
}

class Notification {
  final String id;
  final NotificationType type;
  final String userId;
  final String? projectId;
  final String? taskId;
  final String? commentId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.type,
    required this.userId,
    this.projectId,
    this.taskId,
    this.commentId,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'user_id': userId,
      'project_id': projectId,
      'task_id': taskId,
      'comment_id': commentId,
      'title': title,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Notification.fromJson(Map<String, dynamic> json) {
    final userIdKey = json.containsKey('user_id') ? 'user_id' : 'userId';
    final projectIdKey = json.containsKey('project_id') ? 'project_id' : 'projectId';
    final taskIdKey = json.containsKey('task_id') ? 'task_id' : 'taskId';
    final commentIdKey = json.containsKey('comment_id') ? 'comment_id' : 'commentId';
    final isReadKey = json.containsKey('is_read') ? 'is_read' : 'isRead';
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';

    final rawType = json['type']?.toString() ?? '';
    final mappedType = NotificationType.values.firstWhere(
      (e) => e.name == rawType,
      orElse: () => NotificationType.taskAssigned,
    );

    return Notification(
      id: json['id'].toString(),
      type: mappedType,
      userId: json[userIdKey].toString(),
      projectId: json[projectIdKey]?.toString(),
      taskId: json[taskIdKey]?.toString(),
      commentId: json[commentIdKey]?.toString(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: json[isReadKey] as bool? ?? false,
      createdAt: parseUtcToLocal(json[createdAtKey]),
    );
  }

  Notification copyWith({
    String? id,
    NotificationType? type,
    String? userId,
    String? projectId,
    String? taskId,
    String? commentId,
    String? title,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      commentId: commentId ?? this.commentId,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
