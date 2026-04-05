import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/github_provider.dart';
import 'github_panel_widgets.dart';

enum GitHubDialogType { commits, branches, pullRequests }

class GitHubListDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCommits = type == GitHubDialogType.commits;

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
                      Text(title,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface)),
                      const Spacer(),
                      if (isCommits && ghProvider.branches.isNotEmpty)
                        GitHubBranchSelectorDropdown(projectId: projectId),
                      if (type == GitHubDialogType.pullRequests)
                        GitHubPRFilterSegmented(projectId: projectId),
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
                      : _buildList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList() {
    switch (type) {
      case GitHubDialogType.commits:
        return GitHubCommitsGraphList(projectId: projectId);
      case GitHubDialogType.branches:
        return const GitHubBranchesList();
      case GitHubDialogType.pullRequests:
        return GitHubPullRequestsList(projectId: projectId);
    }
  }
}
