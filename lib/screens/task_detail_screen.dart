import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';

/// 태스크 상세 화면 - GitHub 이슈 스타일
class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _detailController;
  late TaskStatus _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _detailController = TextEditingController(text: widget.task.detail);
    _selectedStatus = widget.task.status;
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskProvider = context.watch<TaskProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final currentProject = projectProvider.currentProject;
    
    // 최신 태스크 정보 가져오기
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1000,
          maxHeight: 800,
        ),
        child: GlassContainer(
          padding: const EdgeInsets.all(24.0),
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
              // 헤더
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currentTask.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // 상태 배지
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    borderRadius: 20.0,
                    blur: 20.0,
                    gradientColors: [
                      currentTask.status.color.withOpacity(0.3),
                      currentTask.status.color.withOpacity(0.2),
                    ],
                    borderColor: currentTask.status.color.withOpacity(0.5),
                    child: Text(
                      currentTask.status.displayName,
                      style: TextStyle(
                        color: currentTask.status.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 닫기 버튼
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 메인 컨텐츠
              Flexible(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 왼쪽: 상세 내용
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 설명
                            if (currentTask.description.isNotEmpty) ...[
                              GlassContainer(
                                padding: const EdgeInsets.all(20),
                                borderRadius: 15.0,
                                blur: 20.0,
                                gradientColors: [
                                  colorScheme.surface.withOpacity(0.4),
                                  colorScheme.surface.withOpacity(0.3),
                                ],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '설명',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      currentTask.description,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colorScheme.onSurface.withOpacity(0.8),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // 상세 내용
                            GlassContainer(
                              padding: const EdgeInsets.all(20),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                colorScheme.surface.withOpacity(0.4),
                                colorScheme.surface.withOpacity(0.3),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '상세 내용',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: Icon(
                                          _isEditing ? Icons.check : Icons.edit,
                                          size: 20,
                                          color: colorScheme.primary,
                                        ),
                                        onPressed: () {
                                          if (_isEditing) {
                                            _saveTask(context, taskProvider);
                                          } else {
                                            setState(() {
                                              _isEditing = true;
                                            });
                                          }
                                        },
                                        tooltip: _isEditing ? '저장' : '편집',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (_isEditing)
                                    TextField(
                                      controller: _detailController,
                                      maxLines: null,
                                      minLines: 10,
                                      decoration: InputDecoration(
                                        hintText: '상세 내용을 입력하세요...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.5),
                                      ),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colorScheme.onSurface,
                                        height: 1.5,
                                      ),
                                    )
                                  else
                                    Text(
                                      currentTask.detail.isEmpty
                                          ? '상세 내용이 없습니다. 편집 버튼을 눌러 추가하세요.'
                                          : currentTask.detail,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: currentTask.detail.isEmpty
                                            ? colorScheme.onSurface.withOpacity(0.5)
                                            : colorScheme.onSurface.withOpacity(0.8),
                                        height: 1.5,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // 오른쪽: 사이드바
                      SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 프로젝트
                            if (currentProject != null)
                              GlassContainer(
                                padding: const EdgeInsets.all(16),
                                borderRadius: 15.0,
                                blur: 20.0,
                                gradientColors: [
                                  colorScheme.surface.withOpacity(0.4),
                                  colorScheme.surface.withOpacity(0.3),
                                ],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '프로젝트',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.settings, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: currentProject.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            currentProject.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colorScheme.onSurface.withOpacity(0.8),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            // 상태
                            GlassContainer(
                              padding: const EdgeInsets.all(16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                colorScheme.surface.withOpacity(0.4),
                                colorScheme.surface.withOpacity(0.3),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '상태',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.settings, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButton<TaskStatus>(
                                    value: _selectedStatus,
                                    isExpanded: true,
                                    items: TaskStatus.values.map((status) {
                                      return DropdownMenuItem(
                                        value: status,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: status.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(status.displayName),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedStatus = value;
                                        });
                                        taskProvider.changeTaskStatus(currentTask.id, value);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 시작일
                            GlassContainer(
                              padding: const EdgeInsets.all(16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                colorScheme.surface.withOpacity(0.4),
                                colorScheme.surface.withOpacity(0.3),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '시작일',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.settings, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          _startDate = date;
                                        });
                                        await taskProvider.updateTask(
                                          currentTask.copyWith(
                                            startDate: date,
                                            updatedAt: DateTime.now(),
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      _startDate != null
                                          ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                                          : '날짜 선택',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _startDate != null
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 종료일
                            GlassContainer(
                              padding: const EdgeInsets.all(16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                colorScheme.surface.withOpacity(0.4),
                                colorScheme.surface.withOpacity(0.3),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '종료일',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.settings, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                                        firstDate: _startDate ?? DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          _endDate = date;
                                        });
                                        await taskProvider.updateTask(
                                          currentTask.copyWith(
                                            endDate: date,
                                            updatedAt: DateTime.now(),
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      _endDate != null
                                          ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                          : '날짜 선택',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _endDate != null
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 할당된 팀원
                            GlassContainer(
                              padding: const EdgeInsets.all(16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                colorScheme.surface.withOpacity(0.4),
                                colorScheme.surface.withOpacity(0.3),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '할당된 팀원',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: Icon(
                                          Icons.person_add,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                        onPressed: () => _showAssignMemberDialog(context, currentTask, taskProvider, currentProject),
                                        tooltip: '팀원 할당',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (currentTask.assignedMemberIds.isEmpty)
                                    Text(
                                      '할당된 팀원이 없습니다',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    )
                                  else
                                    FutureBuilder<List<User>>(
                                      future: _loadAssignedMembers(currentTask.assignedMemberIds),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const SizedBox.shrink();
                                        }
                                        final members = snapshot.data!;
                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: members.map((member) {
                                            return GlassContainer(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              borderRadius: 8.0,
                                              blur: 15.0,
                                              gradientColors: [
                                                colorScheme.primary.withOpacity(0.2),
                                                colorScheme.primary.withOpacity(0.1),
                                              ],
                                              borderColor: colorScheme.primary.withOpacity(0.3),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 8,
                                                    backgroundColor: colorScheme.primary,
                                                    child: Text(
                                                      member.username[0].toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    member.username,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: colorScheme.onSurface,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  GestureDetector(
                                                    onTap: () => _removeAssignedMember(context, currentTask, member.id, taskProvider),
                                                    child: Icon(
                                                      Icons.close,
                                                      size: 14,
                                                      color: colorScheme.onSurface.withOpacity(0.5),
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
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 생성일
                            GlassContainer(
                              padding: const EdgeInsets.all(16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                colorScheme.surface.withOpacity(0.4),
                                colorScheme.surface.withOpacity(0.3),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '생성일',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${currentTask.createdAt.year}-${currentTask.createdAt.month.toString().padLeft(2, '0')}-${currentTask.createdAt.day.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveTask(BuildContext context, TaskProvider taskProvider) async {
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );

    await taskProvider.updateTask(
      currentTask.copyWith(
        detail: _detailController.text,
        updatedAt: DateTime.now(),
      ),
    );

    setState(() {
      _isEditing = false;
    });
  }

  /// 할당된 팀원 목록 로드
  Future<List<User>> _loadAssignedMembers(List<String> memberIds) async {
    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      return allUsers.where((user) => memberIds.contains(user.id)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 팀원 할당 다이얼로그
  Future<void> _showAssignMemberDialog(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
    currentProject,
  ) async {
    if (currentProject == null) return;
    
    final colorScheme = Theme.of(context).colorScheme;
    final authService = AuthService();
    
    try {
      final allUsers = await authService.getAllUsers();
      final projectMembers = allUsers.where((user) {
        return currentProject.teamMemberIds.contains(user.id);
      }).toList();
      
      final availableMembers = projectMembers.where((user) {
        return !task.assignedMemberIds.contains(user.id);
      }).toList();
      
      if (availableMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('할당할 수 있는 팀원이 없습니다'),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }
      
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 20.0,
              blur: 25.0,
              gradientColors: [
                colorScheme.surface.withOpacity(0.6),
                colorScheme.surface.withOpacity(0.5),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '팀원 할당',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableMembers.length,
                        itemBuilder: (context, index) {
                          final user = availableMembers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primary,
                              child: Text(
                                user.username[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              user.username,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              user.email,
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                color: colorScheme.primary,
                              ),
                              onPressed: () async {
                                final updatedMemberIds = List<String>.from(task.assignedMemberIds);
                                updatedMemberIds.add(user.id);
                                await taskProvider.updateTask(
                                  task.copyWith(
                                    assignedMemberIds: updatedMemberIds,
                                    updatedAt: DateTime.now(),
                                  ),
                                );
                                Navigator.of(context).pop();
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            '닫기',
                            style: TextStyle(color: colorScheme.onSurface),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류 발생: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  /// 할당된 팀원 제거
  Future<void> _removeAssignedMember(
    BuildContext context,
    Task task,
    String userId,
    TaskProvider taskProvider,
  ) async {
    final updatedMemberIds = task.assignedMemberIds.where((id) => id != userId).toList();
    await taskProvider.updateTask(
      task.copyWith(
        assignedMemberIds: updatedMemberIds,
        updatedAt: DateTime.now(),
      ),
    );
    setState(() {});
  }
}

