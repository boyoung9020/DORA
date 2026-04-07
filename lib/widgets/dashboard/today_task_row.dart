import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../models/project.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../screens/task_detail_screen.dart';

/// 오늘 할 작업 리스트의 단일 행.
/// 대시보드 카드와 사이드 패널 양쪽에서 재사용한다.
class TodayTaskRow extends StatelessWidget {
  final Task task;
  final Project? project;
  /// true 이면 사이드 패널용 넓은 레이아웃
  final bool expanded;

  const TodayTaskRow({
    super.key,
    required this.task,
    this.project,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDone = task.status == TaskStatus.done;
    final priorityColor = task.priority.color;

    final checkWidth = expanded ? 40.0 : 36.0;
    final projectWidth = expanded ? 120.0 : 90.0;
    final priorityWidth = expanded ? 70.0 : 60.0;
    final titleSize = expanded ? 13.0 : 12.0;
    final hPad = expanded ? 16.0 : 4.0;
    final vPad = expanded ? 6.0 : 2.0;

    return InkWell(
      onTap: () {
        showGeneralDialog(
          context: context,
          transitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) =>
              TaskDetailScreen(task: task),
          transitionBuilder:
              (context, animation, secondaryAnimation, child) => child,
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: Row(
          children: [
            // 체크박스
            SizedBox(
              width: checkWidth,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isDone,
                    onChanged: (value) async {
                      if (value == true && !isDone) {
                        final taskProvider = context.read<TaskProvider>();
                        final authProvider = context.read<AuthProvider>();
                        await taskProvider.updateTask(
                          task.copyWith(status: TaskStatus.done),
                          userId: authProvider.currentUser?.id,
                          username: authProvider.currentUser?.username,
                        );
                      }
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                    activeColor: TaskStatus.done.color,
                    side: BorderSide(
                        color: cs.onSurface.withValues(alpha: 0.3),
                        width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
            // 제목
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 6, vertical: expanded ? 0 : 8),
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w500,
                    color: isDone
                        ? cs.onSurface.withValues(alpha: 0.4)
                        : cs.onSurface,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: cs.onSurface.withValues(alpha: 0.4),
                  ),
                  maxLines: expanded ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // 프로젝트
            SizedBox(
              width: projectWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    if (project != null) ...[
                      Container(
                        width: expanded ? 8 : 6,
                        height: expanded ? 8 : 6,
                        decoration: BoxDecoration(
                            color: project!.color, shape: BoxShape.circle),
                      ),
                      SizedBox(width: expanded ? 6 : 4),
                    ],
                    Expanded(
                      child: Text(
                        project?.name ?? '-',
                        style: TextStyle(
                          fontSize: expanded ? 12 : 11,
                          color: isDone
                              ? cs.onSurface.withValues(alpha: 0.35)
                              : cs.onSurface.withValues(alpha: 0.6),
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor:
                              cs.onSurface.withValues(alpha: 0.3),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 우선순위
            SizedBox(
              width: priorityWidth,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: expanded ? 8 : 6, vertical: expanded ? 3 : 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(
                        alpha: isDone ? 0.08 : 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.displayName,
                    style: TextStyle(
                      fontSize: expanded ? 11 : 10,
                      fontWeight: FontWeight.bold,
                      color: isDone
                          ? priorityColor.withValues(alpha: 0.4)
                          : priorityColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 오늘 할 작업 테이블 헤더 행.
class TodayTaskHeader extends StatelessWidget {
  final bool expanded;

  const TodayTaskHeader({super.key, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final projectWidth = expanded ? 120.0 : 90.0;
    final priorityWidth = expanded ? 70.0 : 60.0;
    final checkWidth = expanded ? 40.0 : 36.0;
    final fontSize = expanded ? 12.0 : 11.0;
    final hPad = expanded ? 16.0 : 4.0;
    final labelColor = cs.onSurface.withValues(alpha: 0.6);
    final style = TextStyle(
        fontSize: fontSize, fontWeight: FontWeight.w600, color: labelColor);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: expanded ? 10 : 0),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.03),
        borderRadius: expanded
            ? null
            : const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          SizedBox(width: checkWidth),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text('제목', style: style),
            ),
          ),
          SizedBox(width: projectWidth, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text('프로젝트', style: style),
          )),
          SizedBox(width: priorityWidth, child: Center(
            child: Text('우선순위', style: style),
          )),
        ],
      ),
    );
  }
}
