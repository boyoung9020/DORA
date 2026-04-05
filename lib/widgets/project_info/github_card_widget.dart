import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/github_provider.dart';
import '../../widgets/glass_container.dart';
import 'git_graph_painter.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gh = context.read<GitHubProvider>();
      await gh.loadMyTokenStatus();
      if (gh.connectedRepo != null) {
        if (gh.branches.isEmpty) gh.loadBranches(widget.projectId);
        if (gh.commits.isEmpty) gh.loadCommits(widget.projectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, ghProvider, _) {
        final repo = ghProvider.connectedRepo;
        return GlassContainer(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 10),
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
    // 브랜치/커밋 미로드 시 자동 로드
    if ((ghProvider.branches.isEmpty || ghProvider.commits.isEmpty) &&
        !ghProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ghProvider.branches.isEmpty) ghProvider.loadBranches(widget.projectId);
        if (ghProvider.commits.isEmpty) ghProvider.loadCommits(widget.projectId);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 레포명 한 줄 컴팩트
        InkWell(
          onTap: () async {
            final uri = Uri.parse(
                'https://github.com/${repo.repoOwner}/${repo.repoName}');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.code, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(repo.fullName,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.open_in_new,
                    size: 13,
                    color: colorScheme.primary.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 브랜치 인라인 표시
        _buildBranchSection(context, colorScheme, ghProvider),

        const SizedBox(height: 12),

        // 최근 커밋 인라인 표시
        _buildRecentCommits(context, colorScheme, ghProvider),

        const SizedBox(height: 10),

        // 커밋 전체보기 / PR 버튼
        Row(
          children: [
            _quickActionButton(
              icon: Icons.commit,
              label: '커밋 전체보기',
              onTap: () => _showCommitsDialog(context),
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 6),
            _quickActionButton(
              icon: Icons.merge,
              label: 'PR',
              onTap: () => _showPRsDialog(context),
              colorScheme: colorScheme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentCommits(BuildContext context, ColorScheme colorScheme,
      GitHubProvider ghProvider) {
    final commits = ghProvider.commits;

    if (ghProvider.isLoading && commits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5)),
          const SizedBox(width: 8),
          Text('커밋 로딩 중…',
              style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.4))),
        ]),
      );
    }
    if (commits.isEmpty) return const SizedBox.shrink();

    const maxRows = 6;
    const rowH = 40.0;
    const laneW = 14.0;

    final visible = commits.take(maxRows).toList();
    final layout = GitGraphLayout.compute(visible);
    final graphW = (layout.maxLane + 1) * laneW + 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.commit,
                size: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            Text('최근 커밋',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
            const Spacer(),
            GestureDetector(
              onTap: () => _showCommitsDialog(context),
              child: Text('전체보기',
                  style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.primary.withValues(alpha: 0.7))),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 그래프 + 커밋 목록
        SizedBox(
          height: rowH * visible.length,
          child: Row(
            children: [
              // 왼쪽: 그래프
              SizedBox(
                width: graphW,
                child: CustomPaint(
                  painter: GitGraphPainter(
                    layout: layout,
                    rowHeight: rowH,
                    laneWidth: laneW,
                    nodeRadius: 4.0,
                  ),
                ),
              ),
              // 오른쪽: 커밋 정보
              Expanded(
                child: Column(
                  children: List.generate(visible.length, (i) {
                    final commit = visible[i];
                    final isMerge = commit.parents.length > 1;
                    final laneColor = GitGraphLayout.colorForLane(
                        layout.nodes[i].lane);
                    return SizedBox(
                      height: rowH,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              if (isMerge)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: laneColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text('merge',
                                      style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: laneColor)),
                                ),
                              Expanded(
                                child: Text(
                                  commit.firstLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text(
                                commit.authorName,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.45)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                commit.shortSha,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.35)),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchSection(BuildContext context, ColorScheme colorScheme,
      GitHubProvider ghProvider) {
    final branches = ghProvider.branches;

    if (ghProvider.isLoading && branches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 8),
            Text('브랜치 로딩 중…',
                style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.45))),
          ],
        ),
      );
    }

    if (branches.isEmpty) {
      return const SizedBox.shrink();
    }

    // 최대 5개 표시, 나머지는 +N
    const maxVisible = 5;
    final visible = branches.take(maxVisible).toList();
    final extra = branches.length - maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_tree_outlined,
                size: 13, color: colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            Text('브랜치',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
            const Spacer(),
            if (branches.length > maxVisible)
              GestureDetector(
                onTap: () => _showBranchesDialog(context),
                child: Text('+$extra 더보기',
                    style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.primary.withValues(alpha: 0.7))),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: visible.map((b) {
            final isMain =
                b.name == 'main' || b.name == 'master' || b.name == 'develop';
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMain
                    ? colorScheme.primary.withValues(alpha: 0.08)
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isMain
                      ? colorScheme.primary.withValues(alpha: 0.25)
                      : colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMain)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(Icons.star_rounded,
                          size: 10, color: colorScheme.primary),
                    ),
                  Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isMain ? FontWeight.w600 : FontWeight.normal,
                      color: isMain
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDisconnectedState(BuildContext context,
      GitHubProvider ghProvider, ColorScheme colorScheme) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.link_off,
              size: 28, color: colorScheme.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 6),
          Text('연결된 레포 없음',
              style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.45))),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: ghProvider.isLoading
                ? null
                : () async {
                    if (!ghProvider.userTokenStatusLoaded) {
                      await ghProvider.loadMyTokenStatus();
                    }
                    if (ghProvider.hasUserToken && ghProvider.myRepos.isEmpty) {
                      await ghProvider.loadMyRepos();
                    }
                    if (!context.mounted) return;
                    _showRepoConnectDialog(context, ghProvider, colorScheme);
                  },
            icon: ghProvider.isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_link, size: 18),
            label: const Text('레포 연결'),
          ),
        ],
      ),
    );
  }

  void _showRepoConnectDialog(BuildContext context, GitHubProvider ghProvider,
      ColorScheme colorScheme) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => _RepoConnectDialog(
        ghProvider: ghProvider,
        projectId: widget.projectId,
        colorScheme: colorScheme,
      ),
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

class _RepoConnectDialog extends StatefulWidget {
  final GitHubProvider ghProvider;
  final String projectId;
  final ColorScheme colorScheme;

  const _RepoConnectDialog({
    required this.ghProvider,
    required this.projectId,
    required this.colorScheme,
  });

  @override
  State<_RepoConnectDialog> createState() => _RepoConnectDialogState();
}

class _RepoConnectDialogState extends State<_RepoConnectDialog> {
  final _searchCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _selectedFullName;
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.ghProvider.myRepos;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ownerCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final repos = widget.ghProvider.myRepos;
    setState(() {
      _filtered = q.isEmpty
          ? repos
          : repos
              .where((r) => (r['full_name'] as String)
                  .toLowerCase()
                  .contains(q.toLowerCase()))
              .toList();
    });
  }

  void _selectRepo(Map<String, dynamic> repo) {
    setState(() {
      _selectedFullName = repo['full_name'] as String;
      _ownerCtrl.text = repo['owner'] as String;
      _nameCtrl.text = repo['name'] as String;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ghProvider,
      builder: (context, _) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final cs = widget.colorScheme;
    final repos = widget.ghProvider.myRepos;
    final hasRepos = repos.isNotEmpty;
    final isLoading = widget.ghProvider.isLoading;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 헤더
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: cs.outline.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.code,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GitHub 레포 연결',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                          if (hasRepos)
                            Text('${repos.length}개의 레포에 접근 가능',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── 본문
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasRepos) ...[
                        // 검색창
                        TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearch,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: '레포 검색…',
                            prefixIcon: Icon(Icons.search,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.4)),
                            isDense: true,
                            filled: true,
                            fillColor: cs.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 레포 리스트
                        Flexible(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: cs.outline.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _filtered.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Center(
                                        child: Text('검색 결과 없음',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.4))),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: _filtered.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: cs.outline.withValues(alpha: 0.1),
                                      ),
                                      itemBuilder: (_, i) {
                                        final repo = _filtered[i];
                                        final fullName =
                                            repo['full_name'] as String;
                                        final isPrivate =
                                            repo['private'] == true;
                                        final isSelected =
                                            _selectedFullName == fullName;
                                        return Material(
                                          color: isSelected
                                              ? cs.primary.withValues(alpha: 0.07)
                                              : Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _selectRepo(repo),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 11),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? cs.primary
                                                              .withValues(alpha: 0.12)
                                                          : cs.surfaceContainerHighest
                                                              .withValues(alpha: 0.6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Icon(
                                                      isPrivate
                                                          ? Icons.lock_outline
                                                          : Icons.folder_outlined,
                                                      size: 14,
                                                      color: isSelected
                                                          ? cs.primary
                                                          : cs.onSurface
                                                              .withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          repo['name'] as String,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: isSelected
                                                                ? FontWeight.w600
                                                                : FontWeight
                                                                    .w500,
                                                            color: isSelected
                                                                ? cs.primary
                                                                : cs.onSurface,
                                                          ),
                                                        ),
                                                        Text(
                                                          repo['owner']
                                                              as String,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: cs.onSurface
                                                                .withValues(
                                                                    alpha: 0.45),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isPrivate)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange
                                                            .withValues(alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                4),
                                                      ),
                                                      child: Text('Private',
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                              color: Colors
                                                                  .orange.shade700)),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  AnimatedOpacity(
                                                    opacity:
                                                        isSelected ? 1.0 : 0.0,
                                                    duration: const Duration(
                                                        milliseconds: 150),
                                                    child: Icon(Icons.check_circle,
                                                        size: 18,
                                                        color: cs.primary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // 토큰 없음 — 수동 입력
                        TextField(
                          controller: _ownerCtrl,
                          decoration: InputDecoration(
                            labelText: 'Repository Owner',
                            hintText: 'e.g. octocat',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Repository Name',
                            hintText: 'e.g. Hello-World',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ],

                      if (widget.ghProvider.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(widget.ghProvider.errorMessage!,
                            style: TextStyle(
                                color: cs.error, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),

              // ── 하단 버튼
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: cs.outline.withValues(alpha: 0.12)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final owner = hasRepos
                                    ? _ownerCtrl.text.trim()
                                    : _ownerCtrl.text.trim();
                                final name = hasRepos
                                    ? _nameCtrl.text.trim()
                                    : _nameCtrl.text.trim();
                                if (owner.isEmpty || name.isEmpty) return;
                                final success =
                                    await widget.ghProvider.connectRepo(
                                  projectId: widget.projectId,
                                  repoOwner: owner,
                                  repoName: name,
                                );
                                if (success && context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.link, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedFullName != null
                                        ? '$_selectedFullName 연결'
                                        : '연결',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
