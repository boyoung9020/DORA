import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../widgets/glass_container.dart';

class DDayCard extends StatelessWidget {
  final DateTime createdAt;
  final double progressPercent;
  final List<Task> allTasks;

  const DDayCard({
    super.key,
    required this.createdAt,
    required this.progressPercent,
    required this.allTasks,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final taskEndDates = allTasks
        .where((t) => t.endDate != null)
        .map((t) => t.endDate!)
        .toList();
    final goalDate = taskEndDates.isNotEmpty
        ? taskEndDates.reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    String dDayText;
    double progressValue;

    if (goalDate != null) {
      final daysRemaining = goalDate.difference(now).inDays;
      if (daysRemaining > 0) {
        dDayText = 'D-$daysRemaining';
      } else if (daysRemaining == 0) {
        dDayText = 'D-Day';
      } else {
        dDayText = 'D+${-daysRemaining}';
      }
      final totalDays = goalDate.difference(createdAt).inDays;
      final elapsedDays = now.difference(createdAt).inDays;
      progressValue =
          totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 1.0) : 0.0;
    } else {
      final totalDuration = now.difference(createdAt).inDays;
      dDayText = totalDuration == 0 ? 'D-Day' : 'D+$totalDuration';
      progressValue = (progressPercent / 100).clamp(0.0, 1.0);
    }

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
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.calendar_today_rounded,
                size: 16, color: Colors.orange.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('프로젝트 D-Day',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 2),
                Text(dDayText,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade700)),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progressValue,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade300,
                              Colors.orange.shade500
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('시작',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(alpha: 0.4))),
                    Text('현재',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade600)),
                    Text('목표',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
