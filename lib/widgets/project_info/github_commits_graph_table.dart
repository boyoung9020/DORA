import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/github.dart';
import '../../providers/github_provider.dart';
import 'git_graph_painter.dart';

String _tableDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('d MMM yyyy', 'en_US').format(dt);
  } catch (_) {
    return iso;
  }
}

List<String> _allBranchNames(GitHubCommit c, List<GitHubBranch> branches) {
  if (c.branchNames.isNotEmpty) return c.branchNames;
  return branches.where((b) => b.sha == c.sha).map((b) => b.name).toList();
}

/// Git Graph 스타일: 그래프 | 설명(브랜치 뱃지) | 날짜 | 작성자 | 커밋
class GitHubCommitsGraphTable extends StatelessWidget {
  final String projectId;

  const GitHubCommitsGraphTable({super.key, required this.projectId});

  static const _rowH = 44.0;
  static const _laneW = 15.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, gh, _) {
        // 전체 브랜치 뷰: graphCommits, 특정 브랜치: commits
        final useGraph = gh.selectedBranch == null && gh.graphCommits.isNotEmpty;
        final commits = useGraph ? gh.graphCommits : gh.commits;
        final hasMore = useGraph ? gh.hasMoreGraph : gh.hasMoreCommits;
        final isLoading = useGraph ? gh.graphLoading : gh.isLoading;

        if (commits.isEmpty && isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (commits.isEmpty) {
          return Center(
            child: Text(
              '커밋이 없습니다',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45)),
            ),
          );
        }

        final layout = GitGraphLayout.compute(commits);
        final graphW = (layout.maxLane + 1) * _laneW + 18.0;

        return Container(
          color: cs.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerRow(graphW, cs),
              Expanded(
                child: ListView.builder(
                  itemCount: commits.length + (hasMore ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == commits.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => useGraph
                                ? gh.loadMoreGraph(projectId)
                                : gh.loadMoreCommits(projectId),
                            icon: Icon(Icons.expand_more,
                                size: 18, color: cs.primary),
                            label: Text(
                              '더 불러오기',
                              style: TextStyle(color: cs.primary),
                            ),
                          ),
                        ),
                      );
                    }
                    return _dataRow(
                      gh: gh,
                      commits: commits,
                      layout: layout,
                      graphW: graphW,
                      row: i,
                      cs: cs,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerRow(double graphW, ColorScheme cs) {
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: cs.onSurface.withValues(alpha: 0.5),
    );
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: graphW,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text('Graph', style: headerStyle),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text('Description', style: headerStyle),
          ),
          SizedBox(
            width: 104,
            child: Text('Date', style: headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('Author',
                style: headerStyle, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text('Commit',
                  textAlign: TextAlign.right, style: headerStyle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow({
    required GitHubProvider gh,
    required List<GitHubCommit> commits,
    required GitGraphLayout layout,
    required double graphW,
    required int row,
    required ColorScheme cs,
  }) {
    final commit = commits[row];
    final node = layout.nodes[row];
    final isMerge = commit.parents.length > 1;
    final laneColor = GitGraphLayout.colorForLane(node.lane);
    final branchNames = _allBranchNames(commit, gh.branches);
    final branchName = branchNames.isNotEmpty ? branchNames.first : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(commit.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        hoverColor: cs.onSurface.withValues(alpha: 0.04),
        child: Container(
          height: _rowH,
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.25))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: graphW,
                child: CustomPaint(
                  painter: GitGraphPainter(
                    layout: layout,
                    rowHeight: _rowH,
                    laneWidth: _laneW,
                    startRow: row,
                    endRow: (row + 2).clamp(0, commits.length),
                  ),
                  size: Size(graphW, _rowH),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      if (branchName != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_tree,
                                    size: 11, color: laneColor),
                                const SizedBox(width: 4),
                                Text(
                                  branchName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: laneColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // 브랜치 뱃지 (두 번째 이후 브랜치)
                      ...branchNames.skip(1).map((name) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.account_tree, size: 11, color: laneColor),
                            const SizedBox(width: 4),
                            Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: laneColor)),
                          ]),
                        ),
                      )),
                      // 태그 뱃지
                      ...commit.tagNames.map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4A843).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD4A843).withValues(alpha: 0.5)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.local_offer, size: 11, color: Color(0xFFD4A843)),
                            const SizedBox(width: 4),
                            Text(tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD4A843))),
                          ]),
                        ),
                      )),
                      if (isMerge && branchName == null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: laneColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'merge',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: laneColor,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          commit.firstLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 104,
                child: Text(
                  _tableDate(commit.date),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  commit.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              SizedBox(
                width: 76,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    commit.shortSha,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
