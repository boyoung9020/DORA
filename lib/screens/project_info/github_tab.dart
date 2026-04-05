import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/github.dart';
import '../../providers/github_provider.dart';
import '../../utils/tech_stack_devicon.dart';
import '../../widgets/project_info/github_commits_graph_table.dart';
import '../../widgets/project_info/github_contribution_heatmap.dart';
import '../../widgets/project_info/github_panel_widgets.dart';
import '../../widgets/project_info/github_repo_connect_dialog.dart';

/// 프로젝트 정보 — GitHub 전용 탭 (스크롤 없이 한 화면 레이아웃)
class GitHubTab extends StatefulWidget {
  final String projectId;

  const GitHubTab({
    super.key,
    required this.projectId,
  });

  @override
  State<GitHubTab> createState() => _GitHubTabState();
}

class _GitHubTabState extends State<GitHubTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didUpdateWidget(GitHubTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }
  }

  Future<void> _bootstrap() async {
    final gh = context.read<GitHubProvider>();
    await gh.loadMyTokenStatus();
    await gh.loadRepoInfo(widget.projectId);
    if (!mounted) return;
    if (gh.connectedRepo != null) {
      await Future.wait([
        gh.loadBranches(widget.projectId),
        gh.loadLanguages(widget.projectId),
        gh.loadTags(widget.projectId),
        gh.loadReleases(widget.projectId),
        gh.loadRepoRemoteDetails(widget.projectId),
      ]);
      if (!mounted) return;
      await Future.wait([
        gh.loadCommits(widget.projectId, showGlobalLoading: false),
        gh.loadPullRequests(widget.projectId, showGlobalLoading: false),
        gh.loadCommitActivityHeatmap(widget.projectId),
      ]);
    }
  }

  Future<void> _refreshCommitsAndHeatmap() async {
    final gh = context.read<GitHubProvider>();
    await Future.wait([
      gh.loadCommitActivityHeatmap(widget.projectId),
      gh.loadCommits(widget.projectId, showGlobalLoading: false),
    ]);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showConnectDialog(
      BuildContext context, GitHubProvider gh, ColorScheme cs) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => GitHubRepoConnectDialog(
        ghProvider: gh,
        projectId: widget.projectId,
        colorScheme: cs,
      ),
    );
  }

  Future<void> _confirmDisconnect(
      BuildContext context, GitHubProvider gh, GitHubRepo repo) async {
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
      await gh.disconnectRepo(widget.projectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, gh, _) {
        if (!gh.repoInfoLoaded && gh.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final repo = gh.connectedRepo;
        if (repo == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off,
                      size: 48, color: cs.onSurface.withValues(alpha: 0.25)),
                  const SizedBox(height: 12),
                  Text('연결된 레포 없음',
                      style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface.withValues(alpha: 0.55))),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: gh.isLoading
                        ? null
                        : () async {
                            if (!gh.userTokenStatusLoaded) {
                              await gh.loadMyTokenStatus();
                            }
                            if (gh.hasUserToken && gh.myRepos.isEmpty) {
                              await gh.loadMyRepos();
                            }
                            if (!context.mounted) return;
                            _showConnectDialog(context, gh, cs);
                          },
                    icon: gh.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_link),
                    label: const Text('레포 연결'),
                  ),
                ],
              ),
            ),
          );
        }

        final meta = gh.repoRemoteDetails;
        final base = 'https://github.com/${repo.repoOwner}/${repo.repoName}';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 헤더 (한 줄) ──────────────────────────────────────────
              _compactHeader(context, gh, repo, meta, base, cs),
              const SizedBox(height: 8),
              // ── 메인 콘텐츠 ──────────────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 왼쪽: 잔디 + 브랜치 + 커밋 그래프
                    Expanded(
                      flex: 3,
                      child: _leftPanel(gh, cs),
                    ),
                    const SizedBox(width: 12),
                    // 오른쪽: 태그 + PR
                    Expanded(
                      flex: 2,
                      child: _rightPanel(gh, repo, cs),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // ── 언어 스택 바 (한 줄) ──────────────────────────────────
              _compactLanguageRow(gh, cs),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 헤더: 레포명 + 메타 + 외부 링크 아이콘 + 새로고침 + 연결 해제
  // ────────────────────────────────────────────────────────────────────────
  Widget _compactHeader(
    BuildContext context,
    GitHubProvider gh,
    GitHubRepo repo,
    GitHubRepoRemoteDetails? meta,
    String base,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.code, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _launch(
                meta?.htmlUrl.isNotEmpty == true ? meta!.htmlUrl : base),
            child: Text(
              repo.fullName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (meta != null) ...[
            _metaChip(cs, Icons.star_outline, '${meta.stargazersCount}'),
            const SizedBox(width: 8),
            _metaChip(cs, Icons.device_hub_outlined, '${meta.forksCount}'),
            const SizedBox(width: 8),
            _metaChip(cs, Icons.alt_route, meta.defaultBranch),
            const SizedBox(width: 8),
            _metaChip(
                cs, Icons.bug_report_outlined, '${meta.openIssuesCount}'),
          ],
          const Spacer(),
          // 빠른 링크 아이콘
          _linkIconBtn(Icons.bug_report_outlined, '$base/issues', 'Issues'),
          _linkIconBtn(Icons.merge_type, '$base/pulls', 'Pull requests'),
          _linkIconBtn(Icons.play_circle_outline, '$base/actions', 'Actions'),
          const SizedBox(width: 4),
          // 새로고침
          SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: '새로고침',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _bootstrap,
            ),
          ),
          // 연결 해제
          SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: '연결 해제',
              icon: Icon(Icons.link_off, size: 18, color: Colors.red.shade400),
              onPressed: () => _confirmDisconnect(context, gh, repo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(ColorScheme cs, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _linkIconBtn(IconData icon, String url, String tooltip) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        icon: Icon(icon, size: 17),
        onPressed: () => _launch(url),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 왼쪽 패널: 잔디 + 브랜치 선택 + 커밋 그래프
  // ────────────────────────────────────────────────────────────────────────
  Widget _leftPanel(GitHubProvider gh, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 잔디 (heatmap)
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GitHubContributionHeatmap(
                  countByDay: gh.commitActivityByDay,
                  loading: gh.commitHeatmapLoading,
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '커밋·잔디 새로고침',
                  onPressed: _refreshCommitsAndHeatmap,
                  icon: const Icon(Icons.refresh, size: 17),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // 브랜치 선택
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                'Branch:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              if (gh.branches.isNotEmpty)
                GitHubBranchSelectorDropdown(
                  projectId: widget.projectId,
                  quietRefresh: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // 커밋 그래프
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: GitHubCommitsGraphTable(projectId: widget.projectId),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 오른쪽 패널: 태그 (상단) + PR (하단)
  // ────────────────────────────────────────────────────────────────────────
  Widget _rightPanel(
      GitHubProvider gh, GitHubRepo repo, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 릴리즈
        Row(
          children: [
            Icon(Icons.rocket_launch_outlined, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('Releases',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          flex: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(10),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: GitHubTagsSidePanel(
                projectId: widget.projectId,
                repoOwner: repo.repoOwner,
                repoName: repo.repoName,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // PR
        Row(
          children: [
            Icon(Icons.merge_type, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('Pull requests',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const Spacer(),
            GitHubPRFilterSegmented(
              projectId: widget.projectId,
              quietRefresh: true,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          flex: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: GitHubPullRequestsList(
                projectId: widget.projectId,
                padding: const EdgeInsets.symmetric(vertical: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 언어 스택 바: 가로로 한 줄에 모두 표시
  // ────────────────────────────────────────────────────────────────────────
  Widget _compactLanguageRow(GitHubProvider gh, ColorScheme cs) {
    if (gh.languagesLoading && gh.languages.isEmpty) {
      return const SizedBox(
        height: 20,
        child: LinearProgressIndicator(),
      );
    }
    if (gh.languages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 스택 바
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: gh.languages.map((l) {
                final color = techStackLanguageColor(l.name);
                return Flexible(
                  flex: (l.percentage * 10).round().clamp(1, 1000),
                  child: Container(color: color.withValues(alpha: 0.85)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 범례 (작은 점 + 이름 + %)
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: gh.languages.map((l) {
            final color = techStackLanguageColor(l.name);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${l.name} ${l.percentage.toStringAsFixed(l.percentage >= 10 ? 0 : 1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
