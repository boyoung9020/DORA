import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/project_info/member_workload_section.dart';
import '../../widgets/project_info/team_members_card_widget.dart';
import '../../widgets/project_info/team_workload_chart_widget.dart';

class MembersTab extends StatelessWidget {
  final Project project;
  final List<Task> allTasks;
  final List<User> teamMembers;
  final bool teamMembersLoading;
  final bool isPM;
  final VoidCallback onMemberChanged;
  final dynamic authService;

  const MembersTab({
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
          // 팀원별 작업 할당 막대 그래프
          TeamWorkloadChart(memberWorkload: memberWorkload),
          const SizedBox(height: 16),

          // 팀원 목록 (초대/제거)
          TeamMembersCard(
            teamMembers: teamMembers,
            isPM: isPM,
            onMemberChanged: onMemberChanged,
            authService: authService,
          ),
          const SizedBox(height: 16),

          // 팀원별 업무 상세 현황
          MemberWorkloadSection(
            teamMembers: teamMembers,
            isLoading: teamMembersLoading,
            allTasks: allTasks,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
