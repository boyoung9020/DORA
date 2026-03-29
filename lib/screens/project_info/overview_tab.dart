import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/project_info/active_team_widget.dart';
import '../../widgets/project_info/dday_widget.dart';
import '../../widgets/project_info/description_tasks_widget.dart';
import '../../widgets/project_info/github_card_widget.dart';
import '../../widgets/project_info/member_workload_section.dart';
import '../../widgets/project_info/productivity_widget.dart';
import '../../widgets/project_info/progress_widget.dart';
import '../../widgets/project_info/team_members_card_widget.dart';
import '../../widgets/project_info/team_workload_chart_widget.dart';

class OverviewTab extends StatelessWidget {
  final Project project;
  final List<Task> allTasks;
  final List<User> teamMembers;
  final bool teamMembersLoading;
  final bool isPM;
  final VoidCallback onMemberChanged;
  final dynamic authService;

  const OverviewTab({
    super.key,
    required this.project,
    required this.allTasks,
    required this.teamMembers,
    required this.teamMembersLoading,
    required this.isPM,
    required this.onMemberChanged,
    required this.authService,
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
      padding: const EdgeInsets.all(24),
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
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.6,
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
          const SizedBox(height: 24),

          // 프로젝트 설명 + 마감임박 / 팀원 막대 그래프
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            final description = DescriptionAndUrgentTasksCard(
              project: project,
              allTasks: allTasks,
              teamMembers: teamMembers,
            );
            final chart = TeamWorkloadChart(memberWorkload: memberWorkload);
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: description),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: chart),
                ],
              );
            }
            return Column(children: [
              description,
              const SizedBox(height: 24),
              chart,
            ]);
          }),
          const SizedBox(height: 24),

          // 팀원 + GitHub
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TeamMembersCard(
                  teamMembers: teamMembers,
                  isPM: isPM,
                  onMemberChanged: onMemberChanged,
                  authService: authService,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GitHubCard(projectId: project.id, isPM: isPM),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 팀원별 업무 현황
          MemberWorkloadSection(
            teamMembers: teamMembers,
            isLoading: teamMembersLoading,
            allTasks: allTasks,
          ),
        ],
      ),
    );
  }
}
