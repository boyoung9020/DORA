/// 체크리스트 항목 모델
class ChecklistItem {
  final String id;
  final String checklistId;
  final String taskId;
  final String content;
  final bool isChecked;
  final String? assigneeId;
  final DateTime? dueDate;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChecklistItem({
    required this.id,
    required this.checklistId,
    required this.taskId,
    required this.content,
    required this.isChecked,
    this.assigneeId,
    this.dueDate,
    required this.displayOrder,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      checklistId: (json['checklist_id'] ?? json['checklistId']) as String,
      taskId: (json['task_id'] ?? json['taskId']) as String,
      content: json['content'] as String,
      isChecked: (json['is_checked'] ?? json['isChecked'] ?? false) as bool,
      assigneeId: (json['assignee_id'] ?? json['assigneeId']) as String?,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : json['dueDate'] != null
              ? DateTime.parse(json['dueDate'] as String)
              : null,
      displayOrder: (json['display_order'] ?? json['displayOrder'] ?? 0) as int,
      createdAt: DateTime.parse(
          (json['created_at'] ?? json['createdAt']) as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
    );
  }

  ChecklistItem copyWith({
    String? id,
    String? checklistId,
    String? taskId,
    String? content,
    bool? isChecked,
    String? assigneeId,
    DateTime? dueDate,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      checklistId: checklistId ?? this.checklistId,
      taskId: taskId ?? this.taskId,
      content: content ?? this.content,
      isChecked: isChecked ?? this.isChecked,
      assigneeId: assigneeId ?? this.assigneeId,
      dueDate: dueDate ?? this.dueDate,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 체크리스트 모델
class Checklist {
  final String id;
  final String taskId;
  final String title;
  final String createdBy;
  final List<ChecklistItem> items;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Checklist({
    required this.id,
    required this.taskId,
    required this.title,
    required this.createdBy,
    required this.items,
    required this.createdAt,
    this.updatedAt,
  });

  int get totalItems => items.length;
  int get checkedItems => items.where((i) => i.isChecked).length;
  double get progress => totalItems == 0 ? 0.0 : checkedItems / totalItems;

  factory Checklist.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return Checklist(
      id: json['id'] as String,
      taskId: (json['task_id'] ?? json['taskId']) as String,
      title: json['title'] as String? ?? 'Checklist',
      createdBy: (json['created_by'] ?? json['createdBy']) as String,
      items: rawItems
          .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(
          (json['created_at'] ?? json['createdAt']) as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
    );
  }

  Checklist copyWith({
    String? id,
    String? taskId,
    String? title,
    String? createdBy,
    List<ChecklistItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Checklist(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      createdBy: createdBy ?? this.createdBy,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
