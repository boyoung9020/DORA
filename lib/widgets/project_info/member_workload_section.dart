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
            LayoutBuilder(builder: (ctx, c) {
              final w = c.maxWidth;
              final cols = w < 600 ? 1 : (w < 1000 ? 2 : 3);
              const gap = 12.0;
              final cardW = (w - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: teamMembers
                    .map((m) => SizedBox(
                          width: cardW,
                          child: _MemberWorkloadCard(
                            member: m,
                            tasks: tasksByMember[m.id] ?? const [],
                          ),
                        ))
                    .toList(),
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

// ── 팀원 개별 카드 (컴팩트: 헤더 + 진행률 바 + inline 카운트) ──
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(colorScheme, isCreator, total),
          const SizedBox(height: 8),
          _buildProgress(done, inReview, inProgress, ready, backlog,
              donePercent, total, colorScheme),
          const SizedBox(height: 6),
          _buildCounts(
              colorScheme, inProgress, inReview, ready, backlog, done, total),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isCreator, int total) => Row(
        children: [
          CircleAvatar(
            radius: 12,
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
                        fontSize: 11))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(member.username,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (isCreator) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
          const SizedBox(width: 6),
          _countBadge('$total건', cs.primaryContainer, cs.onPrimaryContainer),
        ],
      );

  Widget _buildProgress(int done, int inReview, int inProgress, int ready,
      int backlog, double donePercent, int total, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: total == 0
                  ? Container(color: cs.outlineVariant.withValues(alpha: 0.3))
                  : Row(
                      children: [
                        if (done > 0)
                          Flexible(
                              flex: done,
                              child: Container(color: Colors.green)),
                        if (inReview > 0)
                          Flexible(
                              flex: inReview,
                              child: Container(color: Colors.purple)),
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
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            total == 0 ? '―' : '${donePercent.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 11,
                color: total == 0
                    ? cs.onSurface.withValues(alpha: 0.4)
                    : Colors.green.shade600,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildCounts(ColorScheme cs, int inProgress, int inReview, int ready,
      int backlog, int done, int total) {
    if (total == 0) {
      return Text('할당된 작업 없음',
          style: TextStyle(
              fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (inProgress > 0) _statusLabel('진행', inProgress, Colors.orange),
        if (inReview > 0) _statusLabel('검토', inReview, Colors.purple),
        if (ready > 0) _statusLabel('준비', ready, Colors.blue.shade300),
        if (backlog > 0) _statusLabel('백로그', backlog, Colors.grey),
        if (done > 0) _statusLabel('완료', done, Colors.green),
      ],
    );
  }

  static Widget _countBadge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(10)),
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
