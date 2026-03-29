import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/github_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 500,
        child: Consumer<GitHubProvider>(
          builder: (context, ghProvider, _) {
            return Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Text(widget.title,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface)),
                      const Spacer(),
                      if (widget.type == GitHubDialogType.commits &&
                          ghProvider.branches.isNotEmpty)
                        DropdownButton<String?>(
                          value: ghProvider.selectedBranch,
                          hint: const Text('브랜치'),
                          underline: const SizedBox.shrink(),
                          isDense: true,
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
                      if (widget.type == GitHubDialogType.pullRequests)
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'open', label: Text('Open')),
                            ButtonSegment(value: 'closed', label: Text('Closed')),
                            ButtonSegment(value: 'all', label: Text('All')),
                          ],
                          selected: {_prFilter},
                          onSelectionChanged: (v) {
                            setState(() => _prFilter = v.first);
                            ghProvider.loadPullRequests(widget.projectId,
                                state: v.first);
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: WidgetStateProperty.all(
                                const TextStyle(fontSize: 12)),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                          icon: const Icon(Icons.close),
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

  Widget _buildList(GitHubProvider ghProvider, ColorScheme colorScheme) {
    switch (widget.type) {
      case GitHubDialogType.commits:
        if (ghProvider.commits.isEmpty) {
          return const Center(child: Text('커밋이 없습니다'));
        }
        return ListView.builder(
          itemCount:
              ghProvider.commits.length + (ghProvider.hasMoreCommits ? 1 : 0),
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
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(commit.authorAvatarUrl!))
                  : CircleAvatar(
                      radius: 16,
                      child: Text(commit.authorName.isNotEmpty
                          ? commit.authorName[0]
                          : '?')),
              title: Text(commit.firstLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${commit.authorName} · ${commit.shortSha} · ${_formatDate(commit.date)}',
                style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              onTap: () async {
                final uri = Uri.parse(commit.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            );
          },
        );

      case GitHubDialogType.branches:
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
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              trailing: Text(branch.shortSha,
                  style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontFamily: 'monospace')),
            );
          },
        );

      case GitHubDialogType.pullRequests:
        if (ghProvider.pullRequests.isEmpty) {
          return const Center(child: Text('PR이 없습니다'));
        }
        return ListView.builder(
          itemCount: ghProvider.pullRequests.length +
              (ghProvider.hasMorePRs ? 1 : 0),
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
                      child: Text(pr.author.isNotEmpty ? pr.author[0] : '?')),
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
