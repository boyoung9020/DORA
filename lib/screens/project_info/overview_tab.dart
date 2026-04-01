import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/project_info/active_team_widget.dart';
import '../../widgets/project_info/dday_widget.dart';
import '../../widgets/project_info/description_tasks_widget.dart';
import '../../widgets/project_info/github_card_widget.dart';
import '../../widgets/project_info/productivity_widget.dart';
import '../../widgets/project_info/progress_widget.dart';
import '../../widgets/project_info/team_workload_chart_widget.dart';

class OverviewTab extends StatelessWidget {
  final Project project;
  final List<Task> allTasks;
  final List<User> teamMembers;
  final bool isPM;

  const OverviewTab({
    super.key,
    required this.project,
    required this.allTasks,
    required this.teamMembers,
    required this.isPM,
  });

  @override
  Widget build(BuildContext context) {
    final doneTasks = allTasks.where((t) => t.status == TaskStatus.done).length;
    final inProgressTasks =
        allTasks.where((t) => t.status == TaskStatus.inProgress).length;
    final progressPercent =
        allTasks.isNotEmpty ? (doneTasks / allTasks.length * 100) : 0.0;

    final activeAssigneeIds = <String>{};
    for (final t in allTasks) {
      if (t.status == TaskStatus.inProgress || t.status == TaskStatus.inReview) {
        activeAssigneeIds.addAll(t.assignedMemberIds);
      }
    }
    final activeMembers =
        teamMembers.where((m) => activeAssigneeIds.contains(m.id)).toList();

    final memberWorkload = teamMembers.map((member) {
      final count =
          allTasks.where((t) => t.assignedMemberIds.contains(member.id)).length;
      return MemberWorkload(member: member, count: count);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4개 프리미엄 카드
          LayoutBuilder(builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 600
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: crossCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.6,
              children: [
                ProgressCard(percent: progressPercent),
                ProductivityCard(
                    completedTasks: doneTasks,
                    inProgressTasks: inProgressTasks),
                ActiveTeamCard(activeMembers: activeMembers),
                DDayCard(
                    createdAt: project.createdAt,
                    progressPercent: progressPercent,
                    allTasks: allTasks),
              ],
            );
          }),
          const SizedBox(height: 16),

          // 마감임박/최우선 작업 + 팀원 막대 그래프
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            final urgentCard = DescriptionAndUrgentTasksCard(
              project: project,
              allTasks: allTasks,
              teamMembers: teamMembers,
            );
            final chart = TeamWorkloadChart(memberWorkload: memberWorkload);
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: urgentCard),
                  const SizedBox(width: 12),
                  Expanded(flex: 1, child: chart),
                ],
              );
            }
            return Column(children: [
              urgentCard,
              const SizedBox(height: 12),
              chart,
            ]);
          }),
          const SizedBox(height: 16),

          // GitHub 카드
          GitHubCard(projectId: project.id, isPM: isPM),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
