import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/glass_container.dart';

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

    final urgentTasks = allTasks
        .where((t) => t.status != TaskStatus.done)
        .toList()
      ..sort((a, b) {
        final aDate = a.endDate ?? DateTime(2099);
        final bDate = b.endDate ?? DateTime(2099);
        return aDate.compareTo(bDate);
      });
    final displayTasks = urgentTasks.take(5).toList();

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
          Text('프로젝트 설명',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
            project.description ?? '설명이 없습니다.',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: project.color.withValues(alpha: 0.9),
                height: 1.5),
          ),
          const SizedBox(height: 20),
          Text('마감 임박 작업',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 10),
          if (displayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('진행 중인 작업이 없습니다.',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5))),
            )
          else
            ...displayTasks.map((task) {
              final assigneeName = _getAssigneeName(task);
              final now = DateTime.now();
              final isOverdue = task.endDate != null &&
                  task.endDate!.isBefore(now);
              final dateStr = task.endDate != null
                  ? '${task.endDate!.year}-${task.endDate!.month.toString().padLeft(2, '0')}-${task.endDate!.day.toString().padLeft(2, '0')}'
                  : '미정';

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: isOverdue
                            ? Colors.red.shade500
                            : Colors.orange.shade400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(task.title,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (assigneeName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(assigneeName,
                            style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55))),
                      ],
                      const SizedBox(width: 12),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOverdue
                                  ? Colors.red.shade600
                                  : Colors.red.shade400)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
