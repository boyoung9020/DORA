import 'package:flutter/material.dart';
import '../../widgets/glass_container.dart';

class ProductivityCard extends StatelessWidget {
  final int completedTasks;
  final int inProgressTasks;

  const ProductivityCard({
    super.key,
    required this.completedTasks,
    required this.inProgressTasks,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      blur: 20,
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
      ],
      shadowBlurRadius: 8,
      shadowOffset: const Offset(0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('주간 생산성',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$completedTasks',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface)),
                        const SizedBox(width: 4),
                        Text('건 완료',
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.trending_up_rounded,
                    size: 20, color: Colors.green.shade600),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                const heights = [0.3, 0.45, 0.25, 0.6, 0.4, 0.8, 1.0];
                final isLast = i == 6;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FractionallySizedBox(
                      heightFactor: heights[i],
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLast ? Colors.green.shade500 : Colors.green.shade100,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(3)),
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
