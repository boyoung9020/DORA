import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/glass_container.dart';
import '../../screens/task_detail_screen.dart';

class DescriptionAndUrgentTasksCard extends StatelessWidget {
  final Project project;
  final List<Task> allTasks;
  final List<User> teamMembers;

  const DescriptionAndUrgentTasksCard({
    super.key,
    required this.project,
    required this.allTasks,
    required this.teamMembers,
  });

  String _getAssigneeName(Task task) {
    for (final id in task.assignedMemberIds) {
      final member = teamMembers.where((m) => m.id == id).firstOrNull;
      if (member != null) return member.username;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 마감 임박: end_date 가 있고 오늘로부터 2일 이내(오늘 포함) 마감 + 이미 지난 미완료
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final urgentCutoff = todayStart.add(const Duration(days: 3)); // 오늘+2 까지 포함 (exclusive)
    final urgentTasks = allTasks
        .where((t) =>
            t.status != TaskStatus.done &&
            t.endDate != null &&
            t.endDate!.isBefore(urgentCutoff))
        .toList()
      ..sort((a, b) => a.endDate!.compareTo(b.endDate!));
    final displayUrgent = urgentTasks.take(5).toList();

    final p0Tasks = allTasks
        .where((t) =>
            t.priority == TaskPriority.p0 && t.status != TaskStatus.done)
        .toList()
      ..sort((a, b) {
        const order = {
          TaskStatus.inProgress: 0,
          TaskStatus.inReview: 1,
          TaskStatus.ready: 2,
          TaskStatus.backlog: 3,
        };
        return (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
      });
    final displayP0 = p0Tasks.take(5).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 16,
      blur: 20,
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
      ],
      shadowBlurRadius: 8,
      shadowOffset: const Offset(0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 마감 임박 작업 + 최우선 작업 나란히
          IntrinsicHeight(
           child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 마감 임박 작업
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('마감 임박 작업',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface)),
                    const SizedBox(height: 10),
                    if (displayUrgent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('마감 임박 작업이 없습니다.',
                            style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      )
                    else
                      ...displayUrgent.map((task) {
                        final assigneeName = _getAssigneeName(task);
                        final now = DateTime.now();
                        final isOverdue =
                            task.endDate != null && task.endDate!.isBefore(now);
                        final dateStr = task.endDate != null
                            ? '${task.endDate!.year}-${task.endDate!.month.toString().padLeft(2, '0')}-${task.endDate!.day.toString().padLeft(2, '0')}'
                            : '미정';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              barrierColor: Colors.black.withValues(alpha: 0.2),
                              builder: (_) => TaskDetailScreen(task: task),
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? Colors.red.shade50.withValues(alpha: 0.6)
                                  : colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isOverdue
                                    ? Colors.red.shade200
                                    : colorScheme.outlineVariant
                                        .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isOverdue
                                      ? Icons.warning_amber_rounded
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: isOverdue
                                      ? Colors.red.shade500
                                      : Colors.orange.shade400,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(task.title,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (assigneeName.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(assigneeName,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.55))),
                                ],
                                const SizedBox(width: 8),
                                Text(dateStr,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isOverdue
                                            ? Colors.red.shade600
                                            : Colors.red.shade400)),
                              ],
                            ),
                          ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.black.withValues(alpha: 0.07),
              ),
              const SizedBox(width: 12),
              // ── 최우선 작업 (P0)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('최우선 작업',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('P0',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (displayP0.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('P0 작업이 없습니다.',
                            style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      )
                    else
                      ...displayP0.map((task) {
                        final assigneeName = _getAssigneeName(task);
                        final statusColor = _statusColor(task.status);
                        final statusLabel = _statusLabel(task.status);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              barrierColor: Colors.black.withValues(alpha: 0.2),
                              builder: (_) => TaskDetailScreen(task: task),
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(task.title,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: colorScheme.onSurface),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    if (assigneeName.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(assigneeName,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.55))),
                                    ],
                                    const SizedBox(width: 8),
                                    Text(statusLabel,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: statusColor)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    if (p0Tasks.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('외 ${p0Tasks.length - 5}건',
                            style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4))),
                      ),
                  ],
                ),
              ),
            ],
           ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.inProgress: return Colors.orange;
      case TaskStatus.inReview:   return Colors.purple;
      case TaskStatus.ready:      return Colors.blue.shade300;
      case TaskStatus.backlog:    return Colors.grey;
      case TaskStatus.done:       return Colors.green;
    }
  }

  static String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.inProgress: return '진행 중';
      case TaskStatus.inReview:   return '검토 중';
      case TaskStatus.ready:      return '준비됨';
      case TaskStatus.backlog:    return '백로그';
      case TaskStatus.done:       return '완료';
    }
  }
}
