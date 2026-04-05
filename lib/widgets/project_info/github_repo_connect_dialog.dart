import 'package:flutter/material.dart';

import '../../providers/github_provider.dart';

/// GitHub 레포 연결 다이얼로그 (개요·GitHub 탭 공용)
class GitHubRepoConnectDialog extends StatefulWidget {
  final GitHubProvider ghProvider;
  final String projectId;
  final ColorScheme colorScheme;

  const GitHubRepoConnectDialog({
    super.key,
    required this.ghProvider,
    required this.projectId,
    required this.colorScheme,
  });

  @override
  State<GitHubRepoConnectDialog> createState() =>
      _GitHubRepoConnectDialogState();
}

class _GitHubRepoConnectDialogState extends State<GitHubRepoConnectDialog> {
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
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasRepos) ...[
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
                                                          repo['owner'] as String,
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
                                final owner = _ownerCtrl.text.trim();
                                final name = _nameCtrl.text.trim();
                                if (owner.isEmpty || name.isEmpty) return;
                                final success =
                                    await widget.ghProvider.connectRepo(
                                  projectId: widget.projectId,
                                  repoOwner: owner,
                                  repoName: name,
                                );
                                if (success && context.mounted) {
                                  await Future.wait([
                                    widget.ghProvider
                                        .loadLanguages(widget.projectId),
                                    widget.ghProvider
                                        .loadBranches(widget.projectId),
                                    widget.ghProvider.loadRepoRemoteDetails(
                                        widget.projectId),
                                    widget.ghProvider.loadCommits(
                                        widget.projectId,
                                        showGlobalLoading: false),
                                    widget.ghProvider.loadCommitActivityHeatmap(
                                        widget.projectId),
                                  ]);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
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
