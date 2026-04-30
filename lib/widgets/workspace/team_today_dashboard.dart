import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/member_stats.dart';
import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../screens/task_detail_screen.dart';
import '../../services/task_service.dart';
import '../../utils/avatar_color.dart';

class TeamTodayDashboard extends StatefulWidget {
  final List<MemberStats> allMembers;
  final String workspaceId;
  final VoidCallback onRefresh;

  /// 핀(표시할 멤버) 셋이 바뀔 때마다 부모에게 알림.
  /// 부모는 이 셋으로 다른 위젯(예: 히트맵)도 함께 필터링할 수 있다.
  final ValueChanged<Set<String>>? onPinnedChanged;

  /// summary 와 멤버 grid 사이에 끼워넣을 위젯 (예: Contribution heatmap).
  /// 비어있으면 두 영역이 바로 붙는다.
  final Widget? middleSlot;

  const TeamTodayDashboard({
    super.key,
    required this.allMembers,
    required this.workspaceId,
    required this.onRefresh,
    this.onPinnedChanged,
    this.middleSlot,
  });

  @override
  State<TeamTodayDashboard> createState() => _TeamTodayDashboardState();
}

class _TeamTodayDashboardState extends State<TeamTodayDashboard> {
  Set<String> _pinnedUserIds = {};
  static const _prefKeyPrefix = 'team_dashboard_pinned_';

  @override
  void initState() {
    super.initState();
    _loadPinned();
  }

  @override
  void didUpdateWidget(covariant TeamTodayDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) {
      _loadPinned();
    }
  }

  String get _prefKey => '$_prefKeyPrefix${widget.workspaceId}';

  Future<void> _loadPinned() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefKey);
    setState(() {
      // saved 가 null 이면 (= 한 번도 저장한 적 없음) 처음 진입한 워크스페이스이므로 전체 선택을 기본값으로 둔다.
      // saved 가 빈 리스트라면 사용자가 "전체 해제" 등으로 명시적으로 비운 상태이므로 그대로 존중한다.
      // (이전 구현은 isNotEmpty 로 빈 리스트도 "전체로 리셋" 시켜 버그였음)
      if (saved != null) {
        _pinnedUserIds = saved.toSet();
      } else {
        _pinnedUserIds = widget.allMembers.map((m) => m.userId).toSet();
      }
    });
    _notifyPinnedChanged();
  }

  Future<void> _savePinned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, _pinnedUserIds.toList());
    _notifyPinnedChanged();
  }

  void _notifyPinnedChanged() {
    widget.onPinnedChanged?.call(Set<String>.from(_pinnedUserIds));
  }

  void _toggleMember(String userId) {
    setState(() {
      if (_pinnedUserIds.contains(userId)) {
        _pinnedUserIds.remove(userId);
      } else {
        _pinnedUserIds.add(userId);
      }
    });
    _savePinned();
  }

  List<MemberStats> get _pinnedMembers =>
      widget.allMembers
          .where((m) => _pinnedUserIds.contains(m.userId))
          .toList();

  Future<void> _openTaskDetail(String taskId) async {
    final taskProvider = context.read<TaskProvider>();
    Task? task;
    for (final t in taskProvider.tasks) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    task ??= await TaskService().getTaskById(taskId);
    if (task == null || !mounted) return;

    await showGeneralDialog(
      context: context,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          TaskDetailScreen(task: task!),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pinnedMembers;

    return Column(
      children: [
        _buildSummaryBar(context, pinned),
        // 외부에서 주입된 위젯 (예: Contribution heatmap) — summary 와 grid 사이
        // summary bar 의 좌우 마진(16) 과 동일하게 정렬
        if (widget.middleSlot != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: widget.middleSlot!,
          ),
        ],
        Expanded(
          child: pinned.isEmpty
              ? _buildEmptyState(context)
              : _buildGrid(context, pinned),
        ),
      ],
    );
  }

  // ── 상단 요약 바 ─────────────────────────────────────────────────
  Widget _buildSummaryBar(BuildContext context, List<MemberStats> pinned) {
    final colorScheme = Theme.of(context).colorScheme;
    final allToday =
        pinned.expand((m) => m.todayTasks).toList();
    final totalTasks = allToday.length;
    final doneCount = allToday.where((t) => t.isDone).length;
    final overdueCount = allToday.where((t) => t.isOverdue).length;
    final inProgressCount = totalTasks - doneCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.5),
            colorScheme.primaryContainer.withValues(alpha: 0.2),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          // 오늘 날짜
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 팀 현황',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _todayDateLabel(),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // 통계 칩들
          _summaryChip(
            context,
            icon: Icons.people_alt_outlined,
            label: '멤버',
            value: '${pinned.length}',
            color: colorScheme.primary,
          ),
          const SizedBox(width: 16),
          _summaryChip(
            context,
            icon: Icons.assignment_outlined,
            label: '전체',
            value: '$totalTasks',
            color: colorScheme.brightness == Brightness.dark
                ? const Color(0xFF8E99F3)
                : const Color(0xFF5C6BC0),
          ),
          const SizedBox(width: 16),
          _summaryChip(
            context,
            icon: Icons.trending_up,
            label: '진행',
            value: '$inProgressCount',
            color: colorScheme.brightness == Brightness.dark
                ? const Color(0xFFFFB74D)
                : const Color(0xFFFF9800),
          ),
          const SizedBox(width: 16),
          _summaryChip(
            context,
            icon: Icons.check_circle_outline,
            label: '완료',
            value: '$doneCount',
            color: colorScheme.brightness == Brightness.dark
                ? const Color(0xFF81C784)
                : const Color(0xFF4CAF50),
          ),
          if (overdueCount > 0) ...[
            const SizedBox(width: 16),
            _summaryChip(
              context,
              icon: Icons.warning_amber_rounded,
              label: '지연',
              value: '$overdueCount',
              color: colorScheme.brightness == Brightness.dark
                  ? const Color(0xFFEF5350)
                  : const Color(0xFFF44336),
            ),
          ],
          const Spacer(),
          _buildManageButton(context),
        ],
      ),
    );
  }

  Widget _summaryChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _todayDateLabel() {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} (${weekdays[now.weekday - 1]})';
  }

  Widget _buildManageButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMemberManageDialog(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 5),
              Text(
                '멤버 관리',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 멤버 관리 다이얼로그 ──────────────────────────────────────────
  void _showMemberManageDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final pinnedCount = _pinnedUserIds.length;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('대시보드 멤버 관리',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        '$pinnedCount / ${widget.allMembers.length}명 선택',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _dialogActionChip(
                        context,
                        label: '전체 선택',
                        icon: Icons.select_all,
                        onTap: () {
                          setState(() {
                            _pinnedUserIds = widget.allMembers
                                .map((m) => m.userId)
                                .toSet();
                          });
                          setDialogState(() {});
                          _savePinned();
                        },
                      ),
                      const SizedBox(width: 8),
                      _dialogActionChip(
                        context,
                        label: '전체 해제',
                        icon: Icons.deselect,
                        onTap: () {
                          setState(() {
                            _pinnedUserIds.clear();
                          });
                          setDialogState(() {});
                          _savePinned();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              content: SizedBox(
                width: () {
                  final w = MediaQuery.of(context).size.width;
                  return w < 480 ? w - 64 : 420.0;
                }(),
                height: () {
                  final h = MediaQuery.of(context).size.height;
                  return h < 600 ? h * 0.6 : 400.0;
                }(),
                child: ListView.separated(
                  itemCount: widget.allMembers.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color:
                        colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (ctx, i) {
                    final member = widget.allMembers[i];
                    final isPinned =
                        _pinnedUserIds.contains(member.userId);
                    final todayCount = member.todayTasks.length;
                    final activeCount = member.activeTasks.length;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _toggleMember(member.userId);
                          setDialogState(() {});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isPinned
                                      ? colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isPinned
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant,
                                    width: 1.5,
                                  ),
                                ),
                                child: isPinned
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              _buildMemberAvatar(member, radius: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.username,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isPinned
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Row(
                                      children: [
                                        if (todayCount > 0)
                                          _miniTag('오늘 $todayCount건',
                                              const Color(0xFF5C6BC0)),
                                        if (todayCount > 0 &&
                                            activeCount > 0)
                                          const SizedBox(width: 4),
                                        if (activeCount > 0)
                                          _miniTag('진행 $activeCount건',
                                              const Color(0xFFFF9800)),
                                        if (todayCount == 0 &&
                                            activeCount == 0)
                                          Text(
                                            '오늘 예정 없음',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 12),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('완료', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogActionChip(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color:
                    colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface
                          .withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── 빈 상태 ───────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.group_add_outlined,
                size: 32,
                color: colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            '대시보드에 표시할 멤버를 추가하세요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '멤버 관리에서 팀원을 선택하면 오늘 할 일을 한눈에 볼 수 있어요',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showMemberManageDialog(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('멤버 추가', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 그리드 레이아웃 ─────────────────────────────────────────────
  // Wrap + center alignment: 핀 멤버 수가 한 줄 슬롯보다 적으면 가운데 정렬,
  // 많으면 자연스럽게 다음 줄로 흘려 보냄. 카드 폭은 항상 crossAxisCount 기준
  // 으로 계산해 멤버 수와 무관하게 일관된 크기를 유지한다.
  Widget _buildGrid(BuildContext context, List<MemberStats> members) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        if (width >= 1400) {
          crossAxisCount = 5;
        } else if (width >= 1100) {
          crossAxisCount = 4;
        } else if (width >= 800) {
          crossAxisCount = 3;
        } else if (width >= 520) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        const horizontalPadding = 16.0;
        const spacing = 10.0;
        const aspectRatio = 0.85; // width / height
        final available = width - horizontalPadding * 2;
        final cardWidth =
            (available - spacing * (crossAxisCount - 1)) / crossAxisCount;
        final cardHeight = cardWidth / aspectRatio;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              horizontalPadding, 12, horizontalPadding, 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final m in members)
                SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _buildMemberCard(context, m),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── 멤버 카드 ─────────────────────────────────────────────────────
  Widget _buildMemberCard(BuildContext context, MemberStats member) {
    final colorScheme = Theme.of(context).colorScheme;
    final todayTasks = member.todayTasks;
    final openTasks = todayTasks.where((t) => !t.isDone).toList();
    final doneTasks = todayTasks.where((t) => t.isDone).toList();
    final totalCount = todayTasks.length;
    final doneCount = doneTasks.length;
    final overdueCount = openTasks.where((t) => t.isOverdue).length;
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;

    // 카드 좌측 액센트 색상
    Color accentColor;
    if (totalCount == 0) {
      accentColor = colorScheme.outlineVariant.withValues(alpha: 0.4);
    } else if (doneCount == totalCount) {
      accentColor = const Color(0xFF4CAF50);
    } else if (overdueCount > 0) {
      accentColor = const Color(0xFFF44336);
    } else {
      accentColor = const Color(0xFF5C6BC0);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 좌측 컬러 액센트 바
          Container(width: 3.5, color: accentColor),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 카드 헤더
                _buildCardHeader(
                    context, member, totalCount, doneCount, overdueCount, progress),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                // 오늘 일정 목록 (열린 태스크 + 오늘 완료 태스크 분리)
                Expanded(
                  child: todayTasks.isEmpty
                      ? _buildCardEmptyBody(context)
                      : _buildCardBody(context, openTasks, doneTasks),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBody(
    BuildContext context,
    List<MemberTodayTask> openTasks,
    List<MemberTodayTask> doneTasks,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
      children: [
        if (openTasks.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            label: '오늘 할일',
            count: openTasks.length,
            color: colorScheme.primary,
          ),
          ...openTasks.map((t) => _buildTaskItem(context, t)),
        ],
        if (openTasks.isEmpty && doneTasks.isNotEmpty)
          // 오늘 열린 태스크가 하나도 없고 완료만 있는 경우에도 빈 상태는 보여주지 않고
          // 바로 완료 섹션을 보여줌 (상단에 공백만)
          const SizedBox(height: 2),
        if (doneTasks.isNotEmpty) ...[
          if (openTasks.isNotEmpty) const SizedBox(height: 6),
          _buildSectionHeader(
            context,
            label: '오늘 완료',
            count: doneTasks.length,
            color: const Color(0xFF4CAF50),
          ),
          ...doneTasks.map((t) => _buildTaskItem(context, t)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, top: 2, bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(BuildContext context, MemberStats member,
      int totalCount, int doneCount, int overdueCount, double progress) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
      child: Row(
        children: [
          // 아바타 + 프로그레스 링
          SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (totalCount > 0)
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CustomPaint(
                      painter: _ProgressRingPainter(
                        progress: progress,
                        trackColor:
                            colorScheme.outlineVariant.withValues(alpha: 0.2),
                        progressColor: doneCount == totalCount
                            ? const Color(0xFF4CAF50)
                            : overdueCount > 0
                                ? const Color(0xFFF44336)
                                : colorScheme.primary,
                      ),
                    ),
                  ),
                _buildMemberAvatar(member, radius: 13),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.username,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    if (totalCount > 0) ...[
                      Text(
                        '$doneCount/$totalCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: doneCount == totalCount
                              ? const Color(0xFF4CAF50)
                              : colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 미니 프로그레스바
                      Expanded(
                        child: Container(
                          height: 3,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: doneCount == totalCount
                                    ? const Color(0xFF4CAF50)
                                    : overdueCount > 0
                                        ? const Color(0xFFF44336)
                                        : colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (totalCount == 0)
                      Text(
                        '일정 없음',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.35),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // 지연 뱃지
          if (overdueCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF44336).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '지연 $overdueCount',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF44336)),
              ),
            ),
          // 제거 버튼
          SizedBox(
            width: 26,
            height: 26,
            child: IconButton(
              icon: Icon(Icons.close,
                  size: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.25)),
              onPressed: () => _toggleMember(member.userId),
              tooltip: '대시보드에서 제거',
              padding: EdgeInsets.zero,
              splashRadius: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardEmptyBody(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available,
              size: 22,
              color: colorScheme.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 4),
          Text(
            '오늘 예정 없음',
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ── 작업 아이템 ────────────────────────────────────────────────────
  Widget _buildTaskItem(BuildContext context, MemberTodayTask task) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = task.isOverdue;
    final isDone = task.isDone;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openTaskDetail(task.id),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 아이콘 (체크/진행/지연)
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 6),
            child: isDone
                ? const Icon(Icons.check_circle,
                    size: 14, color: Color(0xFF4CAF50))
                : isOverdue
                    ? const Icon(Icons.error,
                        size: 14, color: Color(0xFFF44336))
                    : Icon(Icons.radio_button_unchecked,
                        size: 14,
                        color: task.taskStatus.color.withValues(alpha: 0.5)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isDone ? FontWeight.w400 : FontWeight.w500,
                    decoration:
                        isDone ? TextDecoration.lineThrough : null,
                    decorationColor:
                        colorScheme.onSurface.withValues(alpha: 0.3),
                    color: colorScheme.onSurface
                        .withValues(alpha: isDone ? 0.35 : 0.85),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _priorityDot(task.priority),
                    const SizedBox(width: 4),
                    if (task.projectName.isNotEmpty)
                      Expanded(
                        child: Text(
                          task.projectName,
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (task.endDate != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        '${task.endDate!.month}/${task.endDate!.day}',
                        style: TextStyle(
                          fontSize: 9,
                          color: isOverdue
                              ? const Color(0xFFF44336)
                              : colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                          fontWeight: isOverdue
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }

  // 우선순위 컬러 dot (뱃지 대신 심플하게)
  Widget _priorityDot(String priority) {
    final color = _priorityColor(priority);
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // ── 공통 헬퍼 ──────────────────────────────────────────────────────
  Widget _buildMemberAvatar(MemberStats member, {double radius = 14}) {
    if (member.profileImageUrl != null &&
        member.profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(member.profileImageUrl!),
      );
    }
    final color = AvatarColor.getColorForUser(member.username);
    final initial = AvatarColor.getInitial(member.username);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'p0':
        return const Color(0xFFF44336);
      case 'p1':
        return const Color(0xFFFF9800);
      case 'p3':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF2196F3);
    }
  }
}

// ── 프로그레스 링 페인터 ──────────────────────────────────────────────
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final strokeWidth = 2.2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor;
}
