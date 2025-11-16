import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../widgets/glass_container.dart';
import 'task_detail_screen.dart';

/// 칸반 보드 화면
class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 로드 시 태스크 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskProvider = context.watch<TaskProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final currentProjectId = projectProvider.currentProject?.id;

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 헤더
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    '칸반 보드',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.primary.withOpacity(0.3),
                  colorScheme.primary.withOpacity(0.2),
                ],
                child: IconButton(
                  icon: Icon(Icons.add, color: colorScheme.primary),
                  onPressed: () => _showAddTaskDialog(context),
                  tooltip: '새 태스크 추가',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 칸반 보드
          Expanded(
            child: taskProvider.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  )
                : _buildKanbanBoard(context, taskProvider, currentProjectId),
          ),
        ],
      ),
    );
  }

  /// 칸반 보드 UI 구성
  Widget _buildKanbanBoard(BuildContext context, TaskProvider taskProvider, String? currentProjectId) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 너비에 따라 컬럼 너비 계산
        // 최소 250px, 최대 300px, 화면이 작으면 더 작게 조정
        final screenWidth = constraints.maxWidth;
        final columnCount = 5; // 컬럼 개수
        final spacing = 16.0; // 컬럼 간 간격
        final padding = 32.0; // 양쪽 패딩
        
        // 사용 가능한 너비 계산
        final availableWidth = screenWidth - padding - (spacing * (columnCount - 1));
        // 컬럼 너비 계산 (최소 250px, 최대 300px)
        final columnWidth = (availableWidth / columnCount).clamp(250.0, 300.0);
        
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildColumn(
                context,
                TaskStatus.backlog,
                taskProvider.getTasksByStatus(TaskStatus.backlog, projectId: currentProjectId),
                taskProvider,
                columnWidth: columnWidth,
              ),
              SizedBox(width: spacing),
              _buildColumn(
                context,
                TaskStatus.ready,
                taskProvider.getTasksByStatus(TaskStatus.ready, projectId: currentProjectId),
                taskProvider,
                columnWidth: columnWidth,
              ),
              SizedBox(width: spacing),
              _buildColumn(
                context,
                TaskStatus.inProgress,
                taskProvider.getTasksByStatus(TaskStatus.inProgress, projectId: currentProjectId),
                taskProvider,
                columnWidth: columnWidth,
              ),
              SizedBox(width: spacing),
              _buildColumn(
                context,
                TaskStatus.inReview,
                taskProvider.getTasksByStatus(TaskStatus.inReview, projectId: currentProjectId),
                taskProvider,
                columnWidth: columnWidth,
              ),
              SizedBox(width: spacing),
              _buildColumn(
                context,
                TaskStatus.done,
                taskProvider.getTasksByStatus(TaskStatus.done, projectId: currentProjectId),
                taskProvider,
                columnWidth: columnWidth,
              ),
            ],
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
    double columnWidth = 300,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = status.color;

    return SizedBox(
      width: columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 컬럼 헤더
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 15.0,
            blur: 20.0,
            gradientColors: [
              statusColor.withOpacity(0.4),
              statusColor.withOpacity(0.3),
            ],
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
                const SizedBox(width: 8),
                Text(
                  status.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tasks.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 태스크 카드들 - 고정 높이로 하단까지 드래그 가능
          Expanded(
            child: DragTarget<Task>(
              onWillAccept: (data) {
                // 같은 상태로는 이동 불가
                return data != null && data.status != status;
              },
              onAccept: (task) {
                if (task.status != status) {
                  // 상태 변경
                  taskProvider.changeTaskStatus(task.id, status);
                }
              },
              onLeave: (data) {
                // 드래그가 떠날 때 아무것도 하지 않음
              },
              builder: (context, candidateData, rejectedData) {
                // candidateData를 사용하여 드래그 오버 상태 확인
                final isDraggingOver = candidateData.isNotEmpty;
                final colorScheme = Theme.of(context).colorScheme;
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isDraggingOver
                          ? statusColor
                          : colorScheme.onSurface.withOpacity(0.1),
                      width: isDraggingOver ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      tasks.isEmpty
                          ? _buildEmptyColumn(context, status)
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...tasks.map((task) {
                                      return Padding(
                                        key: ValueKey(task.id),
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _buildTaskCard(
                                          context,
                                          task,
                                          taskProvider,
                                        ),
                                      );
                                    }).toList(),
                                    // 태스크 하단에 항상 드래그 가능한 영역 추가
                                    Container(
                                      height: 100,
                                      margin: const EdgeInsets.only(top: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      // 하단 오른쪽 구석에 + 버튼
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showAddTaskDialogForStatus(context, status),
                            borderRadius: BorderRadius.circular(20.0),
                            child: GlassContainer(
                              padding: EdgeInsets.zero,
                              borderRadius: 20.0,
                              blur: 20.0,
                              gradientColors: [
                                statusColor.withOpacity(0.4),
                                statusColor.withOpacity(0.3),
                              ],
                              borderColor: statusColor.withOpacity(0.6),
                              borderWidth: 1.0,
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.add,
                                  color: statusColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 컬럼 표시
  Widget _buildEmptyColumn(BuildContext context, TaskStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.1),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Text(
          '태스크를 여기로 드래그하세요',
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// 태스크 카드 위젯 생성
  Widget _buildTaskCard(
    BuildContext context,
    Task task,
    TaskProvider taskProvider, {
    Key? key,
  }) {
    final statusColor = task.status.color;

    return Draggable<Task>(
      key: key ?? ValueKey(task.id),
      data: task,
      feedback: Material(
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
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: _buildTaskCardContent(context, task, statusColor),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskCardContainer(context, task, statusColor, taskProvider),
      ),
      onDragStarted: () {
        // 드래그 시작
      },
      onDragEnd: (details) {
        // 드래그 종료
      },
      child: _buildTaskCardContainer(context, task, statusColor, taskProvider),
    );
  }

  /// 태스크 카드 컨테이너
  Widget _buildTaskCardContainer(
    BuildContext context,
    Task task,
    Color statusColor,
    TaskProvider taskProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _showTaskDetailScreen(context, task, taskProvider),
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
        child: Stack(
          clipBehavior: Clip.none, // 경계 밖으로 나가는 것을 허용
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTaskCardContent(context, task, statusColor),
              ],
            ),
            // 오른쪽 상단 X 버튼 (삭제)
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showDeleteConfirmDialog(context, task, taskProvider),
                  borderRadius: BorderRadius.circular(9),
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 태스크 카드 내용
  Widget _buildTaskCardContent(BuildContext context, Task task, Color statusColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// 새 태스크 추가 다이얼로그
  void _showAddTaskDialog(BuildContext context) {
    _showAddTaskDialogForStatus(context, TaskStatus.backlog);
  }

  /// 특정 상태로 태스크 추가 다이얼로그
  void _showAddTaskDialogForStatus(BuildContext context, TaskStatus initialStatus) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    TaskStatus selectedStatus = initialStatus;
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                    colorScheme.surface.withOpacity(0.6),
                    colorScheme.surface.withOpacity(0.5),
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
                            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                              selectedColor: status.color.withOpacity(0.3),
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
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() {
                            startDate = date;
                          });
                        }
                      },
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        borderRadius: 12.0,
                        blur: 20.0,
                        gradientColors: [
                          colorScheme.surface.withOpacity(0.3),
                          colorScheme.surface.withOpacity(0.2),
                        ],
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: colorScheme.onSurface.withOpacity(0.7)),
                            const SizedBox(width: 12),
                            Text(
                              startDate != null
                                  ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                                  : '날짜 선택',
                              style: TextStyle(
                                fontSize: 16,
                                color: startDate != null
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withOpacity(0.5),
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
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? startDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() {
                            endDate = date;
                          });
                        }
                      },
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        borderRadius: 12.0,
                        blur: 20.0,
                        gradientColors: [
                          colorScheme.surface.withOpacity(0.3),
                          colorScheme.surface.withOpacity(0.2),
                        ],
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: colorScheme.onSurface.withOpacity(0.7)),
                            const SizedBox(width: 12),
                            Text(
                              endDate != null
                                  ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                                  : '날짜 선택',
                              style: TextStyle(
                                fontSize: 16,
                                color: endDate != null
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                            onPressed: () {
                              if (titleController.text.trim().isNotEmpty) {
                                final projectProvider = context.read<ProjectProvider>();
                                final currentProjectId = projectProvider.currentProject?.id;
                                if (currentProjectId != null) {
                                  context.read<TaskProvider>().createTask(
                                        title: titleController.text.trim(),
                                        description: descriptionController.text.trim(),
                                        status: selectedStatus,
                                        projectId: currentProjectId,
                                        startDate: startDate,
                                        endDate: endDate,
                                      );
                                }
                                Navigator.of(context).pop();
                              }
                            },
                            gradientColors: [
                              colorScheme.primary.withOpacity(0.5),
                              colorScheme.primary.withOpacity(0.4),
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

  /// 태스크 상세 화면 표시
  void _showTaskDetailScreen(BuildContext context, Task task, TaskProvider taskProvider) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                    colorScheme.surface.withOpacity(0.6),
                    colorScheme.surface.withOpacity(0.5),
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
                            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                              selectedColor: status.color.withOpacity(0.3),
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
                                        description: descriptionController.text.trim(),
                                        status: selectedStatus,
                                      ),
                                    );
                                Navigator.of(context).pop();
                              }
                            },
                            gradientColors: [
                              colorScheme.primary.withOpacity(0.5),
                              colorScheme.primary.withOpacity(0.4),
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

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final dialogColorScheme = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: dialogColorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${task.title}을(를) 삭제하시겠습니까?',
                  style: TextStyle(
                    fontSize: 16,
                    color: dialogColorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '취소',
                        style: TextStyle(color: dialogColorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        taskProvider.deleteTask(task.id);
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.2),
                      ),
                      child: Text(
                        '삭제',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

