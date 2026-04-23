import 'package:flutter/material.dart';
import '../../models/member_stats.dart';
import '../../models/task.dart';
import '../../utils/avatar_color.dart';

class MemberStatDetail extends StatefulWidget {
  final MemberStats member;

  const MemberStatDetail({super.key, required this.member});

  @override
  State<MemberStatDetail> createState() => _MemberStatDetailState();
}

class _MemberStatDetailState extends State<MemberStatDetail> {
  String _todoFilter = 'all'; // all | p0 | p1 | p2 | p3

  MemberStats get member => widget.member;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeader(context),
          const SizedBox(height: 12),
          _buildStatusChips(context),
          const SizedBox(height: 12),
          _buildMainGrid(context),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: _buildTodoSection(context),
          ),
        ],
      ),
    );
  }

  // ── 1. 컴팩트 헤더: 아바타 + 이름 + 프로젝트 태그 한 줄 ──────────────

  Widget _buildCompactHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAvatar(radius: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(member.username,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                if (member.isOwner) ...[
                  const SizedBox(width: 6),
                  _badge('owner', Colors.amber.shade700,
                      Colors.amber.shade100),
                ],
                const SizedBox(width: 8),
                Text('총 ${member.taskCounts.total}개',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.45))),
              ],
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: member.projects.map((p) {
                final c = Color(p.color);
                return Container(
                  margin: const EdgeInsets.only(right: 5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: c.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Text(p.name,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: c.withValues(alpha: 0.9))),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── 2. 상태 숫자 칩 가로 나열 ────────────────────────────────────────

  Widget _buildStatusChips(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final counts = member.taskCounts;
    final total = counts.total;

    final segments = [
      (TaskStatus.backlog, counts.backlog),
      (TaskStatus.ready, counts.ready),
      (TaskStatus.inProgress, counts.inProgress),
      (TaskStatus.inReview, counts.inReview),
      (TaskStatus.done, counts.done),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // 상태 칩들
          ...segments.map((seg) => Expanded(
                child: Column(
                  children: [
                    Text(
                      '${seg.$2}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: seg.$2 > 0
                            ? seg.$1.color
                            : colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      seg.$1.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )),
          // 세로 구분선 + 진행률
          Container(
              width: 1,
              height: 32,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              margin: const EdgeInsets.symmetric(horizontal: 10)),
          Column(
            children: [
              Text(
                total == 0
                    ? '0%'
                    : '${((counts.done / total) * 100).round()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 2),
              Text('완료율',
                  style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. 메인 2컬럼 그리드: 오늘 일정 | 진행중 + 최근완료 ──────────────
  // 각 카드 고정 높이 — 유저마다 데이터 양이 달라도 위치가 고정됨
  static const double _todayCardHeight = 220;
  static const double _activeCardHeight = 100;
  static const double _doneCardHeight = 112;

  Widget _buildMainGrid(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 오늘 일정 (고정 높이)
        Expanded(
          child: SizedBox(
            height: _todayCardHeight,
            child: _buildTodayCard(context),
          ),
        ),
        const SizedBox(width: 10),
        // 오른쪽: 진행 중 + 최근 완료 (각각 고정 높이)
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: _activeCardHeight,
                child: _buildActiveCard(context),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: _doneCardHeight,
                child: _buildRecentDoneCard(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _card(
      context,
      icon: Icons.today,
      iconColor: const Color(0xFF5C6BC0),
      title: '오늘 일정',
      count: member.todayTasks.length,
      child: member.todayTasks.isEmpty
          ? _emptyText(context, '오늘 예정 없음')
          : Column(
              children: member.todayTasks.map((t) {
                final isOverdue = t.isOverdue;
                final statusColor = t.taskStatus.color;
                String? dateLabel;
                if (t.endDate != null) {
                  final d = t.endDate!.toLocal();
                  dateLabel = '${d.month}/${d.day}';
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 3,
                          height: 30,
                          margin: const EdgeInsets.only(top: 2, right: 8),
                          decoration: BoxDecoration(
                            color: t.isDone
                                ? const Color(0xFF4CAF50)
                                : isOverdue
                                    ? const Color(0xFFF44336)
                                    : statusColor,
                            borderRadius: BorderRadius.circular(2),
                          )),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  decoration: t.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: t.isDone ? 0.45 : 0.85),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            Row(children: [
                              _statusBadge(t.taskStatus),
                              const SizedBox(width: 3),
                              _priorityBadge(t.priority),
                              if (t.projectName.isNotEmpty) ...[
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(t.projectName,
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.4)),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                              if (dateLabel != null) ...[
                                const SizedBox(width: 3),
                                Text(dateLabel,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: isOverdue
                                            ? const Color(0xFFF44336)
                                            : colorScheme.onSurface
                                                .withValues(alpha: 0.35),
                                        fontWeight: isOverdue
                                            ? FontWeight.w700
                                            : FontWeight.w400)),
                              ],
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildActiveCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _card(
      context,
      icon: Icons.play_circle_outline,
      iconColor: const Color(0xFFFF9800),
      title: '진행 중',
      count: member.activeTasks.length,
      child: member.activeTasks.isEmpty
          ? _emptyText(context, '진행 중인 작업 없음')
          : Column(
              children: member.activeTasks.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 3,
                            height: 28,
                            margin: const EdgeInsets.only(top: 2, right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(2),
                            )),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Row(children: [
                                _priorityBadge(t.priority),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(t.projectName,
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.4)),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
    );
  }

  Widget _buildRecentDoneCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _card(
      context,
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF4CAF50),
      title: '최근 완료',
      count: member.recentDone.length,
      child: member.recentDone.isEmpty
          ? _emptyText(context, '완료된 작업 없음')
          : Column(
              children: member.recentDone.map((t) {
                final daysAgo = t.updatedAt != null
                    ? DateTime.now().difference(t.updatedAt!).inDays
                    : null;
                final timeLabel = daysAgo == null
                    ? ''
                    : daysAgo == 0
                        ? '오늘'
                        : '$daysAgo일 전';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 13, color: const Color(0xFF4CAF50)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(t.title,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (timeLabel.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(timeLabel,
                            style: TextStyle(
                                fontSize: 9,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.35))),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── 4. 할 일 목록 (우선순위 탭 필터) ──────────────────────────────────

  Widget _buildTodoSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final all = member.allTasks;
    final p0 = all.where((t) => t.priority == 'p0').toList();
    final p1 = all.where((t) => t.priority == 'p1').toList();
    final p2 = all.where((t) => t.priority == 'p2').toList();
    final p3 = all.where((t) => t.priority == 'p3').toList();

    List<MemberAllTask> filtered;
    switch (_todoFilter) {
      case 'p0':
        filtered = p0;
        break;
      case 'p1':
        filtered = p1;
        break;
      case 'p2':
        filtered = p2;
        break;
      case 'p3':
        filtered = p3;
        break;
      default:
        filtered = all;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 + 탭 필터
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Icon(Icons.format_list_bulleted,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.55)),
                const SizedBox(width: 6),
                const Text('할 일 목록',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                // 우선순위 탭 필터
                _todoTab(context, 'all', '전체 ${all.length}'),
                const SizedBox(width: 4),
                _todoTab(context, 'p0', 'P0 ${p0.length}',
                    color: const Color(0xFFF44336)),
                const SizedBox(width: 4),
                _todoTab(context, 'p1', 'P1 ${p1.length}',
                    color: const Color(0xFFFF9800)),
                const SizedBox(width: 4),
                _todoTab(context, 'p2', 'P2 ${p2.length}',
                    color: const Color(0xFF2196F3)),
                const SizedBox(width: 4),
                _todoTab(context, 'p3', 'P3 ${p3.length}',
                    color: const Color(0xFF9E9E9E)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          // 내용 영역: 남은 공간 채우고 넘치면 스크롤
          Expanded(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: _emptyText(context, '해당 우선순위의 작업이 없습니다'),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: _buildTodoGrid(context, filtered),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoGrid(BuildContext context, List<MemberAllTask> tasks) {
    // 2컬럼 그리드로 배치
    final rows = <Widget>[];
    for (int i = 0; i < tasks.length; i += 2) {
      final left = tasks[i];
      final right = i + 1 < tasks.length ? tasks[i + 1] : null;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildTodoItem(context, left)),
          const SizedBox(width: 8),
          Expanded(
              child: right != null
                  ? _buildTodoItem(context, right)
                  : const SizedBox.shrink()),
        ],
      ));
      if (i + 2 < tasks.length) rows.add(const SizedBox(height: 6));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _buildTodoItem(BuildContext context, MemberAllTask t) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = t.isOverdue;
    final priorityColor = _priorityColor(t.priority);
    String? dateLabel;
    if (t.endDate != null) {
      final d = t.endDate!.toLocal();
      dateLabel = '${d.month}/${d.day}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue
              ? const Color(0xFFF44336).withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 28,
            margin: const EdgeInsets.only(top: 1, right: 7),
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  _statusBadge(t.taskStatus),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(t.projectName,
                        style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurface.withValues(alpha: 0.4)),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (dateLabel != null) ...[
                    const SizedBox(width: 3),
                    Text(
                      isOverdue ? '⚠$dateLabel' : dateLabel,
                      style: TextStyle(
                        fontSize: 9,
                        color: isOverdue
                            ? const Color(0xFFF44336)
                            : colorScheme.onSurface.withValues(alpha: 0.35),
                        fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 공통 카드 래퍼 ────────────────────────────────────────────────────

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 고정
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Icon(icon, size: 13, color: iconColor),
                const SizedBox(width: 5),
                Text(title,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 5),
                if (count > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: iconColor)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 내용 영역: 고정 높이 안에서 넘치면 스크롤
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  // ── 탭 버튼 ──────────────────────────────────────────────────────────

  Widget _todoTab(BuildContext context, String value, String label,
      {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _todoFilter == value;
    final activeColor = color ?? colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _todoFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive
                ? activeColor
                : colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  // ── 뱃지 / 아바타 / 기타 헬퍼 ───────────────────────────────────────

  Widget _badge(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _statusBadge(TaskStatus status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(status.displayName,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: status.color)),
      );

  Widget _priorityBadge(String priority) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(priority.toUpperCase(),
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _emptyText(BuildContext context, String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(msg,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35))),
      );

  Widget _buildAvatar({double radius = 18}) {
    if (member.profileImageUrl != null && member.profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(member.profileImageUrl!));
    }
    final color = AvatarColor.getColorForUser(member.username);
    final initial = AvatarColor.getInitial(member.username);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(initial,
          style: TextStyle(
              fontSize: radius * 0.75,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'p0': return const Color(0xFFF44336);
      case 'p1': return const Color(0xFFFF9800);
      case 'p3': return const Color(0xFF9E9E9E);
      default:   return const Color(0xFF2196F3);
    }
  }
}
