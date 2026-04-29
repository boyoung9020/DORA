import 'package:flutter/material.dart';
import '../../models/activity_stats.dart';

/// GitHub 스타일 contribution heatmap.
/// - 가로축: 최근 N주(기본 12) × 7일 = 7N칸 (좌→우 시간 순)
/// - 세로축: 워크스페이스 멤버 1명 = 1행
/// - 셀 색: accent 색상의 알파 5단계 (Less → More)
/// - 셀 hover: 툴팁으로 날짜·건수
/// - 우측: 멤버별 합계
///
/// 임계값은 워크스페이스 전체의 일별 max 분포 기반 quantile 로 동적 산정.
class ContributionHeatmap extends StatelessWidget {
  final ActivityHeatmap data;
  final Color accent;

  const ContributionHeatmap({
    super.key,
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emptyCellColor = cs.outlineVariant.withValues(alpha: 0.25);

    // 임계값 계산: 모든 (멤버, 일자) count 의 분포에서 0 제외 quantile
    final allCounts = <int>[];
    int dayLen = 0;
    for (final m in data.members) {
      if (m.daily.length > dayLen) dayLen = m.daily.length;
      for (final e in m.daily) {
        if (e.count > 0) allCounts.add(e.count);
      }
    }
    allCounts.sort();
    int q(double p) {
      if (allCounts.isEmpty) return 0;
      final idx = ((allCounts.length - 1) * p).floor();
      return allCounts[idx];
    }
    final t1 = q(0.25);
    final t2 = q(0.50);
    final t3 = q(0.75);
    final t4 = q(0.95);

    Color colorFor(int count) {
      if (count <= 0) return emptyCellColor;
      if (count <= t1) return accent.withValues(alpha: 0.22);
      if (count <= t2) return accent.withValues(alpha: 0.42);
      if (count <= t3) return accent.withValues(alpha: 0.62);
      if (count <= t4) return accent.withValues(alpha: 0.82);
      return accent;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, cs),
          const SizedBox(height: 8),
          if (data.members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '활동 데이터가 없습니다',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // 멤버 이름 영역 + 합계 영역 폭 빼고 셀 영역 폭 계산
                const labelWidth = 64.0;
                const totalWidth = 44.0;
                const hPadding = 12.0;
                final cellAreaWidth = (constraints.maxWidth -
                        labelWidth -
                        totalWidth -
                        hPadding * 2)
                    .clamp(120.0, double.infinity);
                // dayLen 칸을 정확히 채우도록 셀 크기 산출 (셀 사이 1px 갭 포함)
                const spacing = 2.0;
                final cellSize =
                    ((cellAreaWidth - (dayLen - 1) * spacing) / dayLen)
                        .clamp(6.0, 18.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.members.map((m) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: labelWidth,
                            child: Text(
                              m.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          const SizedBox(width: hPadding),
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(m.daily.length, (i) {
                                  final e = m.daily[i];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          i == m.daily.length - 1 ? 0 : spacing,
                                    ),
                                    child: Tooltip(
                                      message:
                                          '${_fmtDate(e.date)} · ${e.count}건',
                                      preferBelow: false,
                                      child: Container(
                                        width: cellSize,
                                        height: cellSize,
                                        decoration: BoxDecoration(
                                          color: colorFor(e.count),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: hPadding),
                          SizedBox(
                            width: totalWidth,
                            child: Text(
                              '${m.total}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contribution heatmap',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Last ${data.weeks} weeks · 작업 생성 + 완료 + 댓글 (작업 카드 단위)',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Text('Less',
            style: TextStyle(
                fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
        const SizedBox(width: 6),
        ...List.generate(5, (i) {
          final alpha = i == 0 ? 0.0 : (0.22 + i * 0.20).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: i == 0
                    ? cs.outlineVariant.withValues(alpha: 0.25)
                    : accent.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        Text('More',
            style: TextStyle(
                fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  static String _fmtDate(DateTime d) {
    final wk = ['일', '월', '화', '수', '목', '금', '토'];
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} (${wk[d.weekday % 7]})';
  }
}
