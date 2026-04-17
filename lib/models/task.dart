import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

/// ?곹깭 蹂寃??덉뒪?좊━
class StatusChangeHistory {
  final TaskStatus fromStatus;
  final TaskStatus toStatus;
  final String userId;
  final String username;
  final DateTime changedAt;

  StatusChangeHistory({
    required this.fromStatus,
    required this.toStatus,
    required this.userId,
    required this.username,
    required this.changedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromStatus': fromStatus.name,
      'toStatus': toStatus.name,
      'userId': userId,
      'username': username,
      'changedAt': changedAt.toIso8601String(),
    };
  }

  factory StatusChangeHistory.fromJson(Map<String, dynamic> json) {
    return StatusChangeHistory(
      fromStatus: TaskStatus.values.firstWhere(
        (e) => e.name == json['fromStatus'],
        orElse: () => TaskStatus.backlog,
      ),
      toStatus: TaskStatus.values.firstWhere(
        (e) => e.name == json['toStatus'],
        orElse: () => TaskStatus.backlog,
      ),
      userId: json['userId'],
      username: json['username'],
      changedAt: parseUtcToLocal(json['changedAt']),
    );
  }
}

/// ????좊떦 ?덉뒪?좊━
class AssignmentHistory {
  final String assignedUserId;
  final String assignedUsername;
  final String assignedBy;
  final String assignedByUsername;
  final DateTime assignedAt;

  AssignmentHistory({
    required this.assignedUserId,
    required this.assignedUsername,
    required this.assignedBy,
    required this.assignedByUsername,
    required this.assignedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'assignedUserId': assignedUserId,
      'assignedUsername': assignedUsername,
      'assignedBy': assignedBy,
      'assignedByUsername': assignedByUsername,
      'assignedAt': assignedAt.toIso8601String(),
    };
  }

  factory AssignmentHistory.fromJson(Map<String, dynamic> json) {
    return AssignmentHistory(
      assignedUserId: json['assignedUserId'],
      assignedUsername: json['assignedUsername'],
      assignedBy: json['assignedBy'],
      assignedByUsername: json['assignedByUsername'],
      assignedAt: parseUtcToLocal(json['assignedAt']),
    );
  }
}

/// 以묒슂??蹂寃??덉뒪?좊━
class PriorityChangeHistory {
  final TaskPriority fromPriority;
  final TaskPriority toPriority;
  final String userId;
  final String username;
  final DateTime changedAt;

  PriorityChangeHistory({
    required this.fromPriority,
    required this.toPriority,
    required this.userId,
    required this.username,
    required this.changedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromPriority': fromPriority.name,
      'toPriority': toPriority.name,
      'userId': userId,
      'username': username,
      'changedAt': changedAt.toIso8601String(),
    };
  }

  factory PriorityChangeHistory.fromJson(Map<String, dynamic> json) {
    return PriorityChangeHistory(
      fromPriority: TaskPriority.values.firstWhere(
        (e) => e.name == json['fromPriority'],
        orElse: () => TaskPriority.p2,
      ),
      toPriority: TaskPriority.values.firstWhere(
        (e) => e.name == json['toPriority'],
        orElse: () => TaskPriority.p2,
      ),
      userId: json['userId'],
      username: json['username'],
      changedAt: parseUtcToLocal(json['changedAt']),
    );
  }
}

/// ?쒖뒪??紐⑤뜽 ?대옒??
/// 
/// 移몃컲 蹂대뱶??媛?移대뱶瑜??섑??대뒗 ?곗씠??紐⑤뜽?낅땲??
/// - id: 怨좎쑀 ?앸퀎??
/// - title: ?쒖뒪???쒕ぉ
/// - description: ?쒖뒪???ㅻ챸
/// - status: ?쒖뒪???곹깭 (todo, inProgress, done)
/// - createdAt: ?앹꽦 ?쒓컙
/// - updatedAt: ?섏젙 ?쒓컙
/// - assignedMemberIds: ?좊떦??????ъ슜??ID 紐⑸줉
const _sentinel = Object();

class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final String projectId;
  final String? sprintId; // ?꾨줈?앺듃 ID 異붽?
  final DateTime? startDate; // ?쒖옉??
  final DateTime? endDate; // 醫낅즺??
  final String detail; // ?곸꽭 ?댁슜
  final List<String> detailImageUrls; // ?곸꽭 ?댁슜 ?대?吏 URL 諛곗뿴
  final List<String> assignedMemberIds; // ?좊떦??????ъ슜??ID 紐⑸줉
  final List<String> observerIds;
  final List<String> commentIds; // ?볤? ID 紐⑸줉
  final TaskPriority priority; // 以묒슂??
  final List<StatusChangeHistory> statusHistory; // ?곹깭 蹂寃??덉뒪?좊━
  final List<AssignmentHistory> assignmentHistory; // ?좊떦 ?덉뒪?좊━
  final List<PriorityChangeHistory> priorityHistory; // 以묒슂??蹂寃??덉뒪?좊━
  final List<Map<String, String>> documentLinks;
  final List<String> siteTags; // 사이트 태그
  final int displayOrder; // 移몃컲 蹂대뱶 ???쒖떆 ?쒖꽌
  final int? displayId; // 순차 ID (SERIAL)
  final String? creatorId; // 태스크 생성자 ID
  final String? parentTaskId; // 부모 태스크 ID (계층 구조)
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.status,
    required this.projectId,
    this.sprintId,
    this.startDate,
    this.endDate,
    this.detail = '',
    List<String>? detailImageUrls,
    List<String>? assignedMemberIds,
    List<String>? observerIds,
    List<String>? commentIds,
    TaskPriority? priority,
    List<StatusChangeHistory>? statusHistory,
    List<AssignmentHistory>? assignmentHistory,
    List<PriorityChangeHistory>? priorityHistory,
    List<Map<String, String>>? documentLinks,
    List<String>? siteTags,
    this.displayOrder = 0,
    this.displayId,
    this.creatorId,
    this.parentTaskId,
    required this.createdAt,
    required this.updatedAt,
  }) : detailImageUrls = detailImageUrls ?? [],
       assignedMemberIds = assignedMemberIds ?? [],
       observerIds = observerIds ?? [],
       commentIds = commentIds ?? [],
       priority = priority ?? TaskPriority.p2,
       statusHistory = statusHistory ?? [],
       assignmentHistory = assignmentHistory ?? [],
       priorityHistory = priorityHistory ?? [],
       documentLinks = documentLinks ?? [],
       siteTags = siteTags ?? [];

  /// JSON?쇰줈 蹂??(??μ슜)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'projectId': projectId,
      'sprint_id': sprintId,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'detail': detail,
      'detail_image_urls': detailImageUrls,
      'assignedMemberIds': assignedMemberIds,
      'observer_ids': observerIds,
      'commentIds': commentIds,
      'priority': priority.name,
      'statusHistory': statusHistory.map((h) => h.toJson()).toList(),
      'assignmentHistory': assignmentHistory.map((h) => h.toJson()).toList(),
      'priorityHistory': priorityHistory.map((h) => h.toJson()).toList(),
      'document_links': documentLinks,
      'site_tags': siteTags,
      'display_order': displayOrder,
      'creator_id': creatorId,
      'parent_task_id': parentTaskId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// JSON?먯꽌 Task 媛앹껜 ?앹꽦
  factory Task.fromJson(Map<String, dynamic> json) {
    // API ?묐떟? snake_case, 濡쒖뺄 ??μ? camelCase 吏??
    String getKey(String camelKey, String snakeKey) {
      return json.containsKey(snakeKey) ? snakeKey : camelKey;
    }
    
    // assigned_member_ids ?먮뒗 assignedMemberIds 泥섎━
    List<String> assignedMemberIds = [];
    final assignedKey = getKey('assignedMemberIds', 'assigned_member_ids');
    if (json.containsKey(assignedKey) && json[assignedKey] != null) {
      try {
        final memberIds = json[assignedKey];
        if (memberIds is List) {
          assignedMemberIds = memberIds.map((e) => e.toString()).toList();
        }
      } catch (e) {
        assignedMemberIds = [];
      }
    }

    // observer_ids 파싱
    List<String> observerIds = [];
    final observerKey = getKey('observerIds', 'observer_ids');
    if (json.containsKey(observerKey) && json[observerKey] != null) {
      try {
        final ids = json[observerKey];
        if (ids is List) {
          observerIds = ids.map((e) => e.toString()).toList();
        }
      } catch (e) {
        observerIds = [];
      }
    }

    // comment_ids ?먮뒗 commentIds 泥섎━
    List<String> commentIds = [];
    final commentKey = getKey('commentIds', 'comment_ids');
    if (json.containsKey(commentKey) && json[commentKey] != null) {
      try {
        final ids = json[commentKey];
        if (ids is List) {
          commentIds = ids.map((e) => e.toString()).toList();
        }
      } catch (e) {
        commentIds = [];
      }
    }
    
    // status_history ?먮뒗 statusHistory 泥섎━
    List<StatusChangeHistory> statusHistory = [];
    final statusHistoryKey = getKey('statusHistory', 'status_history');
    if (json.containsKey(statusHistoryKey) && json[statusHistoryKey] != null) {
      try {
        final history = json[statusHistoryKey];
        if (history is List) {
          statusHistory = history.map((e) => StatusChangeHistory.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        statusHistory = [];
      }
    }
    
    // assignment_history ?먮뒗 assignmentHistory 泥섎━
    List<AssignmentHistory> assignmentHistory = [];
    final assignmentHistoryKey = getKey('assignmentHistory', 'assignment_history');
    if (json.containsKey(assignmentHistoryKey) && json[assignmentHistoryKey] != null) {
      try {
        final history = json[assignmentHistoryKey];
        if (history is List) {
          assignmentHistory = history.map((e) => AssignmentHistory.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        assignmentHistory = [];
      }
    }
    
    // priority_history ?먮뒗 priorityHistory 泥섎━
    List<PriorityChangeHistory> priorityHistory = [];
    final priorityHistoryKey = getKey('priorityHistory', 'priority_history');
    if (json.containsKey(priorityHistoryKey) && json[priorityHistoryKey] != null) {
      try {
        final history = json[priorityHistoryKey];
        if (history is List) {
          priorityHistory = history.map((e) => PriorityChangeHistory.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        priorityHistory = [];
      }
    }
    
    // project_id ?먮뒗 projectId 泥섎━
    // document_links 파싱
    List<Map<String, String>> documentLinks = [];
    final docLinksKey = getKey('documentLinks', 'document_links');
    if (json.containsKey(docLinksKey) && json[docLinksKey] != null) {
      try {
        final links = json[docLinksKey];
        if (links is List) {
          documentLinks = links
              .whereType<Map>()
              .map((e) => Map<String, String>.from(
                    e.map((k, v) => MapEntry(k.toString(), v.toString())),
                  ))
              .toList();
        }
      } catch (e) {
        documentLinks = [];
      }
    }

    final projectIdKey = getKey('projectId', 'project_id');
    final projectId = json[projectIdKey] ?? '';
    final sprintIdKey = getKey('sprintId', 'sprint_id');
    final sprintId = json[sprintIdKey] as String?;
    
    // start_date ?먮뒗 startDate 泥섎━
    final startDateKey = getKey('startDate', 'start_date');
    final startDate = parseDateOnly(json[startDateKey] as String?);

    // end_date ?먮뒗 endDate 泥섎━
    final endDateKey = getKey('endDate', 'end_date');
    final endDate = parseDateOnly(json[endDateKey] as String?);

    // created_at ?먮뒗 createdAt 泥섎━
    final createdAtKey = getKey('createdAt', 'created_at');
    final createdAt = parseUtcToLocal(json[createdAtKey]);

    // updated_at ?먮뒗 updatedAt 泥섎━
    final updatedAtKey = getKey('updatedAt', 'updated_at');
    final updatedAt = parseUtcToLocal(json[updatedAtKey]);
    
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.backlog,
      ),
      projectId: projectId,
      sprintId: sprintId,
      startDate: startDate,
      endDate: endDate,
      detail: json['detail'] ?? '',
      detailImageUrls: json.containsKey('detail_image_urls') && json['detail_image_urls'] != null
          ? List<String>.from(json['detail_image_urls'])
          : [],
      assignedMemberIds: assignedMemberIds,
      observerIds: observerIds,
      commentIds: commentIds,
      priority: json.containsKey('priority') && json['priority'] != null
          ? TaskPriority.values.firstWhere(
              (e) => e.name == json['priority'],
              orElse: () => TaskPriority.p2,
            )
          : TaskPriority.p2,
      statusHistory: statusHistory,
      assignmentHistory: assignmentHistory,
      priorityHistory: priorityHistory,
      documentLinks: documentLinks,
      siteTags: json.containsKey('site_tags') && json['site_tags'] != null
          ? List<String>.from(json['site_tags'])
          : [],
      displayOrder: json['display_order'] ?? 0,
      displayId: json['display_id'] as int?,
      creatorId: json['creator_id'] as String?,
      parentTaskId: json['parent_task_id'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// ?곹깭瑜?蹂寃쏀븳 蹂듭궗蹂??앹꽦
  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    String? projectId,
    String? sprintId,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    String? detail,
    List<String>? detailImageUrls,
    List<String>? assignedMemberIds,
    List<String>? observerIds,
    List<String>? commentIds,
    TaskPriority? priority,
    List<StatusChangeHistory>? statusHistory,
    List<AssignmentHistory>? assignmentHistory,
    List<PriorityChangeHistory>? priorityHistory,
    List<Map<String, String>>? documentLinks,
    List<String>? siteTags,
    int? displayOrder,
    int? displayId,
    String? creatorId,
    String? parentTaskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      sprintId: sprintId ?? this.sprintId,
      startDate: startDate == _sentinel ? this.startDate : startDate as DateTime?,
      endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
      detail: detail ?? this.detail,
      detailImageUrls: detailImageUrls ?? this.detailImageUrls,
      assignedMemberIds: assignedMemberIds ?? this.assignedMemberIds,
      observerIds: observerIds ?? this.observerIds,
      commentIds: commentIds ?? this.commentIds,
      priority: priority ?? this.priority,
      statusHistory: statusHistory ?? this.statusHistory,
      assignmentHistory: assignmentHistory ?? this.assignmentHistory,
      priorityHistory: priorityHistory ?? this.priorityHistory,
      documentLinks: documentLinks ?? this.documentLinks,
      siteTags: siteTags ?? this.siteTags,
      displayOrder: displayOrder ?? this.displayOrder,
      displayId: displayId ?? this.displayId,
      creatorId: creatorId ?? this.creatorId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ?쒖뒪???곹깭 ?닿굅??
enum TaskStatus {
  backlog,      // 諛깅줈洹?
  ready,         // 以鍮꾨맖
  inProgress,    // 吏꾪뻾 以?
  inReview,      // 寃??以?
  done,          // ?꾨즺
}

/// ?곹깭蹂??쒓? ?대쫫
extension TaskStatusExtension on TaskStatus {
  String get displayName {
    switch (this) {
      case TaskStatus.backlog:
        return '백로그';
      case TaskStatus.ready:
        return '준비됨';
      case TaskStatus.inProgress:
        return '진행 중';
      case TaskStatus.inReview:
        return '검토 중';
      case TaskStatus.done:
        return '완료';
    }
  }

  /// ?곹깭蹂??됱긽
  Color get color {
    switch (this) {
      case TaskStatus.backlog:
        return const Color(0xFF9E9E9E); // ?뚯깋
      case TaskStatus.ready:
        return const Color(0xFF2196F3); // ?뚮???
      case TaskStatus.inProgress:
        return const Color(0xFFFF9800); // 二쇳솴??
      case TaskStatus.inReview:
        return const Color(0xFF9C27B0); // 蹂대씪??
      case TaskStatus.done:
        return const Color(0xFF4CAF50); // 珥덈줉??
    }
  }

  /// ?곹깭蹂??ㅻ챸
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

/// ?쒖뒪??以묒슂???닿굅??
enum TaskPriority {
  p0,  // 理쒖슦??
  p1,  // ?믪쓬
  p2,  // 蹂댄넻
  p3,  // ??쓬
}

/// 以묒슂?꾨퀎 ?뺤옣
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

  /// 以묒슂?꾨퀎 ?됱긽
  Color get color {
    switch (this) {
      case TaskPriority.p0:
        return const Color(0xFFE53935); // 鍮④컙??(理쒖슦??
      case TaskPriority.p1:
        return const Color(0xFFFF9800); // 二쇳솴??(?믪쓬)
      case TaskPriority.p2:
        return const Color(0xFF2196F3); // ?뚮???(蹂댄넻)
      case TaskPriority.p3:
        return const Color(0xFF9E9E9E); // ?뚯깋 (??쓬)
    }
  }

  /// 以묒슂?꾨퀎 ?ㅻ챸
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


