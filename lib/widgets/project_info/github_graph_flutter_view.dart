import 'package:flutter/material.dart';

import '../../models/github.dart';
import 'git_graph_painter.dart';

/// GitHub 탭 그래프 패널 — **Flutter Web** 전용 (iframe WebView 미사용).
class GitHubGraphFlutterView extends StatelessWidget {
  final List<GitHubCommit> commits;
  final List<GitHubBranch> branches;
  final bool isDark;
  final bool hasMore;
  final String? selectedSha;
  final ValueChanged<String> onCommitSelected;
  final VoidCallback? onLoadMore;

  const GitHubGraphFlutterView({
    super.key,
    required this.commits,
    required this.branches,
    required this.isDark,
    required this.hasMore,
    required this.selectedSha,
    required this.onCommitSelected,
    this.onLoadMore,
  });

  static String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year;
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$mi';
    } catch (_) {
      return iso;
    }
  }

  List<String> _branchLabels(GitHubCommit c) {
    if (c.branchNames.isNotEmpty) return c.branchNames;
    return branches.where((b) => b.sha == c.sha).map((b) => b.name).toList();
  }

  @override
  Widget build(BuildContext context) {
    final layout = GitGraphLayout.compute(commits);
    const rowHeight = 28.0;
    const laneWidth = 14.0;
    final graphWidth = (layout.maxLane + 1) * laneWidth + 20.0;

    final bg = isDark ? const Color(0xFF09090B) : Colors.white;
    final headerBg = isDark ? const Color(0xFF111113) : const Color(0xFFFAFAFA);
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final textMute = const Color(0xFF71717A);
    final textSub = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B);
    final selBg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFEEF2FF);
    final badgeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
    final badgeBd = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final badgeTx = isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6);

    TextStyle headStyle() => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textMute,
        );

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: graphWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('그래프', style: headStyle()),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text('커밋', style: headStyle()),
                ),
                Expanded(child: Text('설명', style: headStyle())),
                SizedBox(
                  width: 100,
                  child: Text('작성자', style: headStyle()),
                ),
                SizedBox(
                  width: 128,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('날짜',
                        textAlign: TextAlign.right, style: headStyle()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: commits.length + (hasMore ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i >= commits.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: TextButton(
                        onPressed: onLoadMore,
                        child: const Text('더 불러오기'),
                      ),
                    ),
                  );
                }

                final c = commits[i];
                final labels = _branchLabels(c);
                final sel = c.sha == selectedSha;

                return Material(
                  color: sel ? selBg : bg,
                  child: InkWell(
                    onTap: () => onCommitSelected(c.sha),
                    child: Container(
                      height: rowHeight,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: border)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: graphWidth,
                            child: CustomPaint(
                              painter: GitGraphPainter(
                                layout: layout,
                                rowHeight: rowHeight,
                                laneWidth: laneWidth,
                                startRow: i,
                                endRow: i + 2,
                              ),
                              size: Size(graphWidth, rowHeight),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                c.sha.length >= 7
                                    ? c.sha.substring(0, 7)
                                    : c.sha,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: textMute,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                children: [
                                  if (labels.isNotEmpty) ...[
                                    for (final name
                                        in labels.take(2).toList())
                                      Container(
                                        margin:
                                            const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: badgeBd, width: 0.5),
                                        ),
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: badgeTx,
                                          ),
                                        ),
                                      ),
                                    if (labels.length > 2)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Text(
                                          '+${labels.length - 2}',
                                          style: TextStyle(
                                              fontSize: 10, color: textMute),
                                        ),
                                      ),
                                  ],
                                  Expanded(
                                    child: Text(
                                      c.firstLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textMain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                c.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: textSub),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 128,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  _fmtDate(c.date),
                                  style:
                                      TextStyle(fontSize: 11, color: textSub),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
