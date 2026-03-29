import 'package:flutter/material.dart';
import '../../widgets/glass_container.dart';

class ProgressCard extends StatelessWidget {
  final double percent;

  const ProgressCard({super.key, required this.percent});

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
                    Text('전체 진척도',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    Text('${percent.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface)),
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: percent / 100,
                        strokeWidth: 5,
                        backgroundColor:
                            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Icon(Icons.show_chart_rounded, size: 20, color: Colors.blue.shade600),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  percent >= 80 ? '거의 완료' : percent >= 50 ? '순항 중' : '진행 중',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '목표까지 ${(100 - percent).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
