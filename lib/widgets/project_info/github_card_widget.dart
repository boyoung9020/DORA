import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/github_provider.dart';
import '../../widgets/glass_container.dart';
import 'github_list_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class GitHubCard extends StatefulWidget {
  final String projectId;
  final bool isPM;

  const GitHubCard({super.key, required this.projectId, required this.isPM});

  @override
  State<GitHubCard> createState() => _GitHubCardState();
}

class _GitHubCardState extends State<GitHubCard> {
  final _repoOwnerController = TextEditingController();
  final _repoNameController = TextEditingController();
  final _patController = TextEditingController();
  bool _showConnectForm = false;

  @override
  void dispose() {
    _repoOwnerController.dispose();
    _repoNameController.dispose();
    _patController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                  Text('GitHub 연동',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface)),
                  const Spacer(),
                  if (repo != null)
                    IconButton(
                      icon: Icon(Icons.link_off,
                          size: 18, color: Colors.red.shade400),
                      tooltip: '연결 해제',
                      onPressed: () => _confirmDisconnect(context, ghProvider, repo),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (ghProvider.isLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (repo != null) ...[
                _buildConnectedRepo(context, repo, colorScheme, ghProvider),
              ] else ...[
                _buildDisconnectedState(context, ghProvider, colorScheme),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmDisconnect(BuildContext context, GitHubProvider ghProvider,
      dynamic repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GitHub 연결 해제'),
        content: Text('${repo.fullName} 연결을 해제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('해제', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ghProvider.disconnectRepo(widget.projectId);
    }
  }

  Widget _buildConnectedRepo(BuildContext context, dynamic repo,
      ColorScheme colorScheme, GitHubProvider ghProvider) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final uri = Uri.parse(
                'https://github.com/${repo.repoOwner}/${repo.repoName}');
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
                      Text(repo.fullName,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.open_in_new,
                              size: 12,
                              color: colorScheme.primary.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text('GitHub에서 열기',
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      colorScheme.primary.withValues(alpha: 0.7))),
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
        Row(
          children: [
            _quickActionButton(
              icon: Icons.commit,
              label: '커밋',
              onTap: () => _showCommitsDialog(context),
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 8),
            _quickActionButton(
              icon: Icons.account_tree_outlined,
              label: '브랜치',
              onTap: () => _showBranchesDialog(context),
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 8),
            _quickActionButton(
              icon: Icons.merge,
              label: 'PR',
              onTap: () => _showPRsDialog(context),
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
                Text('PAT 연결됨',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDisconnectedState(BuildContext context,
      GitHubProvider ghProvider, ColorScheme colorScheme) {
    if (!_showConnectForm) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.link_off,
                size: 40, color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('연결된 GitHub 레포가 없습니다',
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(() => _showConnectForm = true),
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('레포 연결'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
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
            child: Text(ghProvider.errorMessage!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
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
                          projectId: widget.projectId,
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('연결'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionButton({
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
              Icon(icon,
                  size: 20, color: colorScheme.onSurface.withValues(alpha: 0.7)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommitsDialog(BuildContext ctx) async {
    final ghProvider = ctx.read<GitHubProvider>();
    final nav = Navigator.of(ctx);
    await ghProvider.loadBranches(widget.projectId);
    await ghProvider.loadCommits(widget.projectId);
    if (!mounted) return;
    nav.push(DialogRoute(
      context: nav.context,
      builder: (_) => GitHubListDialog(
        title: '커밋 목록',
        projectId: widget.projectId,
        type: GitHubDialogType.commits,
      ),
    ));
  }

  void _showBranchesDialog(BuildContext ctx) async {
    final ghProvider = ctx.read<GitHubProvider>();
    final nav = Navigator.of(ctx);
    await ghProvider.loadBranches(widget.projectId);
    if (!mounted) return;
    nav.push(DialogRoute(
      context: nav.context,
      builder: (_) => GitHubListDialog(
        title: '브랜치 목록',
        projectId: widget.projectId,
        type: GitHubDialogType.branches,
      ),
    ));
  }

  void _showPRsDialog(BuildContext ctx) async {
    final ghProvider = ctx.read<GitHubProvider>();
    final nav = Navigator.of(ctx);
    await ghProvider.loadPullRequests(widget.projectId);
    if (!mounted) return;
    nav.push(DialogRoute(
      context: nav.context,
      builder: (_) => GitHubListDialog(
        title: 'Pull Requests',
        projectId: widget.projectId,
        type: GitHubDialogType.pullRequests,
      ),
    ));
  }
}
