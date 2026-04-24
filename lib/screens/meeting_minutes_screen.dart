import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../models/meeting_minutes.dart';
import '../models/task.dart';
import '../models/workspace.dart';
import '../models/site_detail.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/meeting_minutes_service.dart';
import '../services/task_service.dart';
import '../services/site_detail_service.dart';
import '../services/project_site_service.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../widgets/glass_container.dart';
import 'task_detail_screen.dart';

// ─── 회의록 줄 ↔ 태스크 링크 마커 ────────────────────────────────
// 회의록 본문의 각 줄 끝에 ` <!--mm:UUID-->` 형태로 삽입되어,
// 해당 줄에서 생성된 태스크와 영구적으로 연결된다. 회의록 편집/이동에도
// 마커가 줄과 함께 이동하므로 위치 변화에 강인하다.
final RegExp _mmLineMarkerRegex = RegExp(r'<!--mm:([0-9a-fA-F-]{36})-->');

/// 줄 텍스트에서 마커 UUID 를 뽑아 (stripped, lineId) 로 반환. 마커 없으면 lineId=null.
({String stripped, String? lineId}) _parseLineMarker(String line) {
  final match = _mmLineMarkerRegex.firstMatch(line);
  if (match == null) return (stripped: line, lineId: null);
  final stripped = line.replaceAll(_mmLineMarkerRegex, '').trimRight();
  return (stripped: stripped, lineId: match.group(1));
}

/// UUID v4 생성 (uuid 패키지 미사용).
String _generateUuidV4() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant
  String h(int v) => v.toRadixString(16).padLeft(2, '0');
  return '${h(b[0])}${h(b[1])}${h(b[2])}${h(b[3])}-'
      '${h(b[4])}${h(b[5])}-'
      '${h(b[6])}${h(b[7])}-'
      '${h(b[8])}${h(b[9])}-'
      '${h(b[10])}${h(b[11])}${h(b[12])}${h(b[13])}${h(b[14])}${h(b[15])}';
}

// ─── 카테고리 트리 노드 ───────────────────────────────────────────
class _CategoryNode {
  final String name;
  final String fullPath; // "정기회의/주간회의" 형태
  final Map<String, _CategoryNode> children = {};
  int count = 0; // 이 경로에 속한 회의록 수 (하위 포함)

  _CategoryNode(this.name, this.fullPath);
}

/// 카테고리 목록을 트리로 변환
_CategoryNode _buildCategoryTreeHelper(List<String> categories, List<MeetingMinutes> minutes) {
  final root = _CategoryNode('', '');

  // 모든 카테고리 경로에서 트리 구축
  for (final cat in categories) {
    if (cat.isEmpty) continue;
    final parts = cat.split('/');
    var current = root;
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty) continue;
      final pathSoFar = parts.sublist(0, i + 1).join('/');
      current.children.putIfAbsent(part, () => _CategoryNode(part, pathSoFar));
      current = current.children[part]!;
    }
  }

  // 각 노드에 회의록 수 계산
  for (final m in minutes) {
    if (m.category.isEmpty) {
      root.count++;
      continue;
    }
    final parts = m.category.split('/');
    var current = root;
    current.count++;
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (current.children.containsKey(trimmed)) {
        current = current.children[trimmed]!;
        current.count++;
      }
    }
  }

  return root;
}

// ─── 메인 화면 ─────────────────────────────────────────────────
class MeetingMinutesScreen extends StatefulWidget {
  const MeetingMinutesScreen({super.key});

  @override
  State<MeetingMinutesScreen> createState() => _MeetingMinutesScreenState();
}

class _MeetingMinutesScreenState extends State<MeetingMinutesScreen> {
  final MeetingMinutesService _service = MeetingMinutesService();
  final TaskService _taskService = TaskService();

  bool _isLoading = false;
  List<MeetingMinutes> _allMinutesList = []; // 전체 (필터 전)
  List<MeetingMinutes> _minutesList = []; // 표시용 (필터 후)
  String? _selectedCategory; // 선택된 카테고리 경로 (null=전체)
  MeetingMinutes? _selectedMinutes;
  _CategoryNode _categoryTree = _CategoryNode('', '');
  final Set<String> _expandedPaths = {}; // 펼쳐진 폴더 경로

  // 선택된 회의록에 연결된 태스크 맵 (line UUID → Task)
  Map<String, Task> _lineTaskMap = {};

  // 편집 모드
  bool _isEditing = false;
  bool _isCreating = false;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _editingCategory = ''; // 편집 중인 카테고리 경로
  DateTime _meetingDate = DateTime.now();
  List<String> _selectedAttendeeIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final wsProvider = context.read<WorkspaceProvider>();
    final wsId = wsProvider.currentWorkspaceId;
    if (wsId == null) return;

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getAll(workspaceId: wsId),
        _service.getCategories(workspaceId: wsId),
      ]);
      if (!mounted) return;
      final allMinutes = results[0] as List<MeetingMinutes>;
      final categories = results[1] as List<String>;
      setState(() {
        _allMinutesList = allMinutes;
        _categoryTree = _buildCategoryTreeHelper(categories, allMinutes);
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회의록 로딩 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 선택된 회의록에서 생성된 태스크 목록을 조회해 `lineId → Task` 맵 구축.
  Future<void> _loadLinkedTasks(String minutesId) async {
    setState(() => _lineTaskMap = {});
    try {
      final tasks = await _taskService.getAllTasks(sourceMeetingMinutesId: minutesId);
      if (!mounted) return;
      final map = <String, Task>{};
      for (final t in tasks) {
        final lid = t.sourceLineId;
        if (lid != null && lid.isNotEmpty) {
          map[lid] = t;
        }
      }
      setState(() => _lineTaskMap = map);
    } catch (_) {
      // 태스크 맵 로드 실패는 조용히 무시 (체크 마커만 표시 안 됨)
    }
  }

  void _applyFilter() {
    if (_selectedCategory == null) {
      _minutesList = List.from(_allMinutesList);
    } else {
      _minutesList = _allMinutesList.where((m) {
        // 선택된 경로와 일치하거나 하위 경로인 회의록
        return m.category == _selectedCategory ||
            m.category.startsWith('$_selectedCategory/');
      }).toList();
    }
    // 선택된 회의록이 필터 결과에 없으면 해제
    if (_selectedMinutes != null &&
        !_minutesList.any((m) => m.id == _selectedMinutes!.id)) {
      _selectedMinutes = null;
    }
  }

  void _startCreating() {
    setState(() {
      _isCreating = true;
      _isEditing = true;
      _selectedMinutes = null;
      _titleController.text = '';
      _contentController.text = '';
      _editingCategory = _selectedCategory ?? '';
      _meetingDate = DateTime.now();
      _selectedAttendeeIds = [];
    });
  }

  void _startEditing() {
    if (_selectedMinutes == null) return;
    setState(() {
      _isEditing = true;
      _isCreating = false;
      _titleController.text = _selectedMinutes!.title;
      _contentController.text = _selectedMinutes!.content;
      _editingCategory = _selectedMinutes!.category;
      _meetingDate = _selectedMinutes!.meetingDate;
      _selectedAttendeeIds = List.from(_selectedMinutes!.attendeeIds);
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _isCreating = false;
    });
  }

  Future<void> _save() async {
    final wsId = context.read<WorkspaceProvider>().currentWorkspaceId;
    if (wsId == null) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요.')),
      );
      return;
    }

    try {
      if (_isCreating) {
        final created = await _service.create(
          workspaceId: wsId,
          title: title,
          content: _contentController.text,
          category: _editingCategory.trim(),
          meetingDate: _meetingDate,
          attendeeIds: _selectedAttendeeIds,
        );
        setState(() {
          _selectedMinutes = created;
          _isEditing = false;
          _isCreating = false;
        });
        _loadLinkedTasks(created.id);
      } else if (_selectedMinutes != null) {
        final updated = await _service.update(
          _selectedMinutes!.id,
          title: title,
          content: _contentController.text,
          category: _editingCategory.trim(),
          meetingDate: _meetingDate,
          attendeeIds: _selectedAttendeeIds,
        );
        setState(() {
          _selectedMinutes = updated;
          _isEditing = false;
        });
        _loadLinkedTasks(updated.id);
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  Future<void> _delete() async {
    if (_selectedMinutes == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회의록 삭제'),
        content: const Text('이 회의록을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.delete(_selectedMinutes!.id);
      setState(() {
        _selectedMinutes = null;
        _isEditing = false;
      });
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  /// 이미 연결된 태스크를 다이얼로그로 열기.
  void _openLinkedTask(Task task) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => TaskDetailScreen(task: task),
    );
  }

  /// 회의록 특정 줄(줄 번호 기준) 에서 작업을 생성한다.
  /// 성공 시 해당 줄 끝에 `<!--mm:UUID-->` 마커를 삽입하고 회의록 본문을 갱신한다.
  Future<void> _createTaskFromLine(int lineIndex) async {
    final minutes = _selectedMinutes;
    if (minutes == null) return;

    final rawLines = minutes.content.split('\n');
    if (lineIndex < 0 || lineIndex >= rawLines.length) return;
    final rawLine = rawLines[lineIndex];
    final parsed = _parseLineMarker(rawLine);
    final existingLineId = parsed.lineId;
    final lineText = parsed.stripped;

    final projectProvider = context.read<ProjectProvider>();
    final projects = projectProvider.projects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로젝트가 없습니다. 프로젝트를 먼저 생성해주세요.')),
      );
      return;
    }

    final cleanText = lineText
        .replaceFirst(RegExp(r'^\s*[-*+]\s+'), '')
        .replaceFirst(RegExp(r'^\s*\d+\.\s+'), '')
        .replaceFirst(RegExp(r'^\s*#+\s+'), '')
        .replaceFirst(RegExp(r'^\s*>\s+'), '')
        .trim();

    final titleController = TextEditingController(text: cleanText);
    String? selectedProjectId = projectProvider.currentProject?.id ?? projects.first.id;
    TaskStatus selectedStatus = TaskStatus.backlog;
    TaskPriority selectedPriority = TaskPriority.p2;
    DateTime? startDate;
    DateTime? endDate;
    String? selectedSiteName;
    List<SiteDetail> availableSites = [];
    try {
      availableSites = await SiteDetailService().listSites();
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickDateRange() async {
              final result = await showTaskDateRangePickerDialog(
                context: context,
                initialStartDate: startDate,
                initialEndDate: endDate,
              );
              if (result != null) {
                setState(() {
                  startDate = result['startDate'];
                  endDate = result['endDate'];
                });
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height - 48,
                ),
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 20.0,
                  blur: 25.0,
                  gradientColors: [
                    colorScheme.surface.withValues(alpha: 0.6),
                    colorScheme.surface.withValues(alpha: 0.5),
                  ],
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '새 태스크 추가',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),
                        GlassTextField(
                          controller: titleController,
                          labelText: '제목',
                          prefixIcon: const Icon(Icons.title),
                        ),
                        const SizedBox(height: 20),
                        // 프로젝트 선택
                        DropdownButtonFormField<String>(
                          value: projects.any((p) => p.id == selectedProjectId) ? selectedProjectId : null,
                          decoration: InputDecoration(
                            labelText: '프로젝트',
                            prefixIcon: const Icon(Icons.folder_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          items: projects.map((p) {
                            return DropdownMenuItem(value: p.id, child: Text(p.name));
                          }).toList(),
                          onChanged: (v) => setState(() => selectedProjectId = v),
                        ),
                        const SizedBox(height: 20),
                        // 상태
                        Text(
                          '상태',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: TaskStatus.values.map((status) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(status.displayName),
                                  selected: selectedStatus == status,
                                  onSelected: (selected) {
                                    if (selected) setState(() => selectedStatus = status);
                                  },
                                  selectedColor: status.color.withValues(alpha: 0.3),
                                  labelStyle: TextStyle(
                                    color: selectedStatus == status
                                        ? status.color
                                        : colorScheme.onSurface,
                                    fontWeight: selectedStatus == status
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        // 중요도
                        Text(
                          '중요도',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: TaskPriority.values.map((priority) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: priority.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(priority.displayName),
                                    ],
                                  ),
                                  selected: selectedPriority == priority,
                                  onSelected: (selected) {
                                    if (selected) setState(() => selectedPriority = priority);
                                  },
                                  selectedColor: priority.color.withValues(alpha: 0.3),
                                  labelStyle: TextStyle(
                                    color: selectedPriority == priority
                                        ? priority.color
                                        : colorScheme.onSurface,
                                    fontWeight: selectedPriority == priority
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        // 시작일
                        Text(
                          '시작일',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: pickDateRange,
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 12.0,
                            blur: 20.0,
                            gradientColors: [
                              colorScheme.surface.withValues(alpha: 0.3),
                              colorScheme.surface.withValues(alpha: 0.2),
                            ],
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 20,
                                    color: colorScheme.onSurface.withValues(alpha: 0.7)),
                                const SizedBox(width: 12),
                                Text(
                                  startDate != null
                                      ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                                      : '날짜 선택',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: startDate != null
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 종료일
                        Text(
                          '종료일',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: pickDateRange,
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 12.0,
                            blur: 20.0,
                            gradientColors: [
                              colorScheme.surface.withValues(alpha: 0.3),
                              colorScheme.surface.withValues(alpha: 0.2),
                            ],
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 20,
                                    color: colorScheme.onSurface.withValues(alpha: 0.7)),
                                const SizedBox(width: 12),
                                Text(
                                  endDate != null
                                      ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                                      : '날짜 선택',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: endDate != null
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 사이트
                        DropdownButtonFormField<String>(
                          value: availableSites.any((s) => s.name == selectedSiteName) ? selectedSiteName : null,
                          decoration: InputDecoration(
                            labelText: '사이트',
                            prefixIcon: const Icon(Icons.dns_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('없음')),
                            ...availableSites.map((site) {
                              return DropdownMenuItem(value: site.name, child: Text(site.name));
                            }),
                          ],
                          onChanged: (v) => setState(() => selectedSiteName = v),
                        ),
                        const SizedBox(height: 24),
                        // 버튼
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('취소', style: TextStyle(color: colorScheme.onSurface)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassButton(
                                text: '추가',
                                onPressed: () async {
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('제목을 입력해주세요.')),
                                    );
                                    return;
                                  }
                                  if (selectedProjectId == null) return;
                                  final authProvider = context.read<AuthProvider>();
                                  final currentUserId = authProvider.currentUser?.id;
                                  if (currentUserId == null) return;

                                  final taskProvider = context.read<TaskProvider>();
                                  // 회의록 줄 UUID: 기존 마커가 있으면 재사용, 없으면 새로 발급
                                  final lineId = existingLineId ?? _generateUuidV4();
                                  final createdTask = await taskProvider.createTaskReturning(
                                    title: titleController.text.trim(),
                                    description: '',
                                    status: selectedStatus,
                                    projectId: selectedProjectId!,
                                    startDate: startDate,
                                    endDate: endDate,
                                    priority: selectedPriority,
                                    assignedMemberIds: [currentUserId],
                                    siteTags: selectedSiteName != null ? [selectedSiteName!] : [],
                                    sourceMeetingMinutesId: minutes.id,
                                    sourceLineId: lineId,
                                  );
                                  if (createdTask == null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(taskProvider.errorMessage ?? '태스크 생성에 실패했습니다.'),
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                      ),
                                    );
                                  }
                                  if (createdTask != null) {
                                    taskProvider.loadTasks(projectId: selectedProjectId!);
                                    if (selectedSiteName != null) {
                                      try {
                                        await ProjectSiteService().createSite(
                                          projectId: selectedProjectId!,
                                          name: selectedSiteName!,
                                        );
                                      } catch (_) {}
                                    }
                                    // 회의록 본문에 줄 마커 삽입 (기존 마커 있으면 스킵)
                                    if (existingLineId == null) {
                                      try {
                                        final lines = minutes.content.split('\n');
                                        if (lineIndex < lines.length) {
                                          final stripped = _parseLineMarker(lines[lineIndex]).stripped.trimRight();
                                          lines[lineIndex] = '$stripped <!--mm:$lineId-->';
                                          final newContent = lines.join('\n');
                                          final updated = await _service.update(
                                            minutes.id,
                                            content: newContent,
                                          );
                                          if (mounted) {
                                            setState(() => _selectedMinutes = updated);
                                          }
                                        }
                                      } catch (e) {
                                        // 마커 삽입 실패해도 태스크 자체는 생성됨 — 다음 로드 시 재시도 가능
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('줄 마커 저장 실패(태스크는 생성됨): $e')),
                                          );
                                        }
                                      }
                                    }
                                    if (mounted) {
                                      setState(() {
                                        _lineTaskMap = {..._lineTaskMap, lineId: createdTask};
                                      });
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('작업 "${titleController.text.trim()}" 생성 완료')),
                                      );
                                    }
                                  }
                                  if (context.mounted) Navigator.of(context).pop();
                                },
                                gradientColors: [
                                  colorScheme.primary.withValues(alpha: 0.5),
                                  colorScheme.primary.withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // titleController와 siteController는 다이얼로그가 닫힌 후 dispose되지 않지만
    // 다이얼로그 컨텍스트와 함께 GC됨
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wsProvider = context.watch<WorkspaceProvider>();

    if (wsProvider.currentWorkspace == null) {
      return const Center(child: Text('워크스페이스를 선택해주세요.'));
    }

    return Row(
      children: [
        // 좌측 패널: 카테고리 트리 + 회의록 목록
        SizedBox(
          width: 320,
          child: _buildListPanel(isDark, wsProvider),
        ),
        Container(width: 1, color: isDark ? Colors.white12 : Colors.black12),
        // 우측 패널: 상세/편집
        Expanded(
          child: _buildDetailPanel(isDark, wsProvider),
        ),
      ],
    );
  }

  // ─── 좌측 패널 ───────────────────────────────────────────────
  Widget _buildListPanel(bool isDark, WorkspaceProvider wsProvider) {
    final bgColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F9FA);

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 24, color: isDark ? Colors.white70 : Colors.black87),
                const SizedBox(width: 8),
                Text(
                  '회의록',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  tooltip: '새 폴더',
                  onPressed: () => _showCreateFolderDialog(isDark),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: '새 회의록',
                  onPressed: _startCreating,
                ),
              ],
            ),
          ),
          // 카테고리 트리
          _buildCategoryTree(isDark),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          // 회의록 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _minutesList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 8),
                            Text(
                              _selectedCategory != null ? '이 폴더에 회의록이 없습니다' : '회의록이 없습니다',
                              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _minutesList.length,
                        itemBuilder: (ctx, i) => _buildMinutesListItem(
                          _minutesList[i],
                          wsProvider.currentMembers,
                          isDark,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ─── 카테고리 트리 위젯 ──────────────────────────────────────────
  Widget _buildCategoryTree(bool isDark) {
    final hasCategories = _categoryTree.children.isNotEmpty;
    if (!hasCategories) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "전체" 항목
            _buildTreeItem(
              icon: Icons.folder_open,
              label: '전체',
              count: _allMinutesList.length,
              isSelected: _selectedCategory == null,
              onTap: () {
                setState(() {
                  _selectedCategory = null;
                  _applyFilter();
                });
              },
              depth: 0,
              isDark: isDark,
            ),
            // 트리 노드들
            ..._categoryTree.children.values.map(
              (node) => _buildTreeNode(node, 0, isDark),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeNode(_CategoryNode node, int depth, bool isDark) {
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expandedPaths.contains(node.fullPath);
    final isSelected = _selectedCategory == node.fullPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTreeItem(
          icon: hasChildren
              ? (isExpanded ? Icons.folder_open : Icons.folder)
              : Icons.folder_outlined,
          label: node.name,
          count: node.count,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (_selectedCategory == node.fullPath) {
                _selectedCategory = null;
              } else {
                _selectedCategory = node.fullPath;
              }
              _applyFilter();
            });
          },
          onExpandTap: hasChildren
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedPaths.remove(node.fullPath);
                    } else {
                      _expandedPaths.add(node.fullPath);
                    }
                  });
                }
              : null,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          depth: depth + 1,
          isDark: isDark,
        ),
        if (hasChildren && isExpanded)
          ...node.children.values.map(
            (child) => _buildTreeNode(child, depth + 1, isDark),
          ),
      ],
    );
  }

  Widget _buildTreeItem({
    required IconData icon,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onExpandTap,
    bool isExpanded = false,
    bool hasChildren = false,
    required int depth,
    required bool isDark,
  }) {
    final leftPadding = 8.0 + depth * 16.0;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.only(left: leftPadding, right: 8, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: isDark ? 0.15 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // 펼치기/접기 화살표
              if (hasChildren)
                GestureDetector(
                  onTap: onExpandTap,
                  child: Icon(
                    isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                )
              else
                const SizedBox(width: 18),
              const SizedBox(width: 2),
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white38 : Colors.black45),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? primaryColor
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 새 폴더 생성 다이얼로그 ────────────────────────────────────
  Future<void> _showCreateFolderDialog(bool isDark) async {
    final controller = TextEditingController();
    // 현재 선택된 카테고리를 상위 경로로 사용
    final parentPath = _selectedCategory ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('새 폴더 생성'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (parentPath.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.folder, size: 16, color: isDark ? Colors.white38 : Colors.black45),
                      const SizedBox(width: 6),
                      Text(
                        '상위: $parentPath',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '폴더 이름',
                    border: OutlineInputBorder(),
                    hintText: '예: 주간회의',
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) Navigator.pop(ctx, name);
              },
              child: const Text('생성'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (result == null) return;

    // 새 카테고리 경로를 만들어서 빈 회의록 하나 생성 (폴더가 존재하도록)
    // → 실제로는 카테고리만 등록하면 되므로, 해당 경로로 새 회의록 생성 시작
    final newPath = parentPath.isEmpty ? result : '$parentPath/$result';
    setState(() {
      _selectedCategory = newPath;
      _expandedPaths.add(parentPath);
      // 새 폴더로 바로 회의록 작성 시작
      _isCreating = true;
      _isEditing = true;
      _selectedMinutes = null;
      _titleController.text = '';
      _contentController.text = '';
      _editingCategory = newPath;
      _meetingDate = DateTime.now();
      _selectedAttendeeIds = [];
    });
  }

  // ─── 회의록 리스트 아이템 ─────────────────────────────────────────
  Widget _buildMinutesListItem(
    MeetingMinutes minutes,
    List<WorkspaceMember> members,
    bool isDark,
  ) {
    final isSelected = _selectedMinutes?.id == minutes.id;
    final dateStr = DateFormat('yyyy.MM.dd').format(minutes.meetingDate);
    final colorScheme = Theme.of(context).colorScheme;
    final attendees = minutes.attendeeIds
        .map((id) {
          final m = members.where((m) => m.userId == id);
          return m.isNotEmpty ? m.first : null;
        })
        .whereType<WorkspaceMember>()
        .toList();

    final creatorMatch = members.where((m) => m.userId == minutes.creatorId);
    final creatorName = creatorMatch.isNotEmpty ? creatorMatch.first.username : '';
    final creatorText = '작성자 - ${creatorName.isEmpty ? '-' : creatorName}';

    final attendeeText = attendees.isEmpty
        ? '참여자 - -'
        : '참여자 - ${attendees.map((m) => m.username).join(', ')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMinutes = minutes;
            _isEditing = false;
            _isCreating = false;
          });
          _loadLinkedTasks(minutes.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: isSelected
                        ? colorScheme.primary
                        : (isDark ? Colors.white30 : Colors.black26),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      minutes.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? colorScheme.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  creatorText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  attendeeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 우측 패널: 상세/편집 ──────────────────────────────────────
  Widget _buildDetailPanel(bool isDark, WorkspaceProvider wsProvider) {
    if (_selectedMinutes == null && !_isCreating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 64, color: isDark ? Colors.white12 : Colors.black12),
            const SizedBox(height: 12),
            Text(
              '회의록을 선택하거나 새로 작성하세요',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _startCreating,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 회의록 작성'),
            ),
          ],
        ),
      );
    }

    if (_isEditing) {
      return _buildEditor(isDark, wsProvider);
    }

    return _buildViewer(isDark, wsProvider);
  }

  // ─── 에디터 ────────────────────────────────────────────────────
  Widget _buildEditor(bool isDark, WorkspaceProvider wsProvider) {
    final members = wsProvider.currentMembers;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 바
          Row(
            children: [
              Text(
                _isCreating ? '새 회의록' : '회의록 편집',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: _cancelEditing, child: const Text('취소')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('저장'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 제목
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // 날짜 + 카테고리
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showSingleDatePickerDialog(
                      context: context,
                      initialDate: _meetingDate,
                      title: '회의 날짜',
                    );
                    if (picked != null) setState(() => _meetingDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '회의 날짜',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('yyyy-MM-dd').format(_meetingDate)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 카테고리 선택기 (트리 기반)
              Expanded(
                child: InkWell(
                  onTap: () => _showCategoryPickerDialog(isDark),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '카테고리',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.folder_open, size: 18),
                    ),
                    child: _editingCategory.isEmpty
                        ? Text(
                            '분류 선택...',
                            style: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black38,
                            ),
                          )
                        : _buildCategoryBreadcrumb(_editingCategory, isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 참석자 선택
          _buildAttendeeSelector(members, isDark),
          const SizedBox(height: 16),
          // 마크다운 에디터
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontFamily: 'NanumSquareRound',
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: '마크다운으로 회의 내용을 작성하세요...\n\n예시:\n# 회의 정리\n\n1. 서비스 이름 변경 후 공유\n   - AI CA가 아닌 "AI 메타"로 이름 변경\n2. 문서 요약&태깅 동시 수행 결과 공유\n   - 작업 과정: STT&OCR -> colova 요약',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 카테고리 경로를 빵부스러기(breadcrumb) 형태로 표시
  Widget _buildCategoryBreadcrumb(String path, bool isDark) {
    final parts = path.split('/');
    return Row(
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Icon(Icons.chevron_right, size: 14,
                color: isDark ? Colors.white24 : Colors.black26),
          Flexible(
            child: Text(
              parts[i],
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  /// 카테고리 트리 선택 다이얼로그
  Future<void> _showCategoryPickerDialog(bool isDark) async {
    String currentPath = _editingCategory;
    final newFolderController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // 현재 경로의 노드 찾기
            _CategoryNode currentNode = _categoryTree;
            if (currentPath.isNotEmpty) {
              final parts = currentPath.split('/');
              for (final part in parts) {
                if (currentNode.children.containsKey(part)) {
                  currentNode = currentNode.children[part]!;
                } else {
                  break;
                }
              }
            }

            return AlertDialog(
              title: const Text('카테고리 선택'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 현재 경로 (breadcrumb)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open, size: 16,
                              color: isDark ? Colors.white54 : Colors.black45),
                          const SizedBox(width: 6),
                          // 루트로 돌아가기
                          InkWell(
                            onTap: () => setDialogState(() => currentPath = ''),
                            child: Text(
                              '전체',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: currentPath.isEmpty ? FontWeight.w600 : FontWeight.w400,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          if (currentPath.isNotEmpty) ...[
                            // 경로 세그먼트들
                            for (int i = 0; i < currentPath.split('/').length; i++) ...[
                              Icon(Icons.chevron_right, size: 14,
                                  color: isDark ? Colors.white24 : Colors.black26),
                              InkWell(
                                onTap: () {
                                  final parts = currentPath.split('/');
                                  setDialogState(() {
                                    currentPath = parts.sublist(0, i + 1).join('/');
                                  });
                                },
                                child: Text(
                                  currentPath.split('/')[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: i == currentPath.split('/').length - 1
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 하위 폴더 목록
                    Expanded(
                      child: currentNode.children.isEmpty
                          ? Center(
                              child: Text(
                                '하위 폴더가 없습니다',
                                style: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.black38,
                                ),
                              ),
                            )
                          : ListView(
                              children: currentNode.children.values.map((child) {
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    child.children.isNotEmpty ? Icons.folder : Icons.folder_outlined,
                                    size: 20,
                                    color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                                  ),
                                  title: Text(child.name, style: const TextStyle(fontSize: 14)),
                                  trailing: child.children.isNotEmpty
                                      ? const Icon(Icons.chevron_right, size: 18)
                                      : null,
                                  onTap: () {
                                    setDialogState(() => currentPath = child.fullPath);
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    // 새 하위 폴더 추가
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newFolderController,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '새 하위 폴더...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            style: const TextStyle(fontSize: 13),
                            onSubmitted: (v) {
                              if (v.trim().isEmpty) return;
                              final newPath = currentPath.isEmpty ? v.trim() : '$currentPath/${v.trim()}';
                              setDialogState(() {
                                // 트리에 노드 추가
                                currentNode.children.putIfAbsent(
                                  v.trim(),
                                  () => _CategoryNode(v.trim(), newPath),
                                );
                                currentPath = newPath;
                                newFolderController.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.create_new_folder, size: 20),
                          tooltip: '폴더 추가',
                          onPressed: () {
                            final v = newFolderController.text.trim();
                            if (v.isEmpty) return;
                            final newPath = currentPath.isEmpty ? v : '$currentPath/$v';
                            setDialogState(() {
                              currentNode.children.putIfAbsent(
                                v,
                                () => _CategoryNode(v, newPath),
                              );
                              currentPath = newPath;
                              newFolderController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // 분류 없음으로 선택
                    Navigator.pop(ctx, '');
                  },
                  child: const Text('분류 없음'),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, currentPath),
                  child: Text(currentPath.isEmpty ? '전체(분류 없음)' : '선택: ${currentPath.split('/').last}'),
                ),
              ],
            );
          },
        );
      },
    );

    newFolderController.dispose();
    if (result == null) return; // 취소

    setState(() => _editingCategory = result);
  }

  Widget _buildAttendeeSelector(List<WorkspaceMember> members, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '참석자',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: members.map((m) {
            final isSelected = _selectedAttendeeIds.contains(m.userId);
            return FilterChip(
              avatar: CircleAvatar(
                radius: 12,
                backgroundImage: m.profileImageUrl != null
                    ? NetworkImage(m.profileImageUrl!)
                    : null,
                child: m.profileImageUrl == null
                    ? Text(m.username.isNotEmpty ? m.username[0] : '?', style: const TextStyle(fontSize: 10))
                    : null,
              ),
              label: Text(m.username, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedAttendeeIds.add(m.userId);
                  } else {
                    _selectedAttendeeIds.remove(m.userId);
                  }
                });
              },
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── 뷰어 (미리보기 + 작업 생성) ──────────────────────────────────
  Widget _buildViewer(bool isDark, WorkspaceProvider wsProvider) {
    final minutes = _selectedMinutes!;
    final members = wsProvider.currentMembers;
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(minutes.meetingDate);
    final creatorMatch = members.where((m) => m.userId == minutes.creatorId);
    final creatorName = creatorMatch.isNotEmpty ? creatorMatch.first.username : '';
    final attendeeNames = minutes.attendeeIds
        .map((id) {
          final m = members.where((m) => m.userId == id);
          return m.isNotEmpty ? m.first.username : '';
        })
        .where((n) => n.isNotEmpty)
        .toList();

    final lines = minutes.content.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 정보 바
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      minutes.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: '편집',
                    onPressed: _startEditing,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: '삭제',
                    onPressed: _delete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14,
                      color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                  Text(dateStr, style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                  )),
                  if (minutes.category.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.folder_outlined, size: 14,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 4),
                    _buildCategoryBreadcrumb(minutes.category, isDark),
                  ],
                  if (creatorName.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.edit_outlined, size: 14,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      creatorName,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                  if (attendeeNames.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.people_outline, size: 14,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        attendeeNames.join(', '),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // 본문
        Expanded(
          child: minutes.content.trim().isEmpty
              ? Center(
                  child: Text(
                    '내용이 없습니다',
                    style: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: lines.length,
                  itemBuilder: (ctx, i) {
                    final rawLine = lines[i];
                    if (rawLine.trim().isEmpty) {
                      return const SizedBox(height: 8);
                    }
                    final parsed = _parseLineMarker(rawLine);
                    final linkedTask = parsed.lineId != null
                        ? _lineTaskMap[parsed.lineId!]
                        : null;
                    return _HoverableLineWidget(
                      line: parsed.stripped,
                      isDark: isDark,
                      linkedTask: linkedTask,
                      onCreateTask: () => _createTaskFromLine(i),
                      onOpenTask: () {
                        if (linkedTask != null) _openLinkedTask(linkedTask);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 회의록 줄 위젯.
/// - 연결된 태스크가 있으면 체크 마커 상시 표시 + 클릭 시 태스크 상세 다이얼로그
/// - 연결된 태스크가 없으면 호버 시 작업 생성 아이콘 표시
/// - 아이콘 위치는 `IntrinsicWidth + Flexible(loose)` 로 텍스트 끝 바로 옆에 배치
class _HoverableLineWidget extends StatefulWidget {
  final String line;
  final bool isDark;
  final Task? linkedTask;
  final VoidCallback onCreateTask;
  final VoidCallback onOpenTask;

  const _HoverableLineWidget({
    required this.line,
    required this.isDark,
    required this.linkedTask,
    required this.onCreateTask,
    required this.onOpenTask,
  });

  @override
  State<_HoverableLineWidget> createState() => _HoverableLineWidgetState();
}

class _HoverableLineWidgetState extends State<_HoverableLineWidget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final hasTask = widget.linkedTask != null;
    final primary = Theme.of(context).colorScheme.primary;

    final marker = hasTask
        ? Tooltip(
            message: '작업 "${widget.linkedTask!.title}" 으로 이동',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: widget.onOpenTask,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ),
          )
        : AnimatedOpacity(
            opacity: _isHovering ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: Tooltip(
              message: '이 항목으로 작업 생성',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: widget.onCreateTask,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.add_task,
                    size: 18,
                    color: primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          );

    final markdown = MarkdownBody(
      data: widget.line,
      styleSheet: MarkdownStyleSheet(
        // letterSpacing: 0 을 명시해 Material 3 테마의 bodyMedium(기본 0.25)
        // 상속을 차단한다. 이를 통해 TextPainter 측정(letterSpacing 0)과
        // 실제 렌더 폭이 동일해져 마지막 글자가 줄바꿈되는 버그를 방지.
        p: TextStyle(
          fontSize: 14,
          height: 1.6,
          letterSpacing: 0,
          color: widget.isDark ? Colors.white : Colors.black87,
          fontFamily: 'NanumSquareRound',
        ),
        h1: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: widget.isDark ? Colors.white : Colors.black87,
          fontFamily: 'NanumSquareRound',
        ),
        h2: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: widget.isDark ? Colors.white : Colors.black87,
          fontFamily: 'NanumSquareRound',
        ),
        h3: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: widget.isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
          fontFamily: 'NanumSquareRound',
        ),
        listBullet: TextStyle(
          fontSize: 14,
          letterSpacing: 0,
          color: widget.isDark ? Colors.white70 : Colors.black54,
          fontFamily: 'NanumSquareRound',
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: primary.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
      ),
      selectable: true,
    );

    // MarkdownBody 는 자체적으로 가로를 꽉 채우려 해서, TextPainter 로 실제 텍스트
    // 너비를 측정한 뒤 SizedBox 로 감싸 "텍스트 크기만큼만" 렌더링되도록 제한.
    // 헤더/볼드 등으로 인한 측정 오차는 몇 픽셀 수준이라 실용상 수용 가능.
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            const iconReserved = 32.0; // 아이콘 + 좌우 padding
            const hGap = 6.0;
            const hPad = 8.0; // Container padding (horizontal 4 × 2)
            final maxTextWidth =
                (constraints.maxWidth - iconReserved - hGap - hPad).clamp(40.0, double.infinity);

            // MarkdownBody 는 불릿/번호목록을 렌더할 때 좌측에 listIndent(기본 32px)
            // 만큼 들여쓰기를 두고, 실제 텍스트는 (SizedBox 폭 − listIndent) 안에 레이아웃한다.
            // 따라서 측정도 동일한 "콘텐츠 영역" 기준으로 해야 마지막 글자가 밀려 줄바꿈되는
            // 문제가 사라진다. (평문 폭 그대로 재면 긴 줄에서 clamp 에 맞물려 32px 좁게 렌더됨)
            const listIndent = 32.0;
            final headingMatch =
                RegExp(r'^\s*(#+)\s+').firstMatch(widget.line);
            final headingLevel = headingMatch?.group(1)?.length ?? 0;
            final isHeading = headingLevel > 0;
            final isListItem =
                RegExp(r'^\s*([-*+]|\d+\.)\s+').hasMatch(widget.line);
            final indentCompensation = isListItem ? listIndent : 0.0;

            // 접두사 제거 — MarkdownBody 는 "#", 불릿/번호목록, ">" 를 별도 영역(listIndent
            // 또는 헤딩 스타일)에 렌더하므로 측정에서는 빼야 한다. 단, 헤딩 줄("## 1. 일반QC"
            // 처럼 내용에 숫자-점 패턴이 있는 경우) 은 "#+ " 만 벗겨내고, 나머지 list/quote
            // 규칙을 적용하지 않는다 — 그렇지 않으면 "1. 일반QC" 중 "1. " 까지 잘못 제거돼
            // 실제 렌더보다 좁게 측정된다.
            final String contentText;
            if (isHeading) {
              contentText =
                  widget.line.replaceFirst(RegExp(r'^\s*#+\s+'), '');
            } else {
              contentText = widget.line
                  .replaceFirst(RegExp(r'^\s*[-*+]\s+'), '')
                  .replaceFirst(RegExp(r'^\s*\d+\.\s+'), '')
                  .replaceFirst(RegExp(r'^\s*>\s+'), '');
            }

            // 헤딩 레벨(#, ##, ###)을 카운트해 MarkdownBody 스타일시트와 동일한
            // fontSize/fontWeight 로 측정해야 실제 렌더 폭과 어긋나 마지막 글자가
            // 줄바꿈되는 문제를 피할 수 있다.
            double headingFontSize;
            FontWeight headingFontWeight;
            switch (headingLevel) {
              case 1:
                headingFontSize = 22.0;
                headingFontWeight = FontWeight.w800;
                break;
              case 2:
                headingFontSize = 18.0;
                headingFontWeight = FontWeight.w700;
                break;
              case 3:
              default:
                headingFontSize = 16.0;
                headingFontWeight = FontWeight.w700;
            }
            final measureStyle = TextStyle(
              fontFamily: 'NanumSquareRound',
              fontSize: isHeading ? headingFontSize : 14.0,
              fontWeight: isHeading ? headingFontWeight : FontWeight.w400,
              height: 1.6,
              // 렌더 쪽 MarkdownStyleSheet 의 letterSpacing: 0 과 맞춰야 측정/렌더 폭이
              // 일치한다. 기본값이지만 drift 방지 위해 명시.
              letterSpacing: 0,
            );

            // 실제 콘텐츠가 쓸 수 있는 가로 폭 = 전체 − listIndent
            final contentMaxWidth =
                (maxTextWidth - indentCompensation).clamp(20.0, double.infinity);
            final tp = TextPainter(
              text: TextSpan(text: contentText, style: measureStyle),
              textDirection: TextDirection.ltr,
              maxLines: null,
            )..layout(maxWidth: contentMaxWidth);

            // SizedBox 폭 = 콘텐츠 실제 폭 + listIndent(있으면) + 안전 버퍼
            // 안전 버퍼는 TextPainter 와 RenderParagraph 간 서브픽셀/폰트메트릭 오차를 흡수.
            const safetyBuffer = 12.0;
            final markdownWidth =
                (tp.size.width + indentCompensation + safetyBuffer)
                    .clamp(20.0, maxTextWidth);

            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: BoxDecoration(
                  color: _isHovering
                      ? (widget.isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.02))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: markdownWidth, child: markdown),
                    const SizedBox(width: hGap),
                    marker,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
