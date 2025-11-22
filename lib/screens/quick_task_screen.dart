import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../utils/avatar_color.dart';
import 'task_detail_screen.dart';

/// 빠른 태스크 추가 화면
class QuickTaskScreen extends StatefulWidget {
  const QuickTaskScreen({super.key});

  @override
  State<QuickTaskScreen> createState() => _QuickTaskScreenState();
}

class _QuickTaskScreenState extends State<QuickTaskScreen> {
  final TextEditingController _taskController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedTasks = {}; // 펼쳐진 태스크 ID 집합

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    final projectProvider = context.read<ProjectProvider>();
    final currentProjectId = projectProvider.currentProject?.id;
    if (currentProjectId == null) return;

    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.id;
    if (currentUserId == null) return;

    final taskProvider = context.read<TaskProvider>();
    taskProvider.createTask(
      title: text,
      description: '',
      status: TaskStatus.backlog,
      projectId: currentProjectId,
      assignedMemberIds: [currentUserId],
    );

    // 입력창 초기화
    _taskController.clear();

    // 스크롤을 맨 위로 이동 (새 태스크가 하단에 추가되므로)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskProvider = context.watch<TaskProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final currentProjectId = projectProvider.currentProject?.id;

    // 현재 프로젝트의 모든 태스크 필터링
    final allTasks = currentProjectId != null
        ? taskProvider.tasks
            .where((task) => task.projectId == currentProjectId)
            .toList()
        : <Task>[];

    // 최신 태스크가 위에 오도록 정렬 (createdAt 기준 내림차순)
    allTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // 헤더
          Row(
            children: [
              Text(
                '빠른 태스크 추가',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${allTasks.length}개',
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 태스크 리스트 (큐 형태)
          Expanded(
            child: allTasks.isEmpty
                ? Center(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(40),
                      borderRadius: 30.0,
                      blur: 25.0,
                      gradientColors: [
                        colorScheme.surface.withOpacity(0.3),
                        colorScheme.surface.withOpacity(0.2),
                      ],
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '태스크가 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '하단 입력창에서 태스크를 추가하세요',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: false, // 최신 태스크가 위에
                    itemCount: allTasks.length,
                    itemBuilder: (context, index) {
                      final task = allTasks[index];
                      final statusColor = task.status.color;
                      final isExpanded = _expandedTasks.contains(task.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedTasks.remove(task.id);
                              } else {
                                _expandedTasks.add(task.id);
                              }
                            });
                          },
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 15.0,
                            blur: 25.0,
                            borderWidth: 1.0,
                            gradientColors: [
                              colorScheme.surface.withOpacity(0.6),
                              colorScheme.surface.withOpacity(0.5),
                            ],
                            borderColor: statusColor.withOpacity(0.3),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // 상태 색상 인디케이터
                                    Container(
                                      width: 4,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 태스크 내용
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          if (task.description.isNotEmpty && !isExpanded) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              task.description,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.7),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          // 할당된 팀원 태그
                                          if (task.assignedMemberIds.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            FutureBuilder<List<dynamic>>(
                                              future: _loadAssignedMembers(task.assignedMemberIds),
                                              builder: (context, snapshot) {
                                                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                                  return const SizedBox.shrink();
                                                }
                                                final members = snapshot.data!;
                                                return Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: members.map((member) {
                                                    return GlassContainer(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      borderRadius: 6.0,
                                                      blur: 10.0,
                                                      gradientColors: [
                                                        colorScheme.primary.withOpacity(0.2),
                                                        colorScheme.primary.withOpacity(0.1),
                                                      ],
                                                      borderColor: colorScheme.primary.withOpacity(0.3),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          CircleAvatar(
                                                            radius: 6,
                                                            backgroundColor: AvatarColor.getColorForUser(member.id),
                                                            child: Text(
                                                              AvatarColor.getInitial(member.username),
                                                              style: const TextStyle(
                                                                fontSize: 8,
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            member.username,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: colorScheme.onSurface,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                const SizedBox(width: 12),
                                // 오른쪽 정보 (시작일, 종료일, 상태) - 한 줄로
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _pickTaskDateRange(
                                          context, task, taskProvider),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: (task.startDate != null ||
                                                  task.endDate != null)
                                              ? colorScheme.primary
                                                  .withOpacity(0.12)
                                              : colorScheme.onSurface
                                                  .withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: (task.startDate != null ||
                                                    task.endDate != null)
                                                ? colorScheme.primary.withOpacity(0.4)
                                                : colorScheme.onSurface
                                                    .withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.date_range,
                                              size: 16,
                                              color: (task.startDate != null ||
                                                      task.endDate != null)
                                                  ? colorScheme.primary
                                                  : colorScheme.onSurface
                                                      .withOpacity(0.4),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _buildRangeLabel(task),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: (task.startDate != null ||
                                                        task.endDate != null)
                                                    ? colorScheme.primary
                                                    : colorScheme.onSurface
                                                        .withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 상태 (클릭 가능)
                                    InkWell(
                                      onTap: () => _showStatusPicker(context, task, taskProvider),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: statusColor.withOpacity(0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.label,
                                              size: 14,
                                              color: statusColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              task.status.displayName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                    const SizedBox(width: 8),
                                    // 편집 버튼
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: colorScheme.primary.withOpacity(0.7),
                                      ),
                                      onPressed: () {
                                        showGeneralDialog(
                                          context: context,
                                          barrierColor: Colors.black.withOpacity(0.2),
                                          transitionDuration: Duration.zero,
                                          pageBuilder: (context, animation, secondaryAnimation) => TaskDetailScreen(task: task),
                                          transitionBuilder: (context, animation, secondaryAnimation, child) => child,
                                        );
                                      },
                                      tooltip: '편집',
                                    ),
                                    // 삭제 버튼
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        size: 20,
                                        color: Colors.red.withOpacity(0.7),
                                      ),
                                      onPressed: () {
                                        _showDeleteConfirmDialog(
                                            context, task, taskProvider);
                                      },
                                      tooltip: '삭제',
                                    ),
                                  ],
                                ),
                                // 펼쳐진 상세 내용
                                if (isExpanded) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 설명
                                        if (task.description.isNotEmpty) ...[
                                          Text(
                                            '설명',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface.withOpacity(0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            task.description,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colorScheme.onSurface.withOpacity(0.7),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        // 상세 내용
                                        if (task.detail.isNotEmpty) ...[
                                          Text(
                                            '상세 내용',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface.withOpacity(0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            task.detail,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colorScheme.onSurface.withOpacity(0.7),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        // 상세 화면으로 이동 버튼
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  PageRouteBuilder(
                                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                                        TaskDetailScreen(task: task),
                                                    transitionDuration: Duration.zero,
                                                    reverseTransitionDuration: Duration.zero,
                                                  ),
                                                );
                                              },
                                              icon: Icon(
                                                Icons.open_in_new,
                                                size: 16,
                                                color: colorScheme.primary,
                                              ),
                                              label: Text(
                                                '상세 화면에서 편집',
                                                style: TextStyle(
                                                  color: colorScheme.primary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
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
                    },
                  ),
          ),
          const SizedBox(height: 16),
          // 하단 입력창
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: 20.0,
            blur: 25.0,
            gradientColors: [
              colorScheme.surface.withOpacity(0.6),
              colorScheme.surface.withOpacity(0.5),
            ],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: '태스크를 입력하고 Enter를 누르세요...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTask(),
                    autofocus: false,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: colorScheme.primary,
                  ),
                  onPressed: _addTask,
                  tooltip: '추가',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 태스크 삭제 확인 다이얼로그
  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        final dialogColorScheme = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 20.0,
              blur: 25.0,
              gradientColors: [
                dialogColorScheme.surface.withOpacity(0.6),
                dialogColorScheme.surface.withOpacity(0.5),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '태스크 삭제',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: dialogColorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\'${task.title}\' 태스크를 삭제하시겠습니까?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: dialogColorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            color: dialogColorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text(
                          '삭제',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await taskProvider.deleteTask(task.id);
    }
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _buildRangeLabel(Task task) {
    final hasStart = task.startDate != null;
    final hasEnd = task.endDate != null;

    if (!hasStart && !hasEnd) {
      return '기간 설정';
    }

    final startText =
        hasStart ? _formatDate(task.startDate!) : '시작 미정';
    final endText = hasEnd ? _formatDate(task.endDate!) : '종료 미정';
    return '$startText ~ $endText';
  }

  /// 기간 선택 다이얼로그
  Future<void> _pickTaskDateRange(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) async {
    final result = await showTaskDateRangePickerDialog(
      context: context,
      initialStartDate: task.startDate,
      initialEndDate: task.endDate,
      minDate: DateTime(2020),
      maxDate: DateTime(2030),
    );

    if (result != null && context.mounted) {
      await taskProvider.updateTask(
        task.copyWith(
          startDate: result['startDate'],
          endDate: result['endDate'],
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  /// 상태 선택 다이얼로그
  Future<void> _showStatusPicker(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    TaskStatus? selectedStatus = task.status;

    final result = await showDialog<TaskStatus>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 500,
                ),
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 20.0,
                  blur: 25.0,
                  gradientColors: [
                    colorScheme.surface.withOpacity(0.6),
                    colorScheme.surface.withOpacity(0.5),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '상태 선택',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 모든 상태 옵션 표시
                      ...TaskStatus.values.map((status) {
                        final statusColor = status.color;
                        final isSelected = selectedStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                selectedStatus = status;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? statusColor.withOpacity(0.2)
                                    : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? statusColor.withOpacity(0.8)
                                      : colorScheme.onSurface.withOpacity(0.2),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      status.displayName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? statusColor
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      color: statusColor,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      // 버튼
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              '취소',
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (selectedStatus != null) {
                                Navigator.of(context).pop(selectedStatus);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      await taskProvider.updateTask(
        task.copyWith(
          status: result,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  /// 할당된 팀원 목록 로드
  Future<List<dynamic>> _loadAssignedMembers(List<String> memberIds) async {
    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      return allUsers.where((user) => memberIds.contains(user.id)).toList();
    } catch (e) {
      return [];
    }
  }
}

