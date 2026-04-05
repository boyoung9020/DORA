import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/github_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'git_graph_painter.dart';

enum GitHubDialogType { commits, branches, pullRequests }

class GitHubListDialog extends StatefulWidget {
  final String title;
  final String projectId;
  final GitHubDialogType type;

  const GitHubListDialog({
    super.key,
    required this.title,
    required this.projectId,
    required this.type,
  });

  @override
  State<GitHubListDialog> createState() => _GitHubListDialogState();
}

class _GitHubListDialogState extends State<GitHubListDialog> {
  String _prFilter = 'open';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCommits = widget.type == GitHubDialogType.commits;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: isCommits ? 800 : 600,
        height: 560,
        child: Consumer<GitHubProvider>(
          builder: (context, ghProvider, _) {
            return Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Text(widget.title,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface)),
                      const Spacer(),
                      if (isCommits && ghProvider.branches.isNotEmpty)
                        _buildBranchSelector(ghProvider),
                      if (widget.type == GitHubDialogType.pullRequests)
                        _buildPRFilter(ghProvider),
                      const SizedBox(width: 8),
                      IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
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

  Widget _buildBranchSelector(GitHubProvider ghProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String?>(
        value: ghProvider.selectedBranch,
        hint: const Text('전체 브랜치', style: TextStyle(fontSize: 13)),
        underline: const SizedBox.shrink(),
        isDense: true,
        style: TextStyle(
            fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
        items: [
          const DropdownMenuItem(value: null, child: Text('전체')),
          ...ghProvider.branches.map((b) =>
              DropdownMenuItem(value: b.name, child: Text(b.name))),
        ],
        onChanged: (v) {
          ghProvider.selectBranch(v);
          ghProvider.loadCommits(widget.projectId, branch: v);
        },
      ),
    );
  }

  Widget _buildPRFilter(GitHubProvider ghProvider) {
    return SegmentedButton<String>(
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
    );
  }

  Widget _buildList(GitHubProvider ghProvider, ColorScheme colorScheme) {
    switch (widget.type) {
      case GitHubDialogType.commits:
        return _buildCommitGraph(ghProvider, colorScheme);
      case GitHubDialogType.branches:
        return _buildBranches(ghProvider, colorScheme);
      case GitHubDialogType.pullRequests:
        return _buildPRs(ghProvider, colorScheme);
    }
  }

  // ── 커밋 그래프 뷰 ──────────────────────────────────────
  Widget _buildCommitGraph(GitHubProvider ghProvider, ColorScheme colorScheme) {
    final commits = ghProvider.commits;
    if (commits.isEmpty) {
      return const Center(child: Text('커밋이 없습니다'));
    }

    final layout = GitGraphLayout.compute(commits);
    const rowHeight = 52.0;
    const laneWidth = 16.0;
    final graphWidth = (layout.maxLane + 1) * laneWidth + 20;

    return ListView.builder(
      itemCount: commits.length + (ghProvider.hasMoreCommits ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == commits.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => ghProvider.loadMoreCommits(widget.projectId),
                icon: const Icon(Icons.expand_more, size: 16),
                label: const Text('더 불러오기', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          );
        }

        final commit = commits[i];
        final node = layout.nodes[i];
        final isMerge = commit.parents.length > 1;
        final laneColor = GitGraphLayout.colorForLane(node.lane);

        return InkWell(
          onTap: () async {
            final uri = Uri.parse(commit.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                // 그래프 영역
                SizedBox(
                  width: graphWidth,
                  child: CustomPaint(
                    painter: GitGraphPainter(
                      layout: layout,
                      rowHeight: rowHeight,
                      laneWidth: laneWidth,
                      startRow: i,
                      endRow: (i + 2).clamp(0, commits.length),
                    ),
                    size: Size(graphWidth, rowHeight),
                  ),
                ),

                // 커밋 정보 영역
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            if (isMerge)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: laneColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color:
                                          laneColor.withValues(alpha: 0.3)),
                                ),
                                child: Text('merge',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: laneColor)),
                              ),
                            Expanded(
                              child: Text(
                                commit.firstLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // 아바타
                            if (commit.authorAvatarUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundImage:
                                      NetworkImage(commit.authorAvatarUrl!),
                                ),
                              ),
                            Text(
                              commit.authorName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                commit.shortSha,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(commit.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 브랜치 뷰 ──────────────────────────────────────────
  Widget _buildBranches(GitHubProvider ghProvider, ColorScheme colorScheme) {
    if (ghProvider.branches.isEmpty) {
      return const Center(child: Text('브랜치가 없습니다'));
    }
    return ListView.builder(
      itemCount: ghProvider.branches.length,
      itemBuilder: (ctx, i) {
        final branch = ghProvider.branches[i];
        return ListTile(
          dense: true,
          leading: Icon(Icons.account_tree_outlined,
              size: 20, color: colorScheme.primary),
          title: Text(branch.name,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          trailing: Text(branch.shortSha,
              style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontFamily: 'monospace')),
        );
      },
    );
  }

  // ── PR 뷰 ──────────────────────────────────────────────
  Widget _buildPRs(GitHubProvider ghProvider, ColorScheme colorScheme) {
    if (ghProvider.pullRequests.isEmpty) {
      return const Center(child: Text('PR이 없습니다'));
    }
    return ListView.builder(
      itemCount:
          ghProvider.pullRequests.length + (ghProvider.hasMorePRs ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == ghProvider.pullRequests.length) {
          return Center(
            child: TextButton(
              onPressed: () =>
                  ghProvider.loadMorePullRequests(widget.projectId),
              child: const Text('더 불러오기'),
            ),
          );
        }
        final pr = ghProvider.pullRequests[i];
        final stateColor =
            pr.state == 'open' ? Colors.green : Colors.red.shade400;
        return ListTile(
          dense: true,
          leading: pr.authorAvatarUrl != null
              ? CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(pr.authorAvatarUrl!))
              : CircleAvatar(
                  radius: 16,
                  child:
                      Text(pr.author.isNotEmpty ? pr.author[0] : '?')),
          title: Row(
            children: [
              Expanded(
                  child: Text(pr.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(pr.state,
                    style: TextStyle(
                        fontSize: 10,
                        color: stateColor,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          subtitle: Text(
            '#${pr.number} · ${pr.author} · ${pr.headBranch} → ${pr.baseBranch}',
            style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          onTap: () async {
            final uri = Uri.parse(pr.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );
      },
    );
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
