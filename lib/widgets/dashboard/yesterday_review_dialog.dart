import 'package:flutter/material.dart';
import '../../models/member_stats.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';

/// 어제 미완료 작업 리뷰 강제 모달 다이얼로그
class YesterdayReviewDialog extends StatefulWidget {
  final List<MemberTodayTask> tasks;
  final String targetDate;

  const YesterdayReviewDialog({
    super.key,
    required this.tasks,
    required this.targetDate,
  });

  @override
  State<YesterdayReviewDialog> createState() => _YesterdayReviewDialogState();
}

enum _TaskAction { none, done, carryToday, skip }

class _YesterdayReviewDialogState extends State<YesterdayReviewDialog> {
  final _taskService = TaskService();
  late final Map<String, _TaskAction> _actions;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _actions = {for (final t in widget.tasks) t.id: _TaskAction.none};
  }

  bool get _allHandled =>
      _actions.values.every((a) => a != _TaskAction.none);

  int get _handledCount =>
      _actions.values.where((a) => a != _TaskAction.none).length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: widget.tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _buildTaskCard(context, widget.tasks[i]),
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 날짜 포맷
    final parts = widget.targetDate.split('-');
    final dateLabel = parts.length == 3
        ? '${parts[1]}월 ${parts[2]}일'
        : widget.targetDate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_late_outlined,
                size: 20, color: Color(0xFFFF9800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '어제 미완료 작업',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.tasks.length}건',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel의 할 일 중 완료되지 않은 작업입니다',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // 진행 카운터
          Text(
            '$_handledCount/${widget.tasks.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _allHandled
                  ? const Color(0xFF4CAF50)
                  : colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 6),
          // 닫기 버튼 (어떤 경로로 닫아도 서버 ack 는 이미 완료되어 있음)
          Tooltip(
            message: '닫기',
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, MemberTodayTask task) {
    final colorScheme = Theme.of(context).colorScheme;
    final action = _actions[task.id] ?? _TaskAction.none;
    final isHandled = action != _TaskAction.none;
    final isProcessing = _processing.contains(task.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHandled
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHandled
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작업 정보
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상태 아이콘
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 8),
                child: isHandled
                    ? const Icon(Icons.check_circle,
                        size: 18, color: Color(0xFF4CAF50))
                    : Icon(Icons.radio_button_unchecked,
                        size: 18,
                        color: colorScheme.onSurface.withValues(alpha: 0.3)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isHandled ? FontWeight.w400 : FontWeight.w600,
                        decoration:
                            isHandled ? TextDecoration.lineThrough : null,
                        decorationColor:
                            colorScheme.onSurface.withValues(alpha: 0.3),
                        color: colorScheme.onSurface
                            .withValues(alpha: isHandled ? 0.4 : 0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _statusBadge(task.taskStatus),
                        const SizedBox(width: 4),
                        _priorityBadge(task.priority),
                        if (task.projectName.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.projectName,
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (task.endDate != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${task.endDate!.month}/${task.endDate!.day}',
                            style: TextStyle(
                              fontSize: 10,
                              color: task.isOverdue
                                  ? const Color(0xFFF44336)
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                              fontWeight: task.isOverdue
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
          // 액션 버튼들
          if (!isHandled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                _actionButton(
                  context,
                  label: '완료 처리',
                  icon: Icons.check,
                  color: const Color(0xFF4CAF50),
                  isLoading: isProcessing,
                  onTap: isProcessing
                      ? null
                      : () => _handleDone(task),
                ),
                const SizedBox(width: 6),
                _actionButton(
                  context,
                  label: '오늘로 연장',
                  icon: Icons.arrow_forward,
                  color: const Color(0xFF2196F3),
                  isLoading: isProcessing,
                  onTap: isProcessing
                      ? null
                      : () => _handleCarryToday(task),
                ),
                const SizedBox(width: 6),
                _actionButton(
                  context,
                  label: '건너뛰기',
                  icon: Icons.skip_next,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  isLoading: false,
                  onTap: () => _handleSkip(task),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _actionLabel(action),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _actionLabel(_TaskAction action) {
    switch (action) {
      case _TaskAction.done:
        return '완료 처리됨';
      case _TaskAction.carryToday:
        return '오늘로 연장됨';
      case _TaskAction.skip:
        return '건너뜀';
      case _TaskAction.none:
        return '';
    }
  }

  Future<void> _handleDone(MemberTodayTask task) async {
    setState(() => _processing.add(task.id));
    try {
      await _taskService.changeTaskStatus(task.id, TaskStatus.done);
      if (mounted) {
        setState(() {
          _actions[task.id] = _TaskAction.done;
          _processing.remove(task.id);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing.remove(task.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('완료 처리 실패: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _handleCarryToday(MemberTodayTask task) async {
    setState(() => _processing.add(task.id));
    try {
      // 전체 Task 를 가져와서 end_date 를 오늘로, start_date 도 필요 시 오늘로 당김
      // (start_date 가 어제 이전이면 범위가 어제와 겹쳐 '어제 미완료' 에 계속 잡히는 문제 방지)
      final fullTask = await _taskService.getTaskById(task.id);
      if (fullTask == null) throw Exception('작업을 찾을 수 없습니다');

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final currentStart = fullTask.startDate;
      final adjustedStart = (currentStart != null && currentStart.isBefore(todayDate))
          ? todayDate
          : currentStart;
      final updated = fullTask.copyWith(
        startDate: adjustedStart,
        endDate: todayDate,
      );
      await _taskService.updateTask(updated);

      if (mounted) {
        setState(() {
          _actions[task.id] = _TaskAction.carryToday;
          _processing.remove(task.id);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing.remove(task.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연장 실패: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _handleSkip(MemberTodayTask task) {
    setState(() {
      _actions[task.id] = _TaskAction.skip;
    });
  }

  Widget _buildFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                foregroundColor: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              child: const Text(
                '나중에 처리',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _allHandled ? () => Navigator.of(context).pop() : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child: Text(
                _allHandled
                    ? '완료'
                    : '완료 ($_handledCount/${widget.tasks.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _allHandled
                      ? null
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(TaskStatus status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status.displayName,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: status.color),
        ),
      );

  Widget _priorityBadge(String priority) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
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
