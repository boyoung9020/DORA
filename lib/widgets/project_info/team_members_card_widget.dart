import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/project.dart';
import '../../models/user.dart';
import '../../providers/project_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/avatar_color.dart';
import '../../widgets/glass_container.dart';

class TeamMembersCard extends StatelessWidget {
  final List<User> teamMembers;
  final bool isPM;
  final VoidCallback onMemberChanged;
  final AuthService authService;

  const TeamMembersCard({
    super.key,
    required this.teamMembers,
    required this.isPM,
    required this.onMemberChanged,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      blur: 20,
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
      ],
      shadowBlurRadius: 8,
      shadowOffset: const Offset(0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('팀원',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${teamMembers.length}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer),
                ),
              ),
              const Spacer(),
              IconButton(
                icon:
                    Icon(Icons.person_add_alt_1, size: 20, color: colorScheme.primary),
                tooltip: '팀원 초대',
                onPressed: () => _showAddDialog(context, colorScheme),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (teamMembers.isEmpty)
            Text('팀원이 없습니다',
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.5)))
          else
            ...List.generate(teamMembers.length, (i) {
              final member = teamMembers[i];
              final project =
                  context.read<ProjectProvider>().currentProject;
              final isCreator = project?.creatorId == member.id;
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AvatarColor.getColorForUser(member.username),
                      backgroundImage: member.profileImageUrl != null
                          ? NetworkImage(member.profileImageUrl!)
                          : null,
                      child: member.profileImageUrl == null
                          ? Text(
                              member.username.isNotEmpty
                                  ? member.username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.username,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface)),
                          if (member.email.isNotEmpty)
                            Text(member.email,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    if (isCreator)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('PM',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800)),
                      )
                    else if (isPM)
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            size: 18, color: Colors.red.shade300),
                        tooltip: '제거',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            _removeTeamMember(context, member, colorScheme),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, ColorScheme colorScheme) {
    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.currentProject;
    if (project == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<List<User>>(
          future: _loadAvailableUsers(project),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData) {
              return const Dialog(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final availableUsers = snapshot.data!;
            if (availableUsers.isEmpty) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('추가할 수 있는 사용자가 없습니다'),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('닫기')),
                    ],
                  ),
                ),
              );
            }
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 400, maxHeight: 500),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('팀원 초대',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface)),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableUsers.length,
                          itemBuilder: (_, i) {
                            final user = availableUsers[i];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    AvatarColor.getColorForUser(user.username),
                                backgroundImage: user.profileImageUrl != null
                                    ? NetworkImage(user.profileImageUrl!)
                                    : null,
                                child: user.profileImageUrl == null
                                    ? Text(
                                        user.username.isNotEmpty
                                            ? user.username[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))
                                    : null,
                              ),
                              title: Text(user.username,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(user.email,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.5))),
                              trailing: IconButton(
                                icon: Icon(Icons.add_circle,
                                    color: colorScheme.primary),
                                onPressed: () async {
                                  final added =
                                      await projectProvider.addTeamMember(
                                          project.id, user.id);
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  onMemberChanged();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(added
                                            ? '${user.username}님이 팀에 추가되었습니다'
                                            : '팀원 추가에 실패했습니다'),
                                        backgroundColor: added
                                            ? colorScheme.primary
                                            : colorScheme.error,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('닫기')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<User>> _loadAvailableUsers(Project project) async {
    try {
      final List<User> candidates;
      if (project.workspaceId != null) {
        candidates = (await authService.getUsersByWorkspace(project.workspaceId!))
            .cast<User>();
      } else {
        candidates = (await authService.getApprovedUsers()).cast<User>();
      }
      return candidates
          .where((u) => !project.teamMemberIds.contains(u.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _removeTeamMember(
      BuildContext context, User member, ColorScheme colorScheme) async {
    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.currentProject;
    if (project == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀원 제거'),
        content: Text('${member.username}님을 프로젝트에서 제거하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('제거', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final removed =
          await projectProvider.removeTeamMember(project.id, member.id);
      if (removed) {
        onMemberChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member.username}님이 제거되었습니다')),
          );
        }
      }
    }
  }
}
