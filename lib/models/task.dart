import 'package:flutter/material.dart';

/// 태스크 모델 클래스
/// 
/// 칸반 보드의 각 카드를 나타내는 데이터 모델입니다.
/// - id: 고유 식별자
/// - title: 태스크 제목
/// - description: 태스크 설명
/// - status: 태스크 상태 (todo, inProgress, done)
/// - createdAt: 생성 시간
/// - updatedAt: 수정 시간
/// - assignedMemberIds: 할당된 팀원 사용자 ID 목록
class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final String projectId; // 프로젝트 ID 추가
  final DateTime? startDate; // 시작일
  final DateTime? endDate; // 종료일
  final String detail; // 상세 내용
  final List<String> assignedMemberIds; // 할당된 팀원 사용자 ID 목록
  final List<String> commentIds; // 댓글 ID 목록
  final TaskPriority priority; // 중요도
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.status,
    required this.projectId,
    this.startDate,
    this.endDate,
    this.detail = '',
    List<String>? assignedMemberIds,
    List<String>? commentIds,
    TaskPriority? priority,
    required this.createdAt,
    required this.updatedAt,
  }) : assignedMemberIds = assignedMemberIds ?? [],
       commentIds = commentIds ?? [],
       priority = priority ?? TaskPriority.p2;

  /// JSON으로 변환 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'projectId': projectId,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'detail': detail,
      'assignedMemberIds': assignedMemberIds,
      'commentIds': commentIds,
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// JSON에서 Task 객체 생성
  factory Task.fromJson(Map<String, dynamic> json) {
    // assignedMemberIds가 없거나 null인 경우 빈 리스트 반환
    List<String> assignedMemberIds = [];
    if (json.containsKey('assignedMemberIds') && json['assignedMemberIds'] != null) {
      try {
        final memberIds = json['assignedMemberIds'];
        if (memberIds is List) {
          assignedMemberIds = memberIds.map((e) => e.toString()).toList();
        }
      } catch (e) {
        assignedMemberIds = [];
      }
    }
    
    // commentIds가 없거나 null인 경우 빈 리스트 반환
    List<String> commentIds = [];
    if (json.containsKey('commentIds') && json['commentIds'] != null) {
      try {
        final ids = json['commentIds'];
        if (ids is List) {
          commentIds = ids.map((e) => e.toString()).toList();
        }
      } catch (e) {
        commentIds = [];
      }
    }
    
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.backlog,
      ),
      projectId: json['projectId'] ?? '',
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      detail: json['detail'] ?? '',
      assignedMemberIds: assignedMemberIds,
      commentIds: commentIds,
      priority: json.containsKey('priority') && json['priority'] != null
          ? TaskPriority.values.firstWhere(
              (e) => e.name == json['priority'],
              orElse: () => TaskPriority.p2,
            )
          : TaskPriority.p2,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  /// 상태를 변경한 복사본 생성
  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    String? projectId,
    DateTime? startDate,
    DateTime? endDate,
    String? detail,
    List<String>? assignedMemberIds,
    List<String>? commentIds,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      detail: detail ?? this.detail,
      assignedMemberIds: assignedMemberIds ?? this.assignedMemberIds,
      commentIds: commentIds ?? this.commentIds,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 태스크 상태 열거형
enum TaskStatus {
  backlog,      // 백로그
  ready,         // 준비됨
  inProgress,    // 진행 중
  inReview,      // 검토 중
  done,          // 완료
}

/// 상태별 한글 이름
extension TaskStatusExtension on TaskStatus {
  String get displayName {
    switch (this) {
      case TaskStatus.backlog:
        return 'Backlog';
      case TaskStatus.ready:
        return 'Ready';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.inReview:
        return 'In Review';
      case TaskStatus.done:
        return 'Done';
    }
  }

  /// 상태별 색상
  Color get color {
    switch (this) {
      case TaskStatus.backlog:
        return const Color(0xFF9E9E9E); // 회색
      case TaskStatus.ready:
        return const Color(0xFF2196F3); // 파란색
      case TaskStatus.inProgress:
        return const Color(0xFFFF9800); // 주황색
      case TaskStatus.inReview:
        return const Color(0xFF9C27B0); // 보라색
      case TaskStatus.done:
        return const Color(0xFF4CAF50); // 초록색
    }
  }

  /// 상태별 설명
  String get description {
    switch (this) {
      case TaskStatus.backlog:
        return 'This item hasn\'t been started';
      case TaskStatus.ready:
        return 'This is ready to be picked up';
      case TaskStatus.inProgress:
        return 'This is actively being worked on';
      case TaskStatus.inReview:
        return 'This item is in review';
      case TaskStatus.done:
        return 'This has been completed';
    }
  }
}

/// 태스크 중요도 열거형
enum TaskPriority {
  p0,  // 최우선
  p1,  // 높음
  p2,  // 보통
  p3,  // 낮음
}

/// 중요도별 확장
extension TaskPriorityExtension on TaskPriority {
  String get displayName {
    switch (this) {
      case TaskPriority.p0:
        return 'P0';
      case TaskPriority.p1:
        return 'P1';
      case TaskPriority.p2:
        return 'P2';
      case TaskPriority.p3:
        return 'P3';
    }
  }

  /// 중요도별 색상
  Color get color {
    switch (this) {
      case TaskPriority.p0:
        return const Color(0xFFE53935); // 빨간색 (최우선)
      case TaskPriority.p1:
        return const Color(0xFFFF9800); // 주황색 (높음)
      case TaskPriority.p2:
        return const Color(0xFF2196F3); // 파란색 (보통)
      case TaskPriority.p3:
        return const Color(0xFF9E9E9E); // 회색 (낮음)
    }
  }

  /// 중요도별 설명
  String get description {
    switch (this) {
      case TaskPriority.p0:
        return '최우선';
      case TaskPriority.p1:
        return '높음';
      case TaskPriority.p2:
        return '보통';
      case TaskPriority.p3:
        return '낮음';
    }
  }
}

