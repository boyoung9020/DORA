import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/project.dart';
import '../../models/workspace.dart';
import 'meeting_task_table_row.dart';

/// 회의록에서 생성된 작업 현황 — 사이드 패널 본문.
///
/// 부모(`showExpandableSidePanel.bodyBuilder`) 가 사용 가능한 너비를
/// LayoutBuilder 로 받아 컬럼 너비를 그에 맞게 분배한다.
/// 정렬 순서는 호출부가 [tasks] 의 순서로 전달한 그대로 유지 (회의록 줄 등장 순).
class MeetingTasksPanel extends StatelessWidget {
  final List<Task> tasks;

  /// projectId -> Project 매핑 (이름 표시용)
  final Map<String, Project> projectsById;

  /// userId -> WorkspaceMember 매핑이 아닌, 전체 멤버 리스트
  /// (행 위젯이 자체적으로 lookup 하도록 그대로 전달)
  final List<WorkspaceMember> members;

  const MeetingTasksPanel({
    super.key,
    required this.tasks,
    required this.projectsById,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (tasks.isEmpty) {
      return _buildEmpty(context, cs);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = _computeColumnWidths(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildColumnHeader(cs, widths),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: tasks.length,
                itemBuilder: (context, i) {
                  final t = tasks[i];
                  return MeetingTaskTableRow(
                    task: t,
                    project: projectsById[t.projectId],
                    members: members,
                    titleWidth: widths.title,
                    statusWidth: widths.status,
                    projectWidth: widths.project,
                    ownerWidth: widths.owner,
                    dateWidth: widths.date,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColumnHeader(ColorScheme cs, _ColumnWidths w) {
    TextStyle headerStyle() => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.55),
          letterSpacing: 0.3,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: w.title,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('Title', style: headerStyle()),
            ),
          ),
          SizedBox(width: w.status, child: Text('Status', style: headerStyle())),
          SizedBox(width: w.project, child: Text('Project', style: headerStyle())),
          SizedBox(width: w.owner, child: Text('Owner', style: headerStyle())),
          SizedBox(width: w.date, child: Text('Date', style: headerStyle())),
        ],
      ),
    );
  }

  /// 가용 폭에서 컬럼별 너비 분배.
  /// (좌우 패딩 12 * 2 = 24 만큼 제외 후 분배)
  /// 5컬럼: Title(flex) / Status / Project / Owner / Date
  _ColumnWidths _computeColumnWidths(double maxWidth) {
    final usable = (maxWidth - 24).clamp(380.0, double.infinity);
    final status = 90.0;
    final project = (usable * 0.16).clamp(70.0, 120.0);
    final owner = (usable * 0.13).clamp(70.0, 100.0);
    final date = 80.0;
    final title = (usable - status - project - owner - date).clamp(120.0, double.infinity);
    return _ColumnWidths(
      title: title,
      status: status,
      project: project,
      owner: owner,
      date: date,
    );
  }

  Widget _buildEmpty(BuildContext context, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '생성된 작업이 없습니다',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '본문 줄 끝의 + 아이콘을 눌러\n작업을 추가하세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnWidths {
  final double title;
  final double status;
  final double project;
  final double owner;
  final double date;
  const _ColumnWidths({
    required this.title,
    required this.status,
    required this.project,
    required this.owner,
    required this.date,
  });
}
