import 'package:flutter/material.dart';

/// 알림 모델
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data; // 추가 데이터 (project_id, task_id 등)

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.other,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// 알림 타입
enum NotificationType {
  teamMemberAdded, // 팀원으로 추가됨
  taskAssigned, // 작업이 할당됨
  taskStatusChanged, // 할당된 태스크의 상태 변경
  commentAdded, // 코멘트 추가
  other, // 기타
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.teamMemberAdded:
        return '팀원 추가';
      case NotificationType.taskAssigned:
        return '작업 할당';
      case NotificationType.taskStatusChanged:
        return '상태 변경';
      case NotificationType.commentAdded:
        return '댓글 추가';
      case NotificationType.other:
        return '기타';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.teamMemberAdded:
        return Icons.person_add;
      case NotificationType.taskAssigned:
        return Icons.assignment;
      case NotificationType.taskStatusChanged:
        return Icons.change_circle;
      case NotificationType.commentAdded:
        return Icons.comment;
      case NotificationType.other:
        return Icons.notifications;
    }
  }
}

