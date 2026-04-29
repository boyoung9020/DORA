import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../models/project.dart';
import '../../models/user.dart';
import '../../providers/workspace_provider.dart';
import '../../utils/api_client.dart';
import '../../utils/avatar_color.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/date_range_picker_dialog.dart';

/// 업무 보고서 내보내기 다이얼로그를 표시한다.
Future<void> showExportReportDialog({
  required BuildContext context,
  required List<Project> allProjects,
  required Future<List<User>>? usersFuture,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final workspaceId = context.read<WorkspaceProvider>().currentWorkspaceId;

  final allUsers = await (usersFuture ?? Future.value(<User>[]));
  if (!context.mounted) return;
  final memberIdSet = <String>{};
  for (final p in allProjects) {
    memberIdSet.addAll(p.teamMemberIds);
  }
  final teamUsers = allUsers.where((u) => memberIdSet.contains(u.id)).toList()
    ..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

  final selectedProjectIds = <String>{};
  final exportAssigneeIds = <String>{};
  String exportFormat = 'docs';
  DateTime exportStart = DateTime.now().subtract(const Duration(days: 7));
  DateTime exportEnd = DateTime.now();

  String defaultExportTitleForDate(DateTime d) {
    final y = (d.year % 100).toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day 업무 보고';
  }

  final titleController = TextEditingController(
    text: defaultExportTitleForDate(DateTime.now()),
  );
  bool isLoading = false;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 20.0,
              blur: 25.0,
              gradientColors: [
                colorScheme.surface.withValues(alpha: 0.95),
                colorScheme.surface.withValues(alpha: 0.9),
              ],
              child: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.ios_share_outlined, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '업무 보고서 내보내기',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 제목
                    Text('제목', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: '기본: 오늘 날짜(YYMMDD) 기준 — 필요 시 수정',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // 프로젝트 선택
                    Row(
                      children: [
                        Text('프로젝트', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (selectedProjectIds.length == allProjects.length) {
                                selectedProjectIds.clear();
                              } else {
                                selectedProjectIds.clear();
                                selectedProjectIds.addAll(allProjects.map((p) => p.id));
                              }
                            });
                          },
                          child: Text(
                            selectedProjectIds.length == allProjects.length ? '전체 해제' : '전체 선택',
                            style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: allProjects.map((project) {
                            final isSelected = selectedProjectIds.contains(project.id);
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedProjectIds.remove(project.id);
                                  } else {
                                    selectedProjectIds.add(project.id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                      size: 18,
                                      color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        project.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurface,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (selectedProjectIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${selectedProjectIds.length}개 선택됨',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // 기간 선택
                    Text('기간', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showTaskDateRangePickerDialog(
                          context: ctx,
                          initialStartDate: exportStart,
                          initialEndDate: exportEnd,
                          minDate: DateTime(2024),
                          maxDate: DateTime(2030),
                        );
                        if (picked != null) {
                          final s = picked['startDate'];
                          final e = picked['endDate'];
                          if (s != null && e != null) {
                            setDialogState(() {
                              exportStart = s;
                              exportEnd = e;
                            });
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 8),
                            Text(
                              '${exportStart.month}/${exportStart.day} ~ ${exportEnd.month}/${exportEnd.day}',
                              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 담당자
                    Row(
                      children: [
                        Text('담당자', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                        const Spacer(),
                        InkWell(
                          onTap: () => setDialogState(() => exportAssigneeIds.clear()),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.clear_all, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                const SizedBox(width: 4),
                                Text('초기화', style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '선택하지 않으면 기간·프로젝트 내 전체 작업입니다. 선택 시 해당 담당자가 할당된 작업만 포함합니다.',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: teamUsers.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '표시할 팀원이 없습니다. 프로젝트에 팀원이 있는지 확인해 주세요.',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: teamUsers.map((user) {
                                  final isSelected = exportAssigneeIds.contains(user.id);
                                  return InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        if (isSelected) {
                                          exportAssigneeIds.remove(user.id);
                                        } else {
                                          exportAssigneeIds.add(user.id);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                            size: 18,
                                            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(width: 8),
                                          CircleAvatar(
                                            radius: 10,
                                            backgroundColor: AvatarColor.getColorForUser(user.id),
                                            child: Text(
                                              AvatarColor.getInitial(user.username),
                                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              user.username,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colorScheme.onSurface,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    if (exportAssigneeIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${exportAssigneeIds.length}명 선택됨',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // 형식 선택
                    Text('형식', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _FormatOption(
                          label: 'Google Docs',
                          icon: Icons.description_outlined,
                          isSelected: exportFormat == 'docs',
                          onTap: () => setDialogState(() => exportFormat = 'docs'),
                        ),
                        const SizedBox(width: 10),
                        _FormatOption(
                          label: 'Markdown',
                          icon: Icons.code,
                          isSelected: exportFormat == 'md',
                          onTap: () => setDialogState(() => exportFormat = 'md'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 내보내기 버튼
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : () async {
                          setDialogState(() => isLoading = true);
                          try {
                            final report = await _callExportApi(
                              title: titleController.text,
                              workspaceId: workspaceId,
                              projectIds: selectedProjectIds.isEmpty ? null : selectedProjectIds.toList(),
                              startDate: exportStart,
                              endDate: exportEnd,
                              format: exportFormat,
                              assigneeIds: exportAssigneeIds.isEmpty ? null : exportAssigneeIds.toList(),
                            );
                            if (ctx.mounted) {
                              Navigator.of(dialogContext).pop();
                              _showExportResultDialog(context, report, exportFormat);
                            }
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('보고서 생성 실패: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(isLoading ? 'AI 보고서 생성 중...' : 'AI 보고서 생성'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ).then((_) => titleController.dispose());
}

// ─── 내부 헬퍼 ─────────────────────────────────────────────

class _FormatOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
            border: Border.all(color: isSelected ? cs.primary : cs.outline),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? cs.primary : cs.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String> _callExportApi({
  required String title,
  String? workspaceId,
  List<String>? projectIds,
  required DateTime startDate,
  required DateTime endDate,
  required String format,
  List<String>? assigneeIds,
}) async {
  final body = <String, dynamic>{
    'title': title,
    'project_ids': projectIds,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'format': format,
    'task_scope': 'all',
  };
  if (workspaceId != null && workspaceId.isNotEmpty) {
    body['workspace_id'] = workspaceId;
  }
  if (assigneeIds != null && assigneeIds.isNotEmpty) {
    body['assignee_ids'] = assigneeIds;
  }
  final response = await ApiClient.post('/api/ai/export-report', body: body);
  final data = ApiClient.handleResponse(response);
  return data['report'] as String;
}

void _showExportResultDialog(BuildContext context, String report, String format) {
  final colorScheme = Theme.of(context).colorScheme;
  final scrollController = ScrollController();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 20.0,
          blur: 25.0,
          gradientColors: [
            colorScheme.surface.withValues(alpha: 0.95),
            colorScheme.surface.withValues(alpha: 0.9),
          ],
          child: SizedBox(
            width: 600,
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.article_outlined, size: 20, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '보고서',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: report));
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('클립보드에 복사되었습니다'), duration: Duration(seconds: 2)),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('복사'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: format == 'md'
                        ? Markdown(
                            data: report,
                            selectable: true,
                            controller: scrollController,
                            padding: EdgeInsets.zero,
                            styleSheet: MarkdownStyleSheet(
                              h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                              h3: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.primary),
                              p: TextStyle(fontSize: 13, height: 1.6, color: colorScheme.onSurface),
                              listBullet: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                              strong: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                              h2Padding: const EdgeInsets.only(bottom: 8),
                              h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
                              blockSpacing: 6,
                            ),
                          )
                        : Scrollbar(
                            controller: scrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: SelectableText(
                                report,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
