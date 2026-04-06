import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/github_provider.dart';
import 'git_graph_painter.dart';

String formatGitHubCommitDate(String dateStr) {
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

/// 커밋 목록용 브랜치 드롭다운 (Provider 상태와 동기화)
class GitHubBranchSelectorDropdown extends StatelessWidget {
  final String projectId;
  /// true면 커밋 재조회 시 전역 [GitHubProvider.isLoading]을 올리지 않음 (탭 등)
  final bool quietRefresh;

  const GitHubBranchSelectorDropdown({
    super.key,
    required this.projectId,
    this.quietRefresh = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GitHubProvider>(
      builder: (context, gh, _) {
        if (gh.branches.isEmpty) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String?>(
            value: gh.selectedBranch,
            hint:
                const Text('전체 브랜치', style: TextStyle(fontSize: 13)),
            underline: const SizedBox.shrink(),
            isDense: true,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
            items: [
              const DropdownMenuItem(value: null, child: Text('전체')),
              ...gh.branches.map(
                (b) => DropdownMenuItem(value: b.name, child: Text(b.name)),
              ),
            ],
            onChanged: (v) {
              gh.selectBranch(v);
              if (v == null) {
                gh.loadGraph(projectId);
              } else {
                gh.loadCommits(
                  projectId,
                  branch: v,
                  showGlobalLoading: !quietRefresh,
                );
              }
            },
          ),
        );
      },
    );
  }
}

/// PR 상태 필터 (Provider [prState]와 동기화)
class GitHubPRFilterSegmented extends StatelessWidget {
  final String projectId;
  final bool quietRefresh;

  const GitHubPRFilterSegmented({
    super.key,
    required this.projectId,
    this.quietRefresh = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GitHubProvider>(
      builder: (context, gh, _) {
        return SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'open', label: Text('Open')),
            ButtonSegment(value: 'closed', label: Text('Closed')),
            ButtonSegment(value: 'all', label: Text('All')),
          ],
          selected: {gh.prState},
          onSelectionChanged: (v) {
            gh.loadPullRequests(
              projectId,
              state: v.first,
              showGlobalLoading: !quietRefresh,
            );
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}

/// 커밋 그래프 + 목록 ([GitHubListDialog]과 동일 레이아웃)
class GitHubCommitsGraphList extends StatelessWidget {
  final String projectId;
  final EdgeInsets padding;

  const GitHubCommitsGraphList({
    super.key,
    required this.projectId,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, ghProvider, _) {
        final commits = ghProvider.commits;
        if (commits.isEmpty) {
          return const Center(child: Text('커밋이 없습니다'));
        }

        final layout = GitGraphLayout.compute(commits);
        const rowHeight = 52.0;
        const laneWidth = 16.0;
        final graphWidth = (layout.maxLane + 1) * laneWidth + 20;

        return ListView.builder(
          padding: padding,
          itemCount:
              commits.length + (ghProvider.hasMoreCommits ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == commits.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ghProvider.loadMoreCommits(projectId),
                    icon: const Icon(Icons.expand_more, size: 16),
                    label:
                        const Text('더 불러오기', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                                          color: laneColor
                                              .withValues(alpha: 0.3)),
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
                                if (commit.authorAvatarUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 5),
                                    child: CircleAvatar(
                                      radius: 8,
                                      backgroundImage: NetworkImage(
                                          commit.authorAvatarUrl!),
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
                                  formatGitHubCommitDate(commit.date),
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
      },
    );
  }
}

class GitHubTagsList extends StatelessWidget {
  const GitHubTagsList({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, ghProvider, _) {
        if (ghProvider.tags.isEmpty) {
          return const Center(child: Text('태그가 없습니다'));
        }
        return ListView.builder(
          itemCount: ghProvider.tags.length,
          itemBuilder: (ctx, i) {
            final tag = ghProvider.tags[i];
            return ListTile(
              dense: true,
              leading: Icon(Icons.label_outline,
                  size: 20, color: colorScheme.tertiary),
              title: Text(tag.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              trailing: Text(tag.shortSha,
                  style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontFamily: 'monospace')),
            );
          },
        );
      },
    );
  }
}

class GitHubBranchesList extends StatelessWidget {
  const GitHubBranchesList({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, ghProvider, _) {
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
      },
    );
  }
}

class GitHubPullRequestsList extends StatelessWidget {
  final String projectId;
  final EdgeInsets? padding;

  const GitHubPullRequestsList({
    super.key,
    required this.projectId,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, ghProvider, _) {
        if (ghProvider.pullRequests.isEmpty) {
          return const Center(child: Text('PR이 없습니다'));
        }
        return ListView.builder(
          padding: padding,
          itemCount: ghProvider.pullRequests.length +
              (ghProvider.hasMorePRs ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == ghProvider.pullRequests.length) {
              return Center(
                child: TextButton(
                  onPressed: () =>
                      ghProvider.loadMorePullRequests(projectId),
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
                      child: Text(
                          pr.author.isNotEmpty ? pr.author[0] : '?')),
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
      },
    );
  }
}

/// 오른쪽 사이드 — Releases 패널 (published_at 기준 최신순)
class GitHubTagsSidePanel extends StatelessWidget {
  final String projectId;
  final String repoOwner;
  final String repoName;

  const GitHubTagsSidePanel({
    super.key,
    required this.projectId,
    required this.repoOwner,
    required this.repoName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: FilledButton.tonalIcon(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => CreateGitTagDialog(projectId: projectId),
              );
            },
            icon: const Icon(Icons.new_label_outlined, size: 18),
            label: const Text('태그 만들기'),
          ),
        ),
        Expanded(
          child: Consumer<GitHubProvider>(
            builder: (context, gh, _) {
              final releases = gh.releases;
              if (releases.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Release가 없습니다.\nGitHub에서 릴리즈를 만들거나\n아래 태그 만들기를 사용하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                itemCount: releases.length,
                itemBuilder: (ctx, i) {
                  final rel = releases[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final uri = Uri.parse(rel.url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.rocket_launch_outlined,
                                      size: 15, color: cs.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      rel.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // 배지들
                                  if (rel.isLatest)
                                    _badge('Latest', Colors.green, cs),
                                  if (rel.prerelease)
                                    _badge('Pre', Colors.orange, cs),
                                  if (rel.draft)
                                    _badge('Draft', cs.onSurface.withValues(alpha: 0.4), cs),
                                  const SizedBox(width: 4),
                                  Icon(Icons.open_in_new,
                                      size: 13,
                                      color: cs.onSurface.withValues(alpha: 0.3)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.label_outline,
                                      size: 12,
                                      color: cs.onSurface.withValues(alpha: 0.4)),
                                  const SizedBox(width: 4),
                                  Text(
                                    rel.tagName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: cs.onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  if (rel.displayDate.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    Icon(Icons.schedule,
                                        size: 12,
                                        color: cs.onSurface.withValues(alpha: 0.35)),
                                    const SizedBox(width: 3),
                                    Text(
                                      rel.displayDate,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (rel.body != null && rel.body!.trim().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  rel.body!.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// GitHub 경량 태그 생성 — 커밋 선택 또는 SHA 직접 입력
class CreateGitTagDialog extends StatefulWidget {
  final String projectId;

  const CreateGitTagDialog({super.key, required this.projectId});

  @override
  State<CreateGitTagDialog> createState() => _CreateGitTagDialogState();
}

class _CreateGitTagDialogState extends State<CreateGitTagDialog> {
  final _tagNameCtrl = TextEditingController();
  final _shaCtrl = TextEditingController();
  String? _selectedCommitSha;
  bool _submitting = false;

  @override
  void dispose() {
    _tagNameCtrl.dispose();
    _shaCtrl.dispose();
    super.dispose();
  }

  static final _shaRx = RegExp(r'^[0-9a-fA-F]{7,40}$');

  String? _effectiveSha() {
    final manual = _shaCtrl.text.trim();
    if (manual.isNotEmpty) return manual;
    return _selectedCommitSha;
  }

  Future<void> _submit() async {
    final name = _tagNameCtrl.text.trim();
    final sha = _effectiveSha();
    if (name.isEmpty) {
      _toast(context, '태그 이름을 입력하세요');
      return;
    }
    if (sha == null || sha.isEmpty) {
      _toast(context, '커밋을 선택하거나 SHA를 입력하세요');
      return;
    }
    if (!_shaRx.hasMatch(sha)) {
      _toast(context, '커밋 SHA는 7~40자의 16진수여야 합니다');
      return;
    }

    setState(() => _submitting = true);
    final gh = context.read<GitHubProvider>();
    final ok = await gh.createTag(
      widget.projectId,
      tagName: name,
      commitSha: sha,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('태그 "$name" 생성됨')),
      );
    } else {
      _toast(context, gh.errorMessage ?? '태그 생성 실패');
    }
  }

  void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('태그 만들기'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _tagNameCtrl,
                decoration: const InputDecoration(
                  labelText: '태그 이름',
                  hintText: '예: v1.2.0',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              Consumer<GitHubProvider>(
                builder: (context, gh, _) {
                  final list = gh.commits;
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '커밋 목록이 비어 있습니다. GitHub 탭에서 커밋이 로드된 뒤 다시 시도하거나, 아래에 SHA를 직접 입력하세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '커밋 선택',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '목록에서 커밋 선택',
                        ),
                        isEmpty: false,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            hint: const Text('목록에서 커밋 선택'),
                            value: _selectedCommitSha != null &&
                                    list.any((c) => c.sha == _selectedCommitSha)
                                ? _selectedCommitSha
                                : null,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('선택 안 함'),
                              ),
                              ...list.map((c) {
                                final line = c.firstLine.length > 48
                                    ? '${c.firstLine.substring(0, 48)}…'
                                    : c.firstLine;
                                return DropdownMenuItem<String?>(
                                  value: c.sha,
                                  child: Text(
                                    '${c.shortSha}  $line',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _selectedCommitSha = v;
                                if (v != null) _shaCtrl.clear();
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shaCtrl,
                decoration: const InputDecoration(
                  labelText: '또는 커밋 SHA 직접 입력',
                  hintText: '7~40자 16진수 (입력 시 목록 선택보다 우선)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_shaCtrl.text.trim().isNotEmpty) {
                    setState(() => _selectedCommitSha = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'GitHub PAT에 저장소 쓰기 권한이 있어야 합니다. 경량 태그만 생성됩니다.',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('생성'),
        ),
      ],
    );
  }
}

/// Issue 상태 필터 (open / closed / all)
class GitHubIssueFilterSegmented extends StatelessWidget {
  final String projectId;

  const GitHubIssueFilterSegmented({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GitHubProvider>(
      builder: (context, gh, _) {
        return SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'open', label: Text('Open')),
            ButtonSegment(value: 'closed', label: Text('Closed')),
            ButtonSegment(value: 'all', label: Text('All')),
          ],
          selected: {gh.issueState},
          onSelectionChanged: (v) {
            gh.loadIssues(projectId, state: v.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}

/// Issue 목록 위젯
class GitHubIssuesList extends StatelessWidget {
  final String projectId;
  final EdgeInsets? padding;

  const GitHubIssuesList({
    super.key,
    required this.projectId,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, gh, _) {
        if (gh.issues.isEmpty) {
          return Center(
            child: Text(
              'Issue가 없습니다',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: padding,
          itemCount: gh.issues.length + (gh.hasMoreIssues ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == gh.issues.length) {
              return Center(
                child: TextButton(
                  onPressed: () => gh.loadMoreIssues(projectId),
                  child: const Text('더 불러오기'),
                ),
              );
            }
            final issue = gh.issues[i];
            final stateColor =
                issue.state == 'open' ? Colors.green : Colors.purple.shade400;
            return ListTile(
              dense: true,
              leading: issue.authorAvatarUrl != null
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(issue.authorAvatarUrl!))
                  : CircleAvatar(
                      radius: 16,
                      child: Text(
                          issue.author.isNotEmpty ? issue.author[0] : '?')),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      issue.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      issue.state,
                      style: TextStyle(
                        fontSize: 10,
                        color: stateColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Row(
                children: [
                  Text(
                    '#${issue.number} · ${issue.author}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (issue.comments > 0) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.chat_bubble_outline,
                        size: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 2),
                    Text(
                      '${issue.comments}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                  if (issue.labels.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    ...issue.labels.take(2).map((label) => Container(
                          margin: const EdgeInsets.only(right: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )),
                  ],
                ],
              ),
              onTap: () async {
                final uri = Uri.parse(issue.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            );
          },
        );
      },
    );
  }
}
