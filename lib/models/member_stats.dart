import 'task.dart';

class MemberProjectInfo {
  final String id;
  final String name;
  final int color;

  MemberProjectInfo({
    required this.id,
    required this.name,
    required this.color,
  });

  factory MemberProjectInfo.fromJson(Map<String, dynamic> json) {
    return MemberProjectInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      color: (json['color'] as num?)?.toInt() ?? 0xFF2196F3,
    );
  }
}

class MemberTaskCounts {
  final int backlog;
  final int ready;
  final int inProgress;
  final int inReview;
  final int done;
  final int total;

  MemberTaskCounts({
    required this.backlog,
    required this.ready,
    required this.inProgress,
    required this.inReview,
    required this.done,
    required this.total,
  });

  factory MemberTaskCounts.fromJson(Map<String, dynamic> json) {
    return MemberTaskCounts(
      backlog: (json['backlog'] as num?)?.toInt() ?? 0,
      ready: (json['ready'] as num?)?.toInt() ?? 0,
      inProgress: (json['in_progress'] as num?)?.toInt() ?? 0,
      inReview: (json['in_review'] as num?)?.toInt() ?? 0,
      done: (json['done'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  int countOf(TaskStatus status) {
    switch (status) {
      case TaskStatus.backlog: return backlog;
      case TaskStatus.ready: return ready;
      case TaskStatus.inProgress: return inProgress;
      case TaskStatus.inReview: return inReview;
      case TaskStatus.done: return done;
    }
  }
}

class MemberActiveTask {
  final String id;
  final String title;
  final String projectName;
  final String priority;

  MemberActiveTask({
    required this.id,
    required this.title,
    required this.projectName,
    required this.priority,
  });

  factory MemberActiveTask.fromJson(Map<String, dynamic> json) {
    return MemberActiveTask(
      id: json['id'] as String,
      title: json['title'] as String,
      projectName: json['project_name'] as String? ?? '',
      priority: json['priority'] as String? ?? 'p2',
    );
  }

  TaskPriority get taskPriority =>
      TaskPriority.values.firstWhere(
        (e) => e.name == priority,
        orElse: () => TaskPriority.p2,
      );
}

class MemberAllTask {
  final String id;
  final String title;
  final String projectName;
  final String priority;
  final String status;
  final DateTime? endDate;

  MemberAllTask({
    required this.id,
    required this.title,
    required this.projectName,
    required this.priority,
    required this.status,
    this.endDate,
  });

  factory MemberAllTask.fromJson(Map<String, dynamic> json) {
    return MemberAllTask(
      id: json['id'] as String,
      title: json['title'] as String,
      projectName: json['project_name'] as String? ?? '',
      priority: json['priority'] as String? ?? 'p2',
      status: json['status'] as String? ?? 'backlog',
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
    );
  }

  TaskStatus get taskStatus => TaskStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => TaskStatus.backlog,
      );

  TaskPriority get taskPriority => TaskPriority.values.firstWhere(
        (e) => e.name == priority,
        orElse: () => TaskPriority.p2,
      );

  bool get isOverdue {
    if (endDate == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final endOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return endOnly.isBefore(todayOnly);
  }
}

class MemberTodayTask {
  final String id;
  final String title;
  final String projectName;
  final String priority;
  final String status;
  final DateTime? endDate;
  final DateTime? startDate;

  MemberTodayTask({
    required this.id,
    required this.title,
    required this.projectName,
    required this.priority,
    required this.status,
    this.endDate,
    this.startDate,
  });

  factory MemberTodayTask.fromJson(Map<String, dynamic> json) {
    return MemberTodayTask(
      id: json['id'] as String,
      title: json['title'] as String,
      projectName: json['project_name'] as String? ?? '',
      priority: json['priority'] as String? ?? 'p2',
      status: json['status'] as String? ?? 'inProgress',
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
    );
  }

  bool get isDone => status == 'done';

  TaskStatus get taskStatus => TaskStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => TaskStatus.inProgress,
      );

  TaskPriority get taskPriority => TaskPriority.values.firstWhere(
        (e) => e.name == priority,
        orElse: () => TaskPriority.p2,
      );

  bool get isOverdue {
    if (isDone) return false;
    if (endDate == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final endOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return endOnly.isBefore(todayOnly);
  }
}

class MemberRecentDone {
  final String id;
  final String title;
  final String projectName;
  final DateTime? updatedAt;

  MemberRecentDone({
    required this.id,
    required this.title,
    required this.projectName,
    this.updatedAt,
  });

  factory MemberRecentDone.fromJson(Map<String, dynamic> json) {
    return MemberRecentDone(
      id: json['id'] as String,
      title: json['title'] as String,
      projectName: json['project_name'] as String? ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class MemberStats {
  final String userId;
  final String username;
  final String? profileImageUrl;
  final String role;
  final List<MemberProjectInfo> projects;
  final MemberTaskCounts taskCounts;
  final List<MemberActiveTask> activeTasks;
  final List<MemberRecentDone> recentDone;
  final List<MemberTodayTask> todayTasks;
  final List<MemberAllTask> allTasks;

  MemberStats({
    required this.userId,
    required this.username,
    this.profileImageUrl,
    required this.role,
    required this.projects,
    required this.taskCounts,
    required this.activeTasks,
    required this.recentDone,
    this.todayTasks = const [],
    this.allTasks = const [],
  });

  bool get isOwner => role == 'owner';

  bool get hasActiveTasks => activeTasks.isNotEmpty;

  bool get hasTodayTasks => todayTasks.isNotEmpty;

  factory MemberStats.fromJson(Map<String, dynamic> json) {
    return MemberStats(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      role: json['role'] as String? ?? 'member',
      projects: (json['projects'] as List<dynamic>? ?? [])
          .map((e) => MemberProjectInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      taskCounts: MemberTaskCounts.fromJson(
          json['task_counts'] as Map<String, dynamic>? ?? {}),
      activeTasks: (json['active_tasks'] as List<dynamic>? ?? [])
          .map((e) => MemberActiveTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentDone: (json['recent_done'] as List<dynamic>? ?? [])
          .map((e) => MemberRecentDone.fromJson(e as Map<String, dynamic>))
          .toList(),
      todayTasks: (json['today_tasks'] as List<dynamic>? ?? [])
          .map((e) => MemberTodayTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      allTasks: (json['all_tasks'] as List<dynamic>? ?? [])
          .map((e) => MemberAllTask.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
