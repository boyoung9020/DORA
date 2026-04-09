import 'package:flutter/material.dart';
import '../../models/member_stats.dart';
import '../../models/task.dart';

class MemberStatCard extends StatelessWidget {
  final MemberStats member;
  final bool isSelected;
  final VoidCallback onTap;

  const MemberStatCard({
    super.key,
    required this.member,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inProgressCount = member.taskCounts.inProgress;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.6)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildAvatar(context),
                if (member.hasActiveTasks || member.hasTodayTasks)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: colorScheme.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.username,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (member.isOwner)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'owner',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildMiniStatusBar(context),
                  const SizedBox(height: 2),
                  Text(
                    inProgressCount > 0
                        ? '진행 중 $inProgressCount건 · 전체 ${member.taskCounts.total}건'
                        : '전체 ${member.taskCounts.total}건',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.chevron_right,
                  size: 16, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    if (member.profileImageUrl != null && member.profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(member.profileImageUrl!),
      );
    }
    final colors = [
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.orange.shade400,
      Colors.pink.shade400,
    ];
    final color = colors[member.username.codeUnitAt(0) % colors.length];
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        member.username.characters.first,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMiniStatusBar(BuildContext context) {
    final total = member.taskCounts.total;
    if (total == 0) {
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final segments = [
      (TaskStatus.done, member.taskCounts.done),
      (TaskStatus.inProgress, member.taskCounts.inProgress),
      (TaskStatus.inReview, member.taskCounts.inReview),
      (TaskStatus.ready, member.taskCounts.ready),
      (TaskStatus.backlog, member.taskCounts.backlog),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Row(
          children: segments.map((seg) {
            final count = seg.$2;
            if (count == 0) return const SizedBox.shrink();
            return Expanded(
              flex: count,
              child: Container(color: seg.$1.color),
            );
          }).toList(),
        ),
      ),
    );
  }
}
