import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/project.dart';
import '../../models/workspace.dart';
import '../../screens/task_detail_screen.dart';

/// 회의록 작업 현황 패널의 단일 행.
/// 5컬럼: Title / Status / Project / Owner / Date.
/// - 우선순위는 Title 좌측의 작은 색 점으로 표시
/// - 완료(`done`) 행은 strikethrough + 알파 0.5
/// - 호버 시 배경 강조, 탭 시 [TaskDetailScreen] 다이얼로그 오픈
class MeetingTaskTableRow extends StatefulWidget {
  final Task task;
  final Project? project;
  final List<WorkspaceMember> members;

  /// 컬럼 너비 — 패널 좌우 가용 폭에 맞춰 호출부에서 계산해 주입
  final double titleWidth;
  final double statusWidth;
  final double projectWidth;
  final double ownerWidth;
  final double dateWidth;

  const MeetingTaskTableRow({
    super.key,
    required this.task,
    required this.project,
    required this.members,
    required this.titleWidth,
    required this.statusWidth,
    required this.projectWidth,
    required this.ownerWidth,
    required this.dateWidth,
  });

  @override
  State<MeetingTaskTableRow> createState() => _MeetingTaskTableRowState();
}

class _MeetingTaskTableRowState extends State<MeetingTaskTableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final task = widget.task;
    final isDone = task.status == TaskStatus.done;

    final ownerLabel = _resolveOwnerLabel(task.assignedMemberIds, widget.members);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? cs.surfaceContainerHigh.withValues(alpha: 0.6)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Title (우선순위 점 + 제목) ───────────────
              SizedBox(
                width: widget.titleWidth,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: task.priority.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? cs.onSurface.withValues(alpha: 0.5)
                              : cs.onSurface,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Status (점 + 상태명) ────────────────────
              SizedBox(
                width: widget.statusWidth,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: task.status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.status.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: task.status.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Project ──────────────────────────────────
              SizedBox(
                width: widget.projectWidth,
                child: Text(
                  widget.project?.name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              // ── Owner ────────────────────────────────────
              SizedBox(
                width: widget.ownerWidth,
                child: Text(
                  ownerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              // ── Date ────────────────────────────────────
              SizedBox(
                width: widget.dateWidth,
                child: Text(
                  _formatDateRange(task.startDate, task.endDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOverdue(task)
                        ? const Color(0xFFE53935)
                        : cs.onSurface.withValues(alpha: 0.7),
                    fontWeight: _isOverdue(task)
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 시작/마감 날짜를 압축 포맷으로:
  ///  - 둘 다 같은 달: "4/26~30"
  ///  - 둘 다 다른 달: "4/26~5/2"
  ///  - 마감만:        "4/30"
  ///  - 시작만:        "4/26~"
  ///  - 둘 다 없음:    "—"
  static String _formatDateRange(DateTime? start, DateTime? end) {
    String fmt(DateTime d) => '${d.month}/${d.day}';
    if (start != null && end != null) {
      if (start.year == end.year && start.month == end.month) {
        return '${fmt(start)}~${end.day}';
      }
      return '${fmt(start)}~${fmt(end)}';
    }
    if (end != null) return fmt(end);
    if (start != null) return '${fmt(start)}~';
    return '—';
  }

  /// 마감일 지났고 아직 미완료면 빨간색 강조
  static bool _isOverdue(Task task) {
    if (task.status == TaskStatus.done) return false;
    final end = task.endDate;
    if (end == null) return false;
    final today = DateTime.now();
    final endDay = DateTime(end.year, end.month, end.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.isBefore(todayDay);
  }

  void _openDetail(BuildContext context) {
    showGeneralDialog(
      context: context,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          TaskDetailScreen(task: widget.task),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  /// 담당자 1명이면 그 이름, 2명 이상이면 "첫이름 +N", 없으면 "—"
  static String _resolveOwnerLabel(
    List<String> assignedIds,
    List<WorkspaceMember> members,
  ) {
    if (assignedIds.isEmpty) return '—';
    final names = <String>[];
    for (final id in assignedIds) {
      final m = members.where((m) => m.userId == id);
      if (m.isNotEmpty) names.add(m.first.username);
    }
    if (names.isEmpty) return '—';
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1}';
  }
}
