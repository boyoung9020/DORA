import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../widgets/glass_container.dart';

class ProjectHeader extends StatelessWidget {
  final Project project;

  const ProjectHeader({super.key, required this.project});

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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: project.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.folder_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface),
                ),
                if (project.description != null && project.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      project.description!,
                      style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '생성일: ${project.createdAt.year}-${project.createdAt.month.toString().padLeft(2, '0')}-${project.createdAt.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 4),
              Text(
                '팀원 ${project.teamMemberIds.length}명',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
