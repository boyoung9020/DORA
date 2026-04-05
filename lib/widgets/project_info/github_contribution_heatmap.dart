import 'package:contribution_heatmap/contribution_heatmap.dart';
import 'package:flutter/material.dart';

/// GitHub 스타일 커밋 활동 잔디 (`contribution_heatmap`)
class GitHubContributionHeatmap extends StatefulWidget {
  final Map<String, int> countByDay;
  final bool loading;

  /// 로컬 날짜 키 `yyyy-MM-dd`
  const GitHubContributionHeatmap({
    super.key,
    required this.countByDay,
    this.loading = false,
  });

  @override
  State<GitHubContributionHeatmap> createState() =>
      _GitHubContributionHeatmapState();
}

class _GitHubContributionHeatmapState extends State<GitHubContributionHeatmap> {
  final ScrollController _hScroll = ScrollController();

  // 선택 가능한 5가지 색상 팔레트
  static const _colorOptions = [
    (HeatmapColor.green,  Color(0xFF2E7D32), '초록'),
    (HeatmapColor.blue,   Color(0xFF1565C0), '파랑'),
    (HeatmapColor.purple, Color(0xFF6A1B9A), '보라'),
    (HeatmapColor.orange, Color(0xFFE65100), '주황'),
    (HeatmapColor.pink,   Color(0xFFAD1457), '핑크'),
  ];

  HeatmapColor _selectedColor = HeatmapColor.green;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollNewestIntoView());
  }

  @override
  void didUpdateWidget(covariant GitHubContributionHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading ||
        oldWidget.countByDay.length != widget.countByDay.length) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollNewestIntoView());
    }
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  void _scrollNewestIntoView() {
    if (!mounted || !_hScroll.hasClients) return;
    final max = _hScroll.position.maxScrollExtent;
    if (max > 0) {
      _hScroll.jumpTo(max);
    }
  }

  static List<ContributionEntry> _entriesFromMap(Map<String, int> map) {
    final out = <ContributionEntry>[];
    for (final e in map.entries) {
      if (e.value <= 0) continue;
      final parts = e.key.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) continue;
      out.add(ContributionEntry(DateTime(y, m, d), e.value));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.countByDay.isEmpty) {
      return SizedBox(
        height: 92,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green.shade700.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 364));
    final entries = _entriesFromMap(widget.countByDay);

    final heatmap = ContributionHeatmap(
      entries: entries,
      minDate: start,
      maxDate: end,
      heatmapColor: _selectedColor,
      weekdayLabel: WeekdayLabel.githubLike,
      showMonthLabels: true,
      splittedMonthView: false,
      cellSize: 11,
      cellSpacing: 3,
      cellRadius: 2,
      padding: const EdgeInsets.fromLTRB(0, 2, 4, 4),
      startWeekday: DateTime.monday,
      monthTextStyle: TextStyle(
        fontSize: 11,
        height: 1,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      weekdayTextStyle: TextStyle(
        fontSize: 10,
        height: 1,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [heatmap],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          // 색상 선택 버튼 + "최근 1년" 레이블
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '최근 1년',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _colorOptions.map((opt) {
                    final (color, swatch, label) = opt;
                    final isSelected = _selectedColor == color;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Tooltip(
                        message: label,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isSelected ? 14 : 12,
                            height: isSelected ? 14 : 12,
                            decoration: BoxDecoration(
                              color: swatch,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: swatch,
                                      width: 2,
                                    )
                                  : Border.all(
                                      color: swatch.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: swatch.withValues(alpha: 0.45),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
