import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/project.dart';
import '../../providers/github_provider.dart';
import '../../widgets/glass_container.dart';
import 'tech_stack_card.dart';

class ProjectHeader extends StatefulWidget {
  final Project project;

  const ProjectHeader({super.key, required this.project});

  @override
  State<ProjectHeader> createState() => _ProjectHeaderState();
}

class _ProjectHeaderState extends State<ProjectHeader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapGitHub());
  }

  @override
  void didUpdateWidget(ProjectHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapGitHub());
    }
  }

  Future<void> _bootstrapGitHub() async {
    if (!mounted) return;
    final id = widget.project.id;
    final gh = context.read<GitHubProvider>();
    await gh.loadMyTokenStatus();
    await gh.loadRepoInfo(id);
    if (!mounted || widget.project.id != id) return;
    if (gh.connectedRepo != null) {
      await gh.loadLanguages(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final project = widget.project;
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: project.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.folder_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    project.name,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface),
                  ),
                  if (project.description != null &&
                      project.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        project.description!,
                        style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TechStackHeaderStrip(maxIcons: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
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
