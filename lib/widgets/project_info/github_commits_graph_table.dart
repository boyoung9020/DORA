import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/github.dart';
import '../../providers/github_provider.dart';
import '../../services/github_service.dart';
import 'github_graph_flutter_view.dart';
import 'github_graph_webview.dart';

String _fmtDate(String iso) {
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

/// WebView 기반 Git Graph + Flutter 사이드바 (커밋 상세 + Compare)
class GitHubCommitsGraphTable extends StatefulWidget {
  final String projectId;
  const GitHubCommitsGraphTable({super.key, required this.projectId});

  @override
  State<GitHubCommitsGraphTable> createState() =>
      _GitHubCommitsGraphTableState();
}

class _GitHubCommitsGraphTableState extends State<GitHubCommitsGraphTable> {
  static const double _sidebarW = 320;

  String? _selectedSha;
  String? _baseSha;
  String? _headSha;

  bool _compareLoading = false;
  String? _compareError;
  GitHubCompareResult? _compareResult;

  final _githubService = GitHubService();

  Future<void> _runCompare() async {
    if (_baseSha == null || _headSha == null) return;
    setState(() {
      _compareLoading = true;
      _compareError = null;
    });
    try {
      final result = await _githubService.compareCommits(
        widget.projectId,
        base: _baseSha!,
        head: _headSha!,
      );
      if (mounted) setState(() => _compareResult = result);
    } catch (_) {
      if (mounted) {
        setState(
            () => _compareError = '비교 결과를 불러오지 못했습니다. base/head 선택을 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _compareLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Consumer<GitHubProvider>(
      builder: (context, gh, _) {
        final useGraph =
            gh.selectedBranch == null && gh.graphCommits.isNotEmpty;
        final commits = useGraph ? gh.graphCommits : gh.commits;
        final hasMore = useGraph ? gh.hasMoreGraph : gh.hasMoreCommits;
        final isLoading = useGraph ? gh.graphLoading : gh.isLoading;

        if (commits.isEmpty && isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (commits.isEmpty) {
          return Center(
            child: Text('커밋이 없습니다',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.45))),
          );
        }

        final selectedCommit = _selectedSha != null
            ? commits.cast<GitHubCommit?>().firstWhere(
                (c) => c!.sha == _selectedSha,
                orElse: () => null)
            : null;

        final borderColor =
            isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 왼쪽: WebView 그래프 ──────────────────────────
            Expanded(
              child: kIsWeb
                  ? GitHubGraphFlutterView(
                      commits: commits,
                      branches: gh.branches,
                      isDark: isDark,
                      hasMore: hasMore,
                      selectedSha: _selectedSha,
                      onCommitSelected: (sha) =>
                          setState(() => _selectedSha = sha),
                      onLoadMore: () => useGraph
                          ? gh.loadMoreGraph(widget.projectId)
                          : gh.loadMoreCommits(widget.projectId),
                    )
                  : GitHubGraphWebView(
                      commits: commits,
                      branches: gh.branches,
                      isDark: isDark,
                      hasMore: hasMore,
                      onCommitSelected: (sha) =>
                          setState(() => _selectedSha = sha),
                      onLoadMore: () => useGraph
                          ? gh.loadMoreGraph(widget.projectId)
                          : gh.loadMoreCommits(widget.projectId),
                    ),
            ),
            // ── 오른쪽: 사이드바 ─────────────────────────────
            Container(
              width: _sidebarW,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borderColor)),
                color: isDark ? const Color(0xFF09090B) : Colors.white,
              ),
              child: _buildSidebar(
                selectedCommit: selectedCommit,
                isDark: isDark,
                borderColor: borderColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar({
    required GitHubCommit? selectedCommit,
    required bool isDark,
    required Color borderColor,
  }) {
    final labelColor = const Color(0xFF71717A);
    final textColor =
        isDark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B);
    final subTextColor =
        isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B);
    final bgMuted =
        isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('선택 커밋',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          const SizedBox(height: 8),
          if (selectedCommit == null)
            Text('그래프에서 커밋을 선택하세요.',
                style: TextStyle(fontSize: 12, color: subTextColor))
          else ...[
            _label('SHA', labelColor),
            const SizedBox(height: 2),
            SelectableText(selectedCommit.sha,
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: textColor)),
            const SizedBox(height: 12),
            _label('비교 선택', labelColor),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _btn(
                    label: 'base로 설정',
                    filled: true,
                    isDark: isDark,
                    borderColor: borderColor,
                    onPressed: _compareLoading
                        ? null
                        : () => setState(() {
                              _baseSha = selectedCommit.sha;
                              _compareResult = null;
                              _compareError = null;
                            }),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _btn(
                    label: 'head로 설정',
                    filled: false,
                    isDark: isDark,
                    borderColor: borderColor,
                    onPressed: _compareLoading
                        ? null
                        : () => setState(() {
                              _headSha = selectedCommit.sha;
                              _compareResult = null;
                              _compareError = null;
                            }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgMuted,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _kv('base', _baseSha, labelColor, textColor),
                  const SizedBox(height: 4),
                  _kv('head', _headSha, labelColor, textColor),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: _btn(
                label: _compareLoading ? '비교 중…' : 'Compare 실행',
                filled: false,
                isDark: isDark,
                borderColor: borderColor,
                onPressed: (_baseSha == null ||
                        _headSha == null ||
                        _compareLoading)
                    ? null
                    : _runCompare,
              ),
            ),
            if (_compareError != null) ...[
              const SizedBox(height: 4),
              Text(_compareError!,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 12),
            _label('메시지', labelColor),
            const SizedBox(height: 2),
            Text(selectedCommit.message,
                style: TextStyle(fontSize: 12, color: textColor)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('작성자', labelColor),
                      const SizedBox(height: 2),
                      Text(selectedCommit.authorName,
                          style:
                              TextStyle(fontSize: 12, color: textColor)),
                    ])),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('시간', labelColor),
                      const SizedBox(height: 2),
                      Text(_fmtDate(selectedCommit.date),
                          style:
                              TextStyle(fontSize: 12, color: textColor)),
                    ])),
              ],
            ),
          ],
          // ── Compare 결과 ──────────────────────────────────
          const SizedBox(height: 16),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 12),
          Text('Compare 결과',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          const SizedBox(height: 8),
          if (_compareResult == null)
            Text('base/head를 선택하고 Compare를 실행하세요.',
                style: TextStyle(fontSize: 12, color: subTextColor))
          else ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgMuted,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _kvRaw(
                      'ahead/behind',
                      '${_compareResult!.aheadBy ?? "-"} / ${_compareResult!.behindBy ?? "-"}',
                      labelColor,
                      textColor),
                  const SizedBox(height: 4),
                  _kvRaw('commits',
                      '${_compareResult!.totalCommits ?? "-"}',
                      labelColor, textColor),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: _compareResult!.files.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                          child: Text('변경된 파일이 없습니다.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor))))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _compareResult!.files.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: borderColor),
                      itemBuilder: (ctx, i) {
                        final f = _compareResult!.files[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(f.filename,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: textColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                  '${f.status ?? "-"} · +${f.additions} -${f.deletions} (Δ${f.changes})',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: labelColor)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text, Color color) =>
      Text(text, style: TextStyle(fontSize: 11, color: color));

  Widget _kv(
      String label, String? sha, Color labelColor, Color textColor) {
    final display = sha != null
        ? sha.substring(0, sha.length.clamp(0, 7))
        : '-';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
        Text(display,
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: textColor)),
      ],
    );
  }

  Widget _kvRaw(
      String label, String value, Color labelColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
        Text(value, style: TextStyle(fontSize: 11, color: textColor)),
      ],
    );
  }

  Widget _btn({
    required String label,
    required bool filled,
    required bool isDark,
    required Color borderColor,
    VoidCallback? onPressed,
  }) {
    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor:
                isDark ? Colors.white : const Color(0xFF18181B),
            foregroundColor:
                isDark ? const Color(0xFF18181B) : Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 6),
            textStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            minimumSize: const Size(0, 30),
          )
        : null;
    if (filled) {
      return ElevatedButton(
          onPressed: onPressed, style: style, child: Text(label));
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isDark ? const Color(0xFFF4F4F5) : const Color(0xFF18181B),
        padding: const EdgeInsets.symmetric(vertical: 6),
        textStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: borderColor),
        minimumSize: const Size(0, 30),
      ),
      child: Text(label),
    );
  }
}
