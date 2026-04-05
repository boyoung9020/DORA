import 'dart:math';

import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../widgets/glass_container.dart';

/// 최근 7일(오늘 포함) 완료 작업 수로 막대 높이 계산. 왼쪽이 가장 오래된 날, 오른쪽이 오늘.
List<double> weeklyDoneBarHeights(List<Task> allTasks) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final counts = List<int>.filled(7, 0);

  for (final t in allTasks) {
    if (t.status != TaskStatus.done) continue;
    final d = DateTime(t.updatedAt.year, t.updatedAt.month, t.updatedAt.day);
    final diff = today.difference(d).inDays;
    if (diff < 0 || diff > 6) continue;
    counts[6 - diff]++;
  }

  final maxC = counts.fold<int>(0, (a, b) => max(a, b));
  if (maxC == 0) {
    return List<double>.filled(7, 0.22);
  }
  return counts
      .map((c) => max(0.2, c / maxC))
      .toList(growable: false);
}

class ProductivityCard extends StatelessWidget {
  final int completedTasks;
  final int inProgressTasks;
  final List<Task> allTasks;

  const ProductivityCard({
    super.key,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.allTasks,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heights = weeklyDoneBarHeights(allTasks);

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 16,
      blur: 20,
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
      ],
      shadowBlurRadius: 8,
      shadowOffset: const Offset(0, 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.trending_up_rounded,
                size: 16, color: Colors.green.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('주간 생산성',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$completedTasks',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface)),
                    const SizedBox(width: 3),
                    Text('건 완료',
                        style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
                Text('최근 7일 · 완료 반영일 기준',
                    style: TextStyle(
                        fontSize: 9,
                        color: colorScheme.onSurface.withValues(alpha: 0.38))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 118,
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final h = heights[i].clamp(0.15, 1.0);
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 3,
                      right: i == 6 ? 0 : 0,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: max(4.0, 34 * h),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.green.shade600
                              : Colors.green.shade200,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
