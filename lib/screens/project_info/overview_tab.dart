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
                  const SizedBox(width: 12),
                  Expanded(flex: 1, child: chart),
                ],
              );
            }
            return Column(children: [
              description,
              const SizedBox(height: 12),
              chart,
            ]);
          }),
          const SizedBox(height: 16),

          // 팀원 + GitHub
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final members = TeamMembersCard(
              teamMembers: teamMembers,
              isPM: isPM,
              onMemberChanged: onMemberChanged,
              authService: authService,
            );
            final github = GitHubCard(projectId: project.id, isPM: isPM);
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: members),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: github),
                ],
              );
            }
            return Column(
              children: [
                members,
                const SizedBox(height: 12),
                github,
              ],
            );
          }),
          const SizedBox(height: 16),

          // 팀원별 업무 현황
          LayoutBuilder(builder: (context, constraints) {
            final maxH = constraints.maxWidth > 900 ? 360.0 : 420.0;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: SingleChildScrollView(
                child: MemberWorkloadSection(
                  teamMembers: teamMembers,
                  isLoading: teamMembersLoading,
                  allTasks: allTasks,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
