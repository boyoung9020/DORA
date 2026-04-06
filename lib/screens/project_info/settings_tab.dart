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

  Future<void> _confirmDelete(BuildContext context, ColorScheme colorScheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever_rounded, size: 40, color: colorScheme.error),
        title: const Text('프로젝트 삭제'),
        content: Text(
          "${project.name} 프로젝트를 정말 삭제하시겠습니까?\n\n모든 작업, 문서, 설정이 영구적으로 삭제됩니다.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<ProjectProvider>();
    final success = await provider.deleteProject(project.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '프로젝트가 삭제되었습니다' : '삭제 중 오류가 발생했습니다'),
          backgroundColor: success ? colorScheme.primary : colorScheme.error,
        ),
      );
    }
  }

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
              // 프로젝트 삭제
              if (isPM) ...[
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20,
                          color: colorScheme.error.withValues(alpha: 0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('프로젝트 삭제',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.error)),
                            const SizedBox(height: 2),
                            Text('삭제된 프로젝트는 복구할 수 없습니다.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _confirmDelete(context, colorScheme),
                        icon: Icon(Icons.delete_outline, color: colorScheme.error),
                        tooltip: '프로젝트 삭제',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.error.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
