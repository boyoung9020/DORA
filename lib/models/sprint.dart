import '../utils/date_utils.dart';

enum SprintStatus { planning, active, completed }

extension SprintStatusExtension on SprintStatus {
  String get displayName {
    switch (this) {
      case SprintStatus.planning:
        return 'Planning';
      case SprintStatus.active:
        return 'Active';
      case SprintStatus.completed:
        return 'Completed';
    }
  }
}

class Sprint {
  final String id;
  final String projectId;
  final String name;
  final String? goal;
  final DateTime? startDate;
  final DateTime? endDate;
  final SprintStatus status;
  final List<String> taskIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Sprint({
    required this.id,
    required this.projectId,
    required this.name,
    this.goal,
    this.startDate,
    this.endDate,
    required this.status,
    this.taskIds = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory Sprint.fromJson(Map<String, dynamic> json) {
    final projectIdKey = json.containsKey('project_id') ? 'project_id' : 'projectId';
    final startDateKey = json.containsKey('start_date') ? 'start_date' : 'startDate';
    final endDateKey = json.containsKey('end_date') ? 'end_date' : 'endDate';
    final taskIdsKey = json.containsKey('task_ids') ? 'task_ids' : 'taskIds';
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';
    final updatedAtKey = json.containsKey('updated_at') ? 'updated_at' : 'updatedAt';

    return Sprint(
      id: json['id'] as String,
      projectId: json[projectIdKey] as String,
      name: json['name'] as String,
      goal: json['goal'] as String?,
      startDate: parseUtcToLocalOrNull(json[startDateKey]),
      endDate: parseUtcToLocalOrNull(json[endDateKey]),
      status: SprintStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SprintStatus.planning,
      ),
      taskIds: (json[taskIdsKey] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      createdAt: parseUtcToLocal(json[createdAtKey]),
      updatedAt: parseUtcToLocalOrNull(json[updatedAtKey]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'goal': goal,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status.name,
      'task_ids': taskIds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Sprint copyWith({
    String? id,
    String? projectId,
    String? name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
    SprintStatus? status,
    List<String>? taskIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sprint(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      taskIds: taskIds ?? this.taskIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
