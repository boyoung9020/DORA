import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/project_provider.dart';
import '../../utils/avatar_color.dart';
import '../../widgets/glass_container.dart';

class MemberWorkloadSection extends StatelessWidget {
  final List<User> teamMembers;
  final bool isLoading;
  final List<Task> allTasks;

  const MemberWorkloadSection({
    super.key,
    required this.teamMembers,
    required this.isLoading,
    required this.allTasks,
  });

  @override
  Widget build(BuildContext context) {
    if (teamMembers.isEmpty && !isLoading) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final Map<String, List<Task>> tasksByMember = {};
    for (final member in teamMembers) {
      tasksByMember[member.id] =
          allTasks.where((t) => t.assignedMemberIds.contains(member.id)).toList();
    }
    final unassignedTasks =
        allTasks.where((t) => t.assignedMemberIds.isEmpty).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(20),
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
          Text('팀원별 업무 현황',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            ...List.generate(teamMembers.length, (i) {
              final member = teamMembers[i];
              final memberTasks = tasksByMember[member.id] ?? [];
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: _MemberWorkloadCard(
                  member: member,
                  tasks: memberTasks,
                ),
              );
            }),
            if (unassignedTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              _UnassignedCard(tasks: unassignedTasks),
            ],
          ],
        ],
      ),
    );
  }
}

// ── 팀원 개별 카드 ──
class _MemberWorkloadCard extends StatelessWidget {
  final User member;
  final List<Task> tasks;

  const _MemberWorkloadCard({required this.member, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final project = context.read<ProjectProvider>().currentProject;
    final isCreator = project?.creatorId == member.id;

    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    final inProgress =
        tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final inReview = tasks.where((t) => t.status == TaskStatus.inReview).length;
    final ready = tasks.where((t) => t.status == TaskStatus.ready).length;
    final backlog = tasks.where((t) => t.status == TaskStatus.backlog).length;
    final total = tasks.length;
    final donePercent = total > 0 ? (done / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AvatarColor.getColorForUser(member.username),
                backgroundImage: member.profileImageUrl != null
                    ? NetworkImage(member.profileImageUrl!)
                    : null,
                child: member.profileImageUrl == null
                    ? Text(
                        member.username.isNotEmpty
                            ? member.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 10),
              Text(member.username,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface)),
              if (isCreator) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('PM',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800)),
                ),
              ],
              const Spacer(),
              _countBadge('$total건', colorScheme.primaryContainer,
                  colorScheme.onPrimaryContainer),
              const SizedBox(width: 6),
              if (total > 0)
                Text('${donePercent.toStringAsFixed(0)}% 완료',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    if (done > 0)
                      Flexible(flex: done, child: Container(color: Colors.green)),
                    if (inReview > 0)
                      Flexible(
                          flex: inReview, child: Container(color: Colors.purple)),
                    if (inProgress > 0)
                      Flexible(
                          flex: inProgress,
                          child: Container(color: Colors.orange)),
                    if (ready > 0)
                      Flexible(
                          flex: ready,
                          child: Container(color: Colors.blue.shade300)),
                    if (backlog > 0)
                      Flexible(
                          flex: backlog,
                          child: Container(color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (inProgress > 0)
                  _statusLabel('진행 중', inProgress, Colors.orange),
                if (inReview > 0)
                  _statusLabel('검토', inReview, Colors.purple),
                if (ready > 0)
                  _statusLabel('준비', ready, Colors.blue.shade300),
                if (backlog > 0) _statusLabel('백로그', backlog, Colors.grey),
                if (done > 0) _statusLabel('완료', done, Colors.green),
              ],
            ),
            const SizedBox(height: 10),
            ..._activeTasks(tasks, colorScheme),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('할당된 작업 없음',
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.4))),
            ),
        ],
      ),
    );
  }

  List<Widget> _activeTasks(List<Task> tasks, ColorScheme colorScheme) {
    final active = tasks
        .where((t) =>
            t.status == TaskStatus.inProgress ||
            t.status == TaskStatus.inReview ||
            t.status == TaskStatus.ready)
        .toList()
      ..sort((a, b) {
        const order = {
          TaskStatus.inProgress: 0,
          TaskStatus.inReview: 1,
          TaskStatus.ready: 2,
        };
        final cmp = (order[a.status] ?? 3).compareTo(order[b.status] ?? 3);
        return cmp != 0 ? cmp : a.priority.index.compareTo(b.priority.index);
      });

    if (active.isEmpty) return [];
    final display = active.take(5).toList();

    return [
      Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
      const SizedBox(height: 8),
      ...display.map((task) {
        final sc = _statusColor(task.status);
        final pc = _priorityColor(task.priority);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: pc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(task.priority.name.toUpperCase(),
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold, color: pc)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(task.title,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(_statusLabel2(task.status),
                  style: TextStyle(
                      fontSize: 10, color: sc, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }),
      if (active.length > 5)
        Text('외 ${active.length - 5}건',
            style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.4))),
    ];
  }

  static Widget _countBadge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
      );

  static Widget _statusLabel(String label, int count, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$label $count',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      );

  static Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.done: return Colors.green;
      case TaskStatus.inReview: return Colors.purple;
      case TaskStatus.inProgress: return Colors.orange;
      case TaskStatus.ready: return Colors.blue.shade300;
      case TaskStatus.backlog: return Colors.grey;
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

  static String _statusLabel2(TaskStatus s) {
    switch (s) {
      case TaskStatus.done: return '완료';
      case TaskStatus.inReview: return '검토 중';
      case TaskStatus.inProgress: return '진행 중';
      case TaskStatus.ready: return '준비됨';
      case TaskStatus.backlog: return '백로그';
    }
  }
}

// ── 미할당 카드 ──
class _UnassignedCard extends StatelessWidget {
  final List<Task> tasks;
  const _UnassignedCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = tasks.length;
    final active = tasks
        .where((t) =>
            t.status == TaskStatus.inProgress ||
            t.status == TaskStatus.inReview)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_off_outlined, size: 20, color: Colors.orange.shade400),
          const SizedBox(width: 10),
          Text('미할당',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10)),
            child: Text('$total건',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800)),
          ),
          const SizedBox(width: 8),
          if (active > 0)
            Text('$active건 진행 중',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade600)),
        ],
      ),
    );
  }
}
