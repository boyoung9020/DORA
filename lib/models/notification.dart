/// 알림 타입 열거형
enum NotificationType {
  projectMemberAdded,      // 프로젝트 팀원으로 추가됨
  taskAssigned,            // 작업 할당자로 임명됨
  taskOptionChanged,       // 작업 옵션 변경 (중요도, 상태, 날짜)
  taskCommentAdded,        // 작업에 코멘트 추가됨
}

/// 알림 타입별 확장
extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.projectMemberAdded:
        return '프로젝트 팀원 추가';
      case NotificationType.taskAssigned:
        return '작업 할당';
      case NotificationType.taskOptionChanged:
        return '작업 옵션 변경';
      case NotificationType.taskCommentAdded:
        return '작업 코멘트';
    }
  }

  String get description {
    switch (this) {
      case NotificationType.projectMemberAdded:
        return '프로젝트에 팀원으로 추가되었습니다';
      case NotificationType.taskAssigned:
        return '작업의 할당자로 임명되었습니다';
      case NotificationType.taskOptionChanged:
        return '작업의 옵션이 변경되었습니다';
      case NotificationType.taskCommentAdded:
        return '작업에 새로운 코멘트가 추가되었습니다';
    }
  }
}

/// 알림 모델 클래스
class Notification {
  final String id;
  final NotificationType type;
  final String userId; // 알림을 받는 사용자 ID
  final String? projectId; // 관련 프로젝트 ID (선택적)
  final String? taskId; // 관련 작업 ID (선택적)
  final String? commentId; // 관련 코멘트 ID (선택적)
  final String title; // 알림 제목
  final String message; // 알림 메시지
  final bool isRead; // 읽음 여부
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

  /// JSON으로 변환
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

  /// JSON에서 Notification 객체 생성
  factory Notification.fromJson(Map<String, dynamic> json) {
    // API 응답은 snake_case, 로컬 저장은 camelCase 지원
    final userIdKey = json.containsKey('user_id') ? 'user_id' : 'userId';
    final projectIdKey = json.containsKey('project_id') ? 'project_id' : 'projectId';
    final taskIdKey = json.containsKey('task_id') ? 'task_id' : 'taskId';
    final commentIdKey = json.containsKey('comment_id') ? 'comment_id' : 'commentId';
    final isReadKey = json.containsKey('is_read') ? 'is_read' : 'isRead';
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';

    return Notification(
      id: json['id'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.taskAssigned,
      ),
      userId: json[userIdKey],
      projectId: json[projectIdKey],
      taskId: json[taskIdKey],
      commentId: json[commentIdKey],
      title: json['title'],
      message: json['message'],
      isRead: json[isReadKey] ?? false,
      createdAt: DateTime.parse(json[createdAtKey]),
    );
  }

  /// 알림을 수정한 복사본 생성
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

