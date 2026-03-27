import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/github_provider.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';
import 'package:url_launcher/url_launcher.dart';

/// 프로젝트 정보 화면 - 통계, 팀원, 진행률, GitHub 연동
class ProjectInfoScreen extends StatefulWidget {
  const ProjectInfoScreen({super.key});

  @override
  State<ProjectInfoScreen> createState() => _ProjectInfoScreenState();
}

class _ProjectInfoScreenState extends State<ProjectInfoScreen> {
  final AuthService _authService = AuthService();
  List<User> _teamMembers = [];
  bool _loadingMembers = false;

  // GitHub 연결 폼
  final _repoOwnerController = TextEditingController();
  final _repoNameController = TextEditingController();
  final _patController = TextEditingController();
  bool _showConnectForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeamMembers();
      _loadGitHubInfo();
    });
  }

  @override
  void dispose() {
    _repoOwnerController.dispose();
    _repoNameController.dispose();
    _patController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamMembers() async {
    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.currentProject;
    if (project == null) return;

    setState(() => _loadingMembers = true);
    try {
      final allUsers = await _authService.getAllUsers();
      final members = allUsers.where((u) => project.teamMemberIds.contains(u.id)).toList();
      if (mounted) setState(() => _teamMembers = members);
    } catch (_) {}
    if (mounted) setState(() => _loadingMembers = false);
  }

  void _loadGitHubInfo() {
    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.currentProject;
    if (project == null) return;
    context.read<GitHubProvider>().loadRepoInfo(project.id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final projectProvider = context.watch<ProjectProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final authProvider = context.watch<AuthProvider>();
    final project = projectProvider.currentProject;

    if (project == null) {
      return const Center(child: Text('프로젝트를 선택해주세요'));
    }

    // 태스크 통계 계산
    final allTasks = taskProvider.tasks;
    final totalTasks = allTasks.length;
    final doneTasks = allTasks.where((t) => t.status == TaskStatus.done).length;
    final inProgressTasks = allTasks.where((t) => t.status == TaskStatus.inProgress).length;
    final inReviewTasks = allTasks.where((t) => t.status == TaskStatus.inReview).length;
    final readyTasks = allTasks.where((t) => t.status == TaskStatus.ready).length;
    final backlogTasks = allTasks.where((t) => t.status == TaskStatus.backlog).length;
    final progressPercent = totalTasks > 0 ? (doneTasks / totalTasks * 100) : 0.0;

    final isPM = authProvider.currentUser?.id == project.creatorId || (authProvider.currentUser?.isAdmin ?? false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로젝트 헤더
            _buildProjectHeader(project, colorScheme),
            const SizedBox(height: 24),

            // 진행률 + 통계 카드 Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 진행률 카드
                Expanded(child: _buildProgressCard(progressPercent, totalTasks, doneTasks, colorScheme)),
                const SizedBox(width: 16),
                // 상태별 통계 카드
                Expanded(
                  child: _buildStatusStatsCard(
                    backlogTasks, readyTasks, inProgressTasks, inReviewTasks, doneTasks, totalTasks, colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 팀원 + GitHub Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 팀원 목록
                Expanded(child: _buildTeamMembersCard(colorScheme, isPM)),
                const SizedBox(width: 16),
                // GitHub 연동
                Expanded(child: _buildGitHubCard(project.id, isPM, colorScheme)),
              ],
            ),
            const SizedBox(height: 24),

            // 팀원별 업무 현황
            _buildMemberWorkloadSection(allTasks, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectHeader(dynamic project, ColorScheme colorScheme) {
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: project.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.folder_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
                if (project.description != null && project.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      project.description!,
                      style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '생성일: ${project.createdAt.year}-${project.createdAt.month.toString().padLeft(2, '0')}-${project.createdAt.day.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 4),
              Text(
                '팀원 ${project.teamMemberIds.length}명',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(double percent, int total, int done, ColorScheme colorScheme) {
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
          Text('전체 진행률', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 10,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percent >= 100
                            ? Colors.green
                            : percent >= 50
                                ? Colors.blue
                                : Colors.orange,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      Text(
                        '$done / $total',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              total == 0
                  ? '작업이 없습니다'
                  : percent >= 100
                      ? '모든 작업 완료!'
                      : '${total - done}개 작업 남음',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStatsCard(
    int backlog, int ready, int inProgress, int inReview, int done, int total, ColorScheme colorScheme,
  ) {
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
          Text('상태별 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          _buildStatusRow('백로그', backlog, total, Colors.grey, colorScheme),
          const SizedBox(height: 8),
          _buildStatusRow('준비됨', ready, total, Colors.blue.shade300, colorScheme),
          const SizedBox(height: 8),
          _buildStatusRow('진행 중', inProgress, total, Colors.orange, colorScheme),
          const SizedBox(height: 8),
          _buildStatusRow('검토 중', inReview, total, Colors.purple, colorScheme),
          const SizedBox(height: 8),
          _buildStatusRow('완료', done, total, Colors.green, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, int total, Color color, ColorScheme colorScheme) {
    final ratio = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(label, style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            '$count',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMembersCard(ColorScheme colorScheme, bool isPM) {
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
              Text('팀원', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_teamMembers.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.person_add_alt_1, size: 20, color: colorScheme.primary),
                tooltip: '팀원 초대',
                onPressed: () => _showAddTeamMemberDialog(colorScheme),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingMembers)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_teamMembers.isEmpty)
            Text('팀원이 없습니다', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)))
          else
            ...List.generate(
              _teamMembers.length,
              (i) {
                final member = _teamMembers[i];
                final project = context.read<ProjectProvider>().currentProject;
                final isCreator = project?.creatorId == member.id;
                return Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AvatarColor.getColorForUser(member.username),
                        backgroundImage: member.profileImageUrl != null ? NetworkImage(member.profileImageUrl!) : null,
                        child: member.profileImageUrl == null
                            ? Text(
                                member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.username,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                            ),
                            if (member.email.isNotEmpty)
                              Text(
                                member.email,
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                              ),
                          ],
                        ),
                      ),
                      if (isCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('PM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                        )
                      else if (isPM)
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, size: 18, color: Colors.red.shade300),
                          tooltip: '제거',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _removeTeamMember(member, colorScheme),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddTeamMemberDialog(ColorScheme colorScheme) {
    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.currentProject;
    if (project == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<List<User>>(
          future: _loadAvailableUsers(project),
          builder: (context, snapshot) {
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('추가할 수 있는 사용자가 없습니다'),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('닫기')),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('팀원 초대', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableUsers.length,
                          itemBuilder: (ctx, i) {
                            final user = availableUsers[i];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AvatarColor.getColorForUser(user.username),
                                backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
                                child: user.profileImageUrl == null
                                    ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                                    : null,
                              ),
                              title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(user.email, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                              trailing: IconButton(
                                icon: Icon(Icons.add_circle, color: colorScheme.primary),
                                onPressed: () async {
                                  final added = await projectProvider.addTeamMember(project.id, user.id);
                                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                                  if (added) {
                                    _loadTeamMembers();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${user.username}님이 팀에 추가되었습니다'), backgroundColor: colorScheme.primary),
                                      );
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: const Text('팀원 추가에 실패했습니다'), backgroundColor: colorScheme.error),
                                      );
                                    }
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
                        child: TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('닫기')),
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

  Future<List<User>> _loadAvailableUsers(dynamic currentProject) async {
    try {
      final workspaceId = (currentProject as Project).workspaceId;
      final List<User> candidates;
      if (workspaceId != null) {
        candidates = (await _authService.getUsersByWorkspace(workspaceId)).cast<User>();
      } else {
        candidates = (await _authService.getApprovedUsers()).cast<User>();
      }
      return candidates.where((u) => !currentProject.teamMemberIds.contains(u.id)).toList();
    } catch (_) {
      return [];
    }
  }

  void _removeTeamMember(User member, ColorScheme colorScheme) async {
    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.currentProject;
    if (project == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀원 제거'),
        content: Text('${member.username}님을 프로젝트에서 제거하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('제거', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final removed = await projectProvider.removeTeamMember(project.id, member.id);
      if (removed) {
        _loadTeamMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member.username}님이 제거되었습니다')),
          );
        }
      }
    }
  }

  Widget _buildGitHubCard(String projectId, bool isPM, ColorScheme colorScheme) {
    return Consumer<GitHubProvider>(
      builder: (context, ghProvider, _) {
        final repo = ghProvider.connectedRepo;

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
                  Icon(Icons.code, size: 20, color: colorScheme.onSurface),
                  const SizedBox(width: 8),
                  Text('GitHub 연동', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const Spacer(),
                  if (repo != null)
                    IconButton(
                      icon: Icon(Icons.link_off, size: 18, color: Colors.red.shade400),
                      tooltip: '연결 해제',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('GitHub 연결 해제'),
                            content: Text('${repo.fullName} 연결을 해제하시겠습니까?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('해제', style: TextStyle(color: Colors.red.shade600)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ghProvider.disconnectRepo(projectId);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (ghProvider.isLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (repo != null) ...[
                // 연결된 레포 정보
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse('https://github.com/${repo.repoOwner}/${repo.repoName}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primaryContainer),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.code, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                repo.fullName,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.primary),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.open_in_new, size: 12, color: colorScheme.primary.withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'GitHub에서 열기',
                                    style: TextStyle(fontSize: 11, color: colorScheme.primary.withValues(alpha: 0.7)),
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
                const SizedBox(height: 12),
                // 커밋/브랜치/PR 빠른 보기 버튼
                Row(
                  children: [
                    _buildQuickActionButton(
                      icon: Icons.commit,
                      label: '커밋',
                      onTap: () => _showCommitsDialog(context, projectId, colorScheme),
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionButton(
                      icon: Icons.account_tree_outlined,
                      label: '브랜치',
                      onTap: () => _showBranchesDialog(context, projectId, colorScheme),
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionButton(
                      icon: Icons.merge,
                      label: 'PR',
                      onTap: () => _showPRsDialog(context, projectId, colorScheme),
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
                if (repo.hasToken)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key, size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text('PAT 연결됨', style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
                      ],
                    ),
                  ),
              ] else ...[
                // 미연결 상태
                if (!_showConnectForm) ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.link_off, size: 40, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text(
                          '연결된 GitHub 레포가 없습니다',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                        ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => setState(() => _showConnectForm = true),
                            icon: const Icon(Icons.add_link, size: 18),
                            label: const Text('레포 연결'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  // 연결 폼
                  TextField(
                    controller: _repoOwnerController,
                    decoration: InputDecoration(
                      labelText: 'Repository Owner',
                      hintText: 'e.g. octocat',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _repoNameController,
                    decoration: InputDecoration(
                      labelText: 'Repository Name',
                      hintText: 'e.g. Hello-World',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _patController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Personal Access Token (선택)',
                      hintText: 'Private 레포 접근 시 필요',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ghProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(ghProvider.errorMessage!, style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _showConnectForm = false),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: ghProvider.isLoading
                              ? null
                              : () async {
                                  final owner = _repoOwnerController.text.trim();
                                  final name = _repoNameController.text.trim();
                                  if (owner.isEmpty || name.isEmpty) return;
                                  final pat = _patController.text.trim();
                                  final success = await ghProvider.connectRepo(
                                    projectId: projectId,
                                    repoOwner: owner,
                                    repoName: name,
                                    accessToken: pat.isEmpty ? null : pat,
                                  );
                                  if (success && mounted) {
                                    setState(() => _showConnectForm = false);
                                    _repoOwnerController.clear();
                                    _repoNameController.clear();
                                    _patController.clear();
                                  }
                                },
                          child: ghProvider.isLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('연결'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.7)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }

  // ── 커밋 다이얼로그 ──
  void _showCommitsDialog(BuildContext context, String projectId, ColorScheme colorScheme) async {
    final ghProvider = context.read<GitHubProvider>();
    await ghProvider.loadBranches(projectId);
    await ghProvider.loadCommits(projectId);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _GitHubListDialog(
        title: '커밋 목록',
        projectId: projectId,
        type: _GitHubDialogType.commits,
      ),
    );
  }

  void _showBranchesDialog(BuildContext context, String projectId, ColorScheme colorScheme) async {
    final ghProvider = context.read<GitHubProvider>();
    await ghProvider.loadBranches(projectId);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _GitHubListDialog(
        title: '브랜치 목록',
        projectId: projectId,
        type: _GitHubDialogType.branches,
      ),
    );
  }

  void _showPRsDialog(BuildContext context, String projectId, ColorScheme colorScheme) async {
    final ghProvider = context.read<GitHubProvider>();
    await ghProvider.loadPullRequests(projectId);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _GitHubListDialog(
        title: 'Pull Requests',
        projectId: projectId,
        type: _GitHubDialogType.pullRequests,
      ),
    );
  }

  // ── 팀원별 업무 현황 섹션 ──
  Widget _buildMemberWorkloadSection(List<Task> allTasks, ColorScheme colorScheme) {
    if (_teamMembers.isEmpty && !_loadingMembers) {
      return const SizedBox.shrink();
    }

    // 팀원별 태스크 그룹핑
    final Map<String, List<Task>> tasksByMember = {};
    for (final member in _teamMembers) {
      tasksByMember[member.id] = allTasks
          .where((t) => t.assignedMemberIds.contains(member.id))
          .toList();
    }

    // 미할당 태스크
    final unassignedTasks = allTasks.where((t) => t.assignedMemberIds.isEmpty).toList();

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
          Text('팀원별 업무 현황',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 16),

          if (_loadingMembers)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            // 팀원별 업무 카드들
            ...List.generate(_teamMembers.length, (i) {
              final member = _teamMembers[i];
              final memberTasks = tasksByMember[member.id] ?? [];
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: _buildMemberWorkloadCard(member, memberTasks, colorScheme),
              );
            }),

            // 미할당 태스크
            if (unassignedTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildUnassignedCard(unassignedTasks, colorScheme),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMemberWorkloadCard(User member, List<Task> tasks, ColorScheme colorScheme) {
    final project = context.read<ProjectProvider>().currentProject;
    final isCreator = project?.creatorId == member.id;

    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    final inProgress = tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final inReview = tasks.where((t) => t.status == TaskStatus.inReview).length;
    final ready = tasks.where((t) => t.status == TaskStatus.ready).length;
    final backlog = tasks.where((t) => t.status == TaskStatus.backlog).length;
    final total = tasks.length;
    final donePercent = total > 0 ? (done / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 팀원 헤더 + 통계 요약
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AvatarColor.getColorForUser(member.username),
                backgroundImage: member.profileImageUrl != null ? NetworkImage(member.profileImageUrl!) : null,
                child: member.profileImageUrl == null
                    ? Text(member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 10),
              Text(member.username,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
              if (isCreator) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text('PM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                ),
              ],
              const Spacer(),
              // 요약 뱃지들
              _buildCountBadge('$total건', colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
              const SizedBox(width: 6),
              if (total > 0)
                Text('${donePercent.toStringAsFixed(0)}% 완료',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade600, fontWeight: FontWeight.w600)),
            ],
          ),

          if (total > 0) ...[
            const SizedBox(height: 10),

            // 상태별 미니 바
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    if (done > 0) Flexible(flex: done, child: Container(color: Colors.green)),
                    if (inReview > 0) Flexible(flex: inReview, child: Container(color: Colors.purple)),
                    if (inProgress > 0) Flexible(flex: inProgress, child: Container(color: Colors.orange)),
                    if (ready > 0) Flexible(flex: ready, child: Container(color: Colors.blue.shade300)),
                    if (backlog > 0) Flexible(flex: backlog, child: Container(color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 상태별 카운트 라벨
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (inProgress > 0) _buildStatusLabel('진행 중', inProgress, Colors.orange),
                if (inReview > 0) _buildStatusLabel('검토', inReview, Colors.purple),
                if (ready > 0) _buildStatusLabel('준비', ready, Colors.blue.shade300),
                if (backlog > 0) _buildStatusLabel('백로그', backlog, Colors.grey),
                if (done > 0) _buildStatusLabel('완료', done, Colors.green),
              ],
            ),

            const SizedBox(height: 10),

            // 진행 중/검토 중인 태스크 상세 (핵심 업무 파악)
            ..._buildActiveTasks(tasks, colorScheme),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('할당된 작업 없음',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.4))),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildActiveTasks(List<Task> tasks, ColorScheme colorScheme) {
    // 진행 중 > 검토 중 > 준비됨 순으로 현재 활성 태스크만 보여줌
    final activeTasks = tasks
        .where((t) => t.status == TaskStatus.inProgress || t.status == TaskStatus.inReview || t.status == TaskStatus.ready)
        .toList();

    if (activeTasks.isEmpty) return [];

    // 우선순위 정렬: 진행중 > 검토 > 준비, 같은 상태면 priority 순
    activeTasks.sort((a, b) {
      final statusOrder = {TaskStatus.inProgress: 0, TaskStatus.inReview: 1, TaskStatus.ready: 2};
      final cmp = (statusOrder[a.status] ?? 3).compareTo(statusOrder[b.status] ?? 3);
      if (cmp != 0) return cmp;
      return a.priority.index.compareTo(b.priority.index);
    });

    // 최대 5개까지만 표시
    final displayTasks = activeTasks.take(5).toList();

    return [
      Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
      const SizedBox(height: 8),
      ...displayTasks.map((task) {
        final statusColor = _getStatusColor(task.status);
        final priorityColor = _getPriorityColor(task.priority);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  task.priority.name.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: priorityColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _getStatusLabel(task.status),
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }),
      if (activeTasks.length > 5)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '외 ${activeTasks.length - 5}건',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.4)),
          ),
        ),
    ];
  }

  Widget _buildUnassignedCard(List<Task> tasks, ColorScheme colorScheme) {
    final total = tasks.length;
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    final active = tasks.where((t) =>
        t.status == TaskStatus.inProgress || t.status == TaskStatus.inReview).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_off_outlined, size: 20, color: Colors.orange.shade400),
          const SizedBox(width: 10),
          Text('미할당', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
          const Spacer(),
          _buildCountBadge('$total건', Colors.orange.shade100, Colors.orange.shade800),
          const SizedBox(width: 8),
          if (active > 0)
            Text('$active건 진행 중', style: TextStyle(fontSize: 11, color: Colors.orange.shade600)),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildStatusLabel(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label $count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.done: return Colors.green;
      case TaskStatus.inReview: return Colors.purple;
      case TaskStatus.inProgress: return Colors.orange;
      case TaskStatus.ready: return Colors.blue.shade300;
      case TaskStatus.backlog: return Colors.grey;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.p0: return Colors.red;
      case TaskPriority.p1: return Colors.orange;
      case TaskPriority.p2: return Colors.blue;
      case TaskPriority.p3: return Colors.grey;
    }
  }

  String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.done: return '완료';
      case TaskStatus.inReview: return '검토 중';
      case TaskStatus.inProgress: return '진행 중';
      case TaskStatus.ready: return '준비됨';
      case TaskStatus.backlog: return '백로그';
    }
  }
}

enum _GitHubDialogType { commits, branches, pullRequests }

class _GitHubListDialog extends StatefulWidget {
  final String title;
  final String projectId;
  final _GitHubDialogType type;

  const _GitHubListDialog({
    required this.title,
    required this.projectId,
    required this.type,
  });

  @override
  State<_GitHubListDialog> createState() => _GitHubListDialogState();
}

class _GitHubListDialogState extends State<_GitHubListDialog> {
  String _prFilter = 'open';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 500,
        child: Consumer<GitHubProvider>(
          builder: (context, ghProvider, _) {
            return Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Text(widget.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      const Spacer(),
                      // 커밋 탭: 브랜치 선택
                      if (widget.type == _GitHubDialogType.commits && ghProvider.branches.isNotEmpty)
                        DropdownButton<String?>(
                          value: ghProvider.selectedBranch,
                          hint: const Text('브랜치'),
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('전체')),
                            ...ghProvider.branches.map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))),
                          ],
                          onChanged: (v) {
                            ghProvider.selectBranch(v);
                            ghProvider.loadCommits(widget.projectId, branch: v);
                          },
                        ),
                      // PR 탭: 상태 필터
                      if (widget.type == _GitHubDialogType.pullRequests)
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'open', label: Text('Open')),
                            ButtonSegment(value: 'closed', label: Text('Closed')),
                            ButtonSegment(value: 'all', label: Text('All')),
                          ],
                          selected: {_prFilter},
                          onSelectionChanged: (v) {
                            setState(() => _prFilter = v.first);
                            ghProvider.loadPullRequests(widget.projectId, state: v.first);
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                // 내용
                Expanded(
                  child: ghProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildList(ghProvider, colorScheme),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(GitHubProvider ghProvider, ColorScheme colorScheme) {
    switch (widget.type) {
      case _GitHubDialogType.commits:
        if (ghProvider.commits.isEmpty) return const Center(child: Text('커밋이 없습니다'));
        return ListView.builder(
          itemCount: ghProvider.commits.length + (ghProvider.hasMoreCommits ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == ghProvider.commits.length) {
              return Center(
                child: TextButton(
                  onPressed: () => ghProvider.loadMoreCommits(widget.projectId),
                  child: const Text('더 불러오기'),
                ),
              );
            }
            final commit = ghProvider.commits[i];
            return ListTile(
              dense: true,
              leading: commit.authorAvatarUrl != null
                  ? CircleAvatar(radius: 16, backgroundImage: NetworkImage(commit.authorAvatarUrl!))
                  : CircleAvatar(radius: 16, child: Text(commit.authorName.isNotEmpty ? commit.authorName[0] : '?')),
              title: Text(commit.firstLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${commit.authorName} · ${commit.shortSha} · ${_formatDate(commit.date)}',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              onTap: () async {
                final uri = Uri.parse(commit.url);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            );
          },
        );

      case _GitHubDialogType.branches:
        if (ghProvider.branches.isEmpty) return const Center(child: Text('브랜치가 없습니다'));
        return ListView.builder(
          itemCount: ghProvider.branches.length,
          itemBuilder: (ctx, i) {
            final branch = ghProvider.branches[i];
            return ListTile(
              dense: true,
              leading: Icon(Icons.account_tree_outlined, size: 20, color: colorScheme.primary),
              title: Text(branch.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              trailing: Text(branch.shortSha, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5), fontFamily: 'monospace')),
            );
          },
        );

      case _GitHubDialogType.pullRequests:
        if (ghProvider.pullRequests.isEmpty) return const Center(child: Text('PR이 없습니다'));
        return ListView.builder(
          itemCount: ghProvider.pullRequests.length + (ghProvider.hasMorePRs ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == ghProvider.pullRequests.length) {
              return Center(
                child: TextButton(
                  onPressed: () => ghProvider.loadMorePullRequests(widget.projectId),
                  child: const Text('더 불러오기'),
                ),
              );
            }
            final pr = ghProvider.pullRequests[i];
            final stateColor = pr.state == 'open' ? Colors.green : Colors.red.shade400;
            return ListTile(
              dense: true,
              leading: pr.authorAvatarUrl != null
                  ? CircleAvatar(radius: 16, backgroundImage: NetworkImage(pr.authorAvatarUrl!))
                  : CircleAvatar(radius: 16, child: Text(pr.author.isNotEmpty ? pr.author[0] : '?')),
              title: Row(
                children: [
                  Expanded(child: Text(pr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: stateColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(pr.state, style: TextStyle(fontSize: 10, color: stateColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Text(
                '#${pr.number} · ${pr.author} · ${pr.headBranch} → ${pr.baseBranch}',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              onTap: () async {
                final uri = Uri.parse(pr.url);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            );
          },
        );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
