import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sprint.dart';
import '../models/task.dart';
import '../providers/project_provider.dart';
import '../providers/sprint_provider.dart';
import '../providers/task_provider.dart';

class SprintScreen extends StatefulWidget {
  const SprintScreen({super.key});

  @override
  State<SprintScreen> createState() => _SprintScreenState();
}

class _SprintScreenState extends State<SprintScreen> {
  SprintStatus _filter = SprintStatus.planning;
  String? _selectedSprintId;
  String? _lastLoadedProjectId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectId = context.read<ProjectProvider>().currentProject?.id;
    if (_lastLoadedProjectId != projectId) {
      _lastLoadedProjectId = projectId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SprintProvider>().loadSprints(projectId: projectId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final project = context.watch<ProjectProvider>().currentProject;
    final sprintProvider = context.watch<SprintProvider>();
    final taskProvider = context.watch<TaskProvider>();

    if (project == null) {
      return const Center(child: Text('프로젝트를 먼저 선택하세요.'));
    }

    final sprints = sprintProvider.sprints.where((s) => s.status == _filter).toList();
    Sprint? selectedSprint;
    if (_selectedSprintId != null) {
      for (final sprint in sprintProvider.sprints) {
        if (sprint.id == _selectedSprintId) {
          selectedSprint = sprint;
          break;
        }
      }
    }
    selectedSprint ??= sprints.isNotEmpty ? sprints.first : null;

    final projectTasks = taskProvider.tasks.where((t) => t.projectId == project.id).toList();
    final backlogTasks = projectTasks.where((t) => t.sprintId == null).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSprintDialog(context, project.id),
        icon: const Icon(Icons.add),
        label: const Text('스프린트 생성'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: SprintStatus.values.map((status) {
                final selected = status == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(status.displayName),
                    onSelected: (_) {
                      setState(() => _filter = status);
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                      ),
                      child: ListView.separated(
                        itemCount: sprints.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.15),
                        ),
                        itemBuilder: (context, index) {
                          final sprint = sprints[index];
                          final selected = sprint.id == selectedSprint?.id;
                          return ListTile(
                            selected: selected,
                            title: Text(sprint.name),
                            subtitle: Text(sprint.goal?.isNotEmpty == true ? sprint.goal! : '목표 없음'),
                            trailing: Text('${sprint.taskIds.length} tasks'),
                            onTap: () => setState(() => _selectedSprintId = sprint.id),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _buildSprintDetail(
                      context,
                      selectedSprint,
                      projectTasks,
                      backlogTasks,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSprintDetail(
    BuildContext context,
    Sprint? sprint,
    List<Task> projectTasks,
    List<Task> backlogTasks,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (sprint == null) {
      return Center(
        child: Text(
          '선택된 스프린트가 없습니다.',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      );
    }

    final sprintTasks = projectTasks.where((t) => sprint.taskIds.contains(t.id)).toList();
    final doneCount = sprintTasks.where((t) => t.status == TaskStatus.done).length;
    final progress = sprintTasks.isEmpty ? 0.0 : doneCount / sprintTasks.length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sprint.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          if (sprint.goal?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              sprint.goal!,
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
            ),
          ),
          const SizedBox(height: 6),
          Text('완료율 ${(progress * 100).toStringAsFixed(0)}% ($doneCount/${sprintTasks.length})'),
          const SizedBox(height: 16),
          Text('스프린트 태스크', style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: sprintTasks.map((task) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(task.title),
                  subtitle: Text(task.status.displayName),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () async {
                      final ok = await context.read<SprintProvider>().removeTaskFromSprint(sprint.id, task.id);
                      if (ok && context.mounted) {
                        final projectId = context.read<ProjectProvider>().currentProject?.id;
                        await context.read<TaskProvider>().loadTasks(projectId: projectId);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          Text('백로그 태스크', style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: ListView(
              children: backlogTasks.map((task) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(task.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () async {
                      final ok = await context.read<SprintProvider>().addTaskToSprint(sprint.id, task.id);
                      if (ok && context.mounted) {
                        final projectId = context.read<ProjectProvider>().currentProject?.id;
                        await context.read<TaskProvider>().loadTasks(projectId: projectId);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateSprintDialog(BuildContext context, String projectId) async {
    final nameCtrl = TextEditingController();
    final goalCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('새 스프린트'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: goalCtrl,
                decoration: const InputDecoration(labelText: '목표'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final ok = await context.read<SprintProvider>().createSprint(
                      projectId: projectId,
                      name: name,
                      goal: goalCtrl.text.trim().isEmpty ? null : goalCtrl.text.trim(),
                    );
                if (ok && context.mounted) {
                  Navigator.of(dialogContext).pop();
                  final currentProjectId = context.read<ProjectProvider>().currentProject?.id;
                  await context.read<SprintProvider>().loadSprints(projectId: currentProjectId);
                }
              },
              child: const Text('생성'),
            ),
          ],
        );
      },
    );
  }
}
