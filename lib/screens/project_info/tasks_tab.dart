import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/glass_container.dart';

class TasksTab extends StatelessWidget {
  final List<Task> allTasks;
  final List<User> teamMembers;

  const TasksTab({
    super.key,
    required this.allTasks,
    required this.teamMembers,
  });

  String _assigneeNames(Task task) {
    final names = <String>[];
    for (final id in task.assignedMemberIds) {
      final m = teamMembers.where((u) => u.id == id).firstOrNull;
      if (m != null) names.add(m.username);
    }
    return names.join(', ');
  }

  static Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.done: return Colors.green;
      case TaskStatus.inReview: return Colors.purple;
      case TaskStatus.inProgress: return Colors.orange;
      case TaskStatus.ready: return Colors.blue.shade300;
      case TaskStatus.backlog: return Colors.grey;
    }
  }

  static String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.done: return '완료';
      case TaskStatus.inReview: return '검토 중';
      case TaskStatus.inProgress: return '진행 중';
      case TaskStatus.ready: return '준비됨';
      case TaskStatus.backlog: return '백로그';
    }
  }

  static Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.p0: return Colors.red;
      case TaskPriority.p1: return Colors.orange;
      case TaskPriority.p2: return Colors.blue;
      case TaskPriority.p3: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        blur: 20,
        gradientColors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.8),
        ],
        shadowBlurRadius: 8,
        shadowOffset: const Offset(0, 2),
        child: Column(
          children: [
            // 검색 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color: colorScheme.onSurface.withValues(alpha: 0.4)),
                        hintText: '작업 검색...',
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.4)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: colorScheme.outlineVariant),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            // 테이블 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Row(
                children: [
                  _header('작업명', flex: 3, colorScheme: colorScheme),
                  _header('상태', flex: 1, colorScheme: colorScheme),
                  _header('우선순위', flex: 1, colorScheme: colorScheme),
                  _header('담당자', flex: 1, colorScheme: colorScheme),
                  _header('마감일', flex: 1, colorScheme: colorScheme),
                ],
              ),
            ),
            // 테이블 본문
            if (allTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text('작업이 없습니다.',
                    style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5))),
              )
            else
              ...allTasks.map((task) => _TaskRow(
                    task: task,
                    assigneeNames: _assigneeNames(task),
                  )),
          ],
        ),
      ),
    );
  }

  static Widget _header(String label,
      {required int flex, required ColorScheme colorScheme}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 0.5)),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  final String assigneeNames;

  const _TaskRow({required this.task, required this.assigneeNames});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sc = TasksTab._statusColor(task.status);
    final sl = TasksTab._statusLabel(task.status);
    final pc = TasksTab._priorityColor(task.priority);
    final dateStr = task.endDate != null
        ? '${task.endDate!.year}-${task.endDate!.month.toString().padLeft(2, '0')}-${task.endDate!.day.toString().padLeft(2, '0')}'
        : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(task.title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(sl,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: sc)),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(task.priority.displayName,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: pc)),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(assigneeNames.isEmpty ? '-' : assigneeNames,
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: Text(dateStr,
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.7))),
          ),
        ],
      ),
    );
  }
}
