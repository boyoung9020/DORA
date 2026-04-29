import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/site_detail_service.dart';
import '../services/project_site_service.dart';
import '../models/site_detail.dart';
import '../widgets/glass_container.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../utils/avatar_color.dart';
import '../utils/api_client.dart';
import 'task_detail_screen.dart';

/// 칸반 보드 화면
class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  final ScrollController _horizontalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _lastLoadedProjectId;
  bool? _lastLoadedAllMode;
  Map<String, User> _usersById = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    try {
      final users = await AuthService().getAllUsers();
      if (mounted) {
        setState(() {
          _usersById = {for (final u in users) u.id: u};
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectProvider = context.read<ProjectProvider>();
    final projectId = projectProvider.currentProject?.id;
    final isAllMode = projectProvider.isAllProjectsMode;
    if (_lastLoadedProjectId != projectId || _lastLoadedAllMode != isAllMode) {
      _lastLoadedProjectId = projectId;
      _lastLoadedAllMode = isAllMode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TaskProvider>().loadTasks(
            projectId: isAllMode ? null : projectId,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskProvider = context.watch<TaskProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final currentProjectId = projectProvider.currentProject?.id;
    final isAllMode = projectProvider.isAllProjectsMode;

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 검색창
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.brightness == Brightness.dark
                        ? colorScheme.surfaceContainerHighest
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: colorScheme.brightness == Brightness.dark
                          ? colorScheme.onSurface.withValues(alpha: 0.1)
                          : const Color(0xFFE0E7FF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '키워드로 검색...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_searchQuery.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  child: Text(
                    'Discard',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // 칸반 보드
          Expanded(
            child: _buildKanbanBoard(
              context,
              taskProvider,
              currentProjectId,
              isAllMode,
            ),
          ),
        ],
      ),
    );
  }

  bool get _disableBoardDragScroll {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  /// 태스크 필터링
  List<Task> _filterTasks(List<Task> tasks, String? currentProjectId) {
    var filtered = tasks.where((task) {
      if (currentProjectId != null && task.projectId != currentProjectId) {
        return false;
      }
      return true;
    }).toList();

    // 작업 소유자 필터 (글로벌)
    final ownerFilter = context.read<TaskProvider>().taskOwnerFilter;
    if (ownerFilter == 'mine') {
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      if (currentUserId != null) {
        filtered = filtered.where((task) => task.assignedMemberIds.contains(currentUserId)).toList();
      }
    } else if (ownerFilter != null) {
      filtered = filtered.where((task) => task.assignedMemberIds.contains(ownerFilter)).toList();
    }

    // 검색어 필터
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(query) ||
            task.description.toLowerCase().contains(query) ||
            task.detail.toLowerCase().contains(query) ||
            task.status.displayName.toLowerCase().contains(query) ||
            task.priority.displayName.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  /// 칸반 보드 UI 구성
  Widget _buildKanbanBoard(
    BuildContext context,
    TaskProvider taskProvider,
    String? currentProjectId,
    bool isAllMode,
  ) {
    // 로딩 중 상태 표시
    if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '태스크를 불러오는 중...',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // 프로젝트가 없으면 빈 상태 표시
    if (currentProjectId == null && !isAllMode) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '프로젝트가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '관리자에게 프로젝트 참여를 요청하세요',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 너비에 따라 컬럼 너비 계산
        final screenWidth = constraints.maxWidth;
        final columnCount = 5; // 컬럼 개수
        final spacing = 16.0; // 컬럼 간 간격
        final padding = 32.0; // 양쪽 패딩

        // 사용 가능한 너비 계산
        final availableWidth =
            screenWidth - padding - (spacing * (columnCount - 1));
        // 컬럼 너비 계산 (최소 180px로 낮춤, 최대 300px)
        // 화면이 작아도 모든 컬럼이 보이도록 최소값을 낮춤
        final columnWidth = (availableWidth / columnCount).clamp(180.0, 300.0);

        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          thickness: 8.0,
          radius: const Radius.circular(4.0),
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: _disableBoardDragScroll
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColumn(
                  context,
                  TaskStatus.backlog,
                  _filterTasks(
                    taskProvider.getTasksByStatus(
                      TaskStatus.backlog,
                      projectId: isAllMode ? null : currentProjectId,
                    ),
                    currentProjectId,
                  ),
                  taskProvider,
                  currentProjectId: currentProjectId,
                  columnWidth: columnWidth,
                  isAllMode: isAllMode,
                ),
                SizedBox(width: spacing),
                _buildColumn(
                  context,
                  TaskStatus.ready,
                  _filterTasks(
                    taskProvider.getTasksByStatus(
                      TaskStatus.ready,
                      projectId: isAllMode ? null : currentProjectId,
                    ),
                    currentProjectId,
                  ),
                  taskProvider,
                  currentProjectId: currentProjectId,
                  columnWidth: columnWidth,
                  isAllMode: isAllMode,
                ),
                SizedBox(width: spacing),
                _buildColumn(
                  context,
                  TaskStatus.inProgress,
                  _filterTasks(
                    taskProvider.getTasksByStatus(
                      TaskStatus.inProgress,
                      projectId: isAllMode ? null : currentProjectId,
                    ),
                    currentProjectId,
                  ),
                  taskProvider,
                  currentProjectId: currentProjectId,
                  columnWidth: columnWidth,
                  isAllMode: isAllMode,
                ),
                SizedBox(width: spacing),
                _buildColumn(
                  context,
                  TaskStatus.inReview,
                  _filterTasks(
                    taskProvider.getTasksByStatus(
                      TaskStatus.inReview,
                      projectId: isAllMode ? null : currentProjectId,
                    ),
                    currentProjectId,
                  ),
                  taskProvider,
                  currentProjectId: currentProjectId,
                  columnWidth: columnWidth,
                  isAllMode: isAllMode,
                ),
                SizedBox(width: spacing),
                _buildColumn(
                  context,
                  TaskStatus.done,
                  _filterTasks(
                    taskProvider.getTasksByStatus(
                      TaskStatus.done,
                      projectId: isAllMode ? null : currentProjectId,
                    ),
                    currentProjectId,
                  ),
                  taskProvider,
                  currentProjectId: currentProjectId,
                  columnWidth: columnWidth,
                  isAllMode: isAllMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 컬럼 위젯 생성
  Widget _buildColumn(
    BuildContext context,
    TaskStatus status,
    List<Task> tasks,
    TaskProvider taskProvider, {
    String? currentProjectId,
    double columnWidth = 300,
    bool isAllMode = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = status.color;

    return SizedBox(
      width: columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 컬럼 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? colorScheme.surfaceContainer
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${tasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  status.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 태스크 카드들 - 고정 높이로 하단까지 드래그 가능
          Expanded(
            child: DragTarget<Task>(
              onWillAcceptWithDetails: (details) =>
                  details.data.status != status,
              onAcceptWithDetails: (details) async {
                final task = details.data;
                final authProvider = context.read<AuthProvider>();
                final currentUser = authProvider.currentUser;
                if (task.status == status) return;

                final changed = await taskProvider.changeTaskStatus(
                  task.id,
                  status,
                  userId: currentUser?.id,
                  username: currentUser?.username,
                );
                if (!changed) {
                  if (!context.mounted) return;
                  final message =
                      taskProvider.errorMessage ?? '카드 상태를 변경하지 못했습니다.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                  return;
                }

                final updatedStatusTasks = taskProvider.getTasksByStatus(
                  status,
                  projectId: currentProjectId,
                );
                final newOrder = [
                  ...updatedStatusTasks.where((t) => t.id != task.id),
                  ...updatedStatusTasks.where((t) => t.id == task.id),
                ];
                if (newOrder.isNotEmpty) {
                  await taskProvider.reorderTasks(
                    newOrder.map((t) => t.id).toList(),
                  );
                }
              },
              builder: (context, candidateData, rejectedData) {
                final isDraggingOver = candidateData.isNotEmpty;
                final colorScheme = Theme.of(context).colorScheme;
                final isDarkMode =
                    Theme.of(context).brightness == Brightness.dark;

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.transparent
                        : const Color(0xFFFAFBFD),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isDraggingOver
                          ? colorScheme.primary
                          : isDarkMode
                          ? colorScheme.onSurface.withValues(alpha: 0.1)
                          : const Color(0xFFE0E7FF),
                      width: isDraggingOver ? 2 : 1,
                    ),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: isAllMode ? null : () => _showAddTaskDialogForStatus(context, status),
                    child: Stack(
                      children: [
                        // 컬럼에 카드가 있어도 안내 문구는 "배경"으로 항상 깔린다.
                        // 카드가 쌓이면 자연스럽게 가려지고, 빈 공간/문구 탭으로도 추가 가능.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: tasks.isEmpty
                                  ? Text(
                                      '태스크를 여기로 드래그하거나 탭하여 추가하세요',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        if (tasks.isNotEmpty)
                          _buildTaskList(
                            context,
                            status,
                            tasks,
                            taskProvider,
                            statusColor,
                          ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isAllMode ? null : () =>
                                  _showAddTaskDialogForStatus(context, status),
                              borderRadius: BorderRadius.circular(20.0),
                              child: GlassContainer(
                                padding: EdgeInsets.zero,
                                borderRadius: 20.0,
                                blur: 20.0,
                                gradientColors: [
                                  colorScheme.surface.withValues(alpha: 0.6),
                                  colorScheme.surface.withValues(alpha: 0.5),
                                ],
                                borderColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? colorScheme.onSurface.withValues(alpha: 0.2)
                                        : const Color(0xFFE0E7FF),
                                borderWidth: 1.0,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.add,
                                    color: colorScheme.onSurface,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 컬럼 내 태스크 목록
  Widget _buildTaskList(
    BuildContext context,
    TaskStatus status,
    List<Task> tasks,
    TaskProvider taskProvider,
    Color statusColor,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 100),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        return _buildDraggableTaskCard(
          context,
          tasks[i],
          taskProvider,
          statusColor,
        );
      },
    );
  }

  /// 드래그 가능한 태스크 카드 (다른 컬럼으로 이동)
  Widget _buildDraggableTaskCard(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
    Color statusColor,
  ) {
    final card = _buildTaskCardContainer(
      context,
      task,
      statusColor,
      taskProvider,
      reorderable: true,
    );
    final draggingCard = Opacity(opacity: 0.3, child: card);

    final draggable = Draggable<Task>(
      data: task,
      feedback: _buildDragFeedback(context, task, statusColor),
      childWhenDragging: draggingCard,
      child: card,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: draggable,
    );
  }

  /// 드래그 중 표시되는 플로팅 카드 피드백
  Widget _buildDragFeedback(
    BuildContext context,
    Task task,
    Color statusColor,
  ) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(15),
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: statusColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: _buildTaskCardContent(context, task, statusColor),
      ),
    );
  }

  /// 태스크 카드 컨테이너
  Widget _buildTaskCardContainer(
    BuildContext context,
    Task task,
    Color statusColor,
    TaskProvider taskProvider, {
    bool reorderable = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _showTaskDetailScreen(context, task, taskProvider),
      // reorderable 모드: 롱프레스는 드래그 리오더용이므로 컨텍스트 메뉴는 우클릭만
      onLongPressStart: reorderable
          ? null
          : (details) => _showTaskContextMenu(
              context,
              task,
              taskProvider,
              details.globalPosition,
            ),
      onSecondaryTapDown: (details) => _showTaskContextMenu(
        context,
        task,
        taskProvider,
        details.globalPosition,
      ),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 15.0,
        blur: 25.0,
        borderWidth: 1.0,
        gradientColors: [
          colorScheme.surface.withValues(alpha: 0.6),
          colorScheme.surface.withValues(alpha: 0.5),
        ],
        borderColor: Theme.of(context).brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: 0.1)
            : const Color(0xFFE0E7FF),
        child: Stack(
          clipBehavior: Clip.none, // 경계 밖으로 나가는 것을 허용
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildTaskCardContent(context, task, statusColor)],
            ),
            // 오른쪽 상단 할당자 프로필 아이콘
            if (task.assignedMemberIds.isNotEmpty && _usersById.isNotEmpty)
              Positioned(
                top: -6,
                right: -6,
                child: () {
                  final member = _usersById[task.assignedMemberIds.first];
                  if (member == null) return const SizedBox.shrink();
                  if (member.profileImageUrl != null && member.profileImageUrl!.isNotEmpty) {
                    final url = member.profileImageUrl!.startsWith('/')
                        ? '${ApiClient.baseUrl}${member.profileImageUrl!}'
                        : member.profileImageUrl!;
                    return CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(url),
                    );
                  }
                  return CircleAvatar(
                    radius: 12,
                    backgroundColor: AvatarColor.getColorForUser(member.id),
                    child: Text(
                      AvatarColor.getInitial(member.username),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }(),
              ),
          ],
        ),
      ),
    );
  }

  /// 태스크 카드 내용
  Widget _buildTaskCardContent(
    BuildContext context,
    Task task,
    Color statusColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    Project? project;
    try {
      project = projectProvider.projects.firstWhere(
        (p) => p.id == task.projectId,
      );
    } catch (e) {
      project = projectProvider.currentProject;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프로젝트 명
        if (project != null) ...[
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: project.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                project.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // 태스크 제목
        Text(
          task.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        // 중요도 태그
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: task.priority.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: task.priority.color.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: task.priority.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                task.priority.displayName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: task.priority.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 할당된 팀원 목록 로드
  /// 새 태스크 추가 다이얼로그
  void _showAddTaskDialog(BuildContext context) {
    _showAddTaskDialogForStatus(context, TaskStatus.backlog);
  }

  /// 특정 상태로 태스크 추가 다이얼로그
  Future<void> _showAddTaskDialogForStatus(
    BuildContext context,
    TaskStatus initialStatus,
  ) async {
    final projectProvider = context.read<ProjectProvider>();
    if (projectProvider.isAllProjectsMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('태스크를 추가하려면 특정 프로젝트를 선택해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final titleController = TextEditingController();
    final siteController = TextEditingController();
    TaskStatus selectedStatus = initialStatus;
    TaskPriority selectedPriority = TaskPriority.p1;
    DateTime? startDate;
    DateTime? endDate;
    String? selectedSiteName;
    List<SiteDetail> availableSites = [];
    try {
      availableSites = await SiteDetailService().listSites();
    } catch (_) {}

    if (!context.mounted) return;

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
                minDate: DateTime(2020),
                maxDate: DateTime(2030),
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
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ChoiceChip(
                                label: Text(status.displayName),
                                selected: selectedStatus == status,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      selectedStatus = status;
                                    });
                                  }
                                },
                                selectedColor: status.color.withValues(
                                  alpha: 0.3,
                                ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
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
                                  if (selected) {
                                    setState(() {
                                      selectedPriority = priority;
                                    });
                                  }
                                },
                                selectedColor: priority.color.withValues(
                                  alpha: 0.3,
                                ),
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
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                startDate != null
                                    ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                                    : '날짜 선택',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: startDate != null
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
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
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                endDate != null
                                    ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                                    : '날짜 선택',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: endDate != null
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 사이트 선택
                      DropdownButtonFormField<String>(
                        value: availableSites.any((s) => s.name == selectedSiteName) ? selectedSiteName : null,
                        decoration: InputDecoration(
                          labelText: '사이트',
                          prefixIcon: Icon(Icons.dns_outlined, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('없음')),
                          ...availableSites.map((site) {
                            return DropdownMenuItem(value: site.name, child: Text(site.name));
                          }),
                        ],
                        onChanged: (v) => setState(() {
                          selectedSiteName = v;
                          siteController.text = v ?? '';
                        }),
                      ),
                      const SizedBox(height: 24),
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
                          Expanded(
                            child: GlassButton(
                              text: '추가',
                              onPressed: () async {
                                if (titleController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('제목을 입력해주세요.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                final projectProvider = context
                                    .read<ProjectProvider>();
                                final currentProjectId =
                                    projectProvider.currentProject?.id;
                                final authProvider = context
                                    .read<AuthProvider>();
                                final currentUserId =
                                    authProvider.currentUser?.id;
                                if (currentProjectId != null &&
                                    currentUserId != null) {
                                  final taskProvider = context.read<TaskProvider>();
                                  final ok = await taskProvider.createTask(
                                    title: titleController.text.trim(),
                                    description: '',
                                    status: selectedStatus,
                                    projectId: currentProjectId,
                                    startDate: startDate,
                                    endDate: endDate,
                                    priority: selectedPriority,
                                    assignedMemberIds: [currentUserId],
                                    siteTags: selectedSiteName != null ? [selectedSiteName!] : [],
                                  );
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(taskProvider.errorMessage ?? '태스크 생성에 실패했습니다.'),
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                  if (ok) {
                                    taskProvider.loadTasks(projectId: currentProjectId);
                                    // 사이트명이 입력된 경우 project_sites/site_details에 등록
                                    // (이미 존재하면 서버가 기존 레코드를 반환하므로 중복 생성 없음)
                                    if (selectedSiteName != null) {
                                      try {
                                        await ProjectSiteService().createSite(
                                          projectId: currentProjectId,
                                          name: selectedSiteName!,
                                        );
                                      } catch (_) {}
                                    }
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
            );
          },
        );
      },
    );
  }

  /// 태스크 상세 화면 표시
  void _showTaskDetailScreen(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => TaskDetailScreen(task: task),
    );
  }

  /// 태스크 수정 다이얼로그 (사용하지 않음 - 상세 화면으로 대체)
  @Deprecated('TaskDetailScreen으로 대체됨')
  void _showEditTaskDialog(BuildContext context, Task task) {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    TaskStatus selectedStatus = task.status;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
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
                          '태스크 수정',
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
                        const SizedBox(height: 16),
                        GlassTextField(
                          controller: descriptionController,
                          labelText: '설명 (선택사항)',
                          prefixIcon: const Icon(Icons.description),
                          keyboardType: TextInputType.multiline,
                        ),
                        const SizedBox(height: 20),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: ChoiceChip(
                                  label: Text(status.displayName),
                                  selected: selectedStatus == status,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        selectedStatus = status;
                                      });
                                    }
                                  },
                                  selectedColor: status.color.withValues(
                                    alpha: 0.3,
                                  ),
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
                        const SizedBox(height: 24),
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
                            Expanded(
                              child: GlassButton(
                                text: '저장',
                                onPressed: () {
                                  if (titleController.text.trim().isNotEmpty) {
                                    context.read<TaskProvider>().updateTask(
                                      task.copyWith(
                                        title: titleController.text.trim(),
                                        description: descriptionController.text
                                            .trim(),
                                        status: selectedStatus,
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  }
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
  }

  /// 태스크 컨텍스트 메뉴 표시
  void _showTaskContextMenu(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
    Offset position,
  ) {
    final size = MediaQuery.of(context).size;
    final navContext = Navigator.of(context).context;

    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final projectProvider = context.read<ProjectProvider>();
    // all-projects 모드에서 currentProject가 null이면 task의 실제 프로젝트로 조회
    final currentProject = projectProvider.currentProject ??
        (() {
          try {
            return projectProvider.projects.firstWhere(
              (p) => p.id == task.projectId,
            );
          } catch (_) {
            return null;
          }
        }());
    final isPm = currentProject?.creatorId == currentUser?.id;
    final isTaskCreator = task.creatorId == currentUser?.id;
    final canDelete = (currentUser?.isAdmin ?? false) || isPm || isTaskCreator;

    if (!canDelete) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        size.width - position.dx,
        size.height - position.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete' && mounted) {
        _showDeleteConfirmDialog(navContext, task, taskProvider);
      }
    });
  }

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogColorScheme = Theme.of(dialogContext).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 20.0,
              blur: 25.0,
              gradientColors: [
                dialogColorScheme.surface.withValues(alpha: 0.6),
                dialogColorScheme.surface.withValues(alpha: 0.5),
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
                    '${task.title}을(를) 삭제하시겠습니까?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: dialogColorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
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
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await taskProvider.deleteTask(task.id);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
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
  }
}
