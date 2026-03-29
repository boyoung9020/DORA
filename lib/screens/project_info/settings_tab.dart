import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../widgets/glass_container.dart';

class SettingsTab extends StatelessWidget {
  final Project project;
  final bool isPM;
  final TextEditingController nameController;
  final TextEditingController descriptionController;

  const SettingsTab({
    super.key,
    required this.project,
    required this.isPM,
    required this.nameController,
    required this.descriptionController,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        blur: 20,
        gradientColors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.8),
        ],
        shadowBlurRadius: 8,
        shadowOffset: const Offset(0, 2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('프로젝트 설정',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text('프로젝트의 기본 정보 및 권한을 관리합니다.',
                        style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              // 폼
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('프로젝트 이름',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      enabled: isPM,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('설명',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      enabled: isPM,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isPM)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              nameController.text = project.name;
                              descriptionController.text =
                                  project.description ?? '';
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            child: const Text('취소'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () async {
                              final provider = context.read<ProjectProvider>();
                              final updated = project.copyWith(
                                name: nameController.text.trim(),
                                description: descriptionController.text.trim(),
                              );
                              await provider.updateProject(updated);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('프로젝트가 저장되었습니다'),
                                    backgroundColor: colorScheme.primary,
                                  ),
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            child: const Text('저장하기'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
