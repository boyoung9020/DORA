import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../models/comment.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';

/// 타임라인 아이템 타입
enum TimelineItemType {
  history,
  comment,
  detail,
}

/// 타임라인 아이템 데이터 클래스
class TimelineItem {
  final TimelineItemType type;
  final DateTime date;
  final dynamic data; // HistoryEvent 또는 Comment

  TimelineItem({
    required this.type,
    required this.date,
    required this.data,
  });
}

/// 히스토리 이벤트 데이터 클래스
class HistoryEvent {
  final String username;
  final String action;
  final Widget? target;
  final IconData icon;

  HistoryEvent({
    required this.username,
    required this.action,
    this.target,
    required this.icon,
  });
}

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
  late TextEditingController _commentController;
  late TaskStatus _selectedStatus;
  late TaskPriority _selectedPriority;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isEditing = false;
  final CommentService _commentService = CommentService();
  List<Comment> _comments = [];
  bool _isLoadingComments = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _detailController = TextEditingController(text: widget.task.detail);
    _commentController = TextEditingController();
    _selectedStatus = widget.task.status;
    _selectedPriority = widget.task.priority;
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;
    _loadComments();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _detailController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// 댓글 로드
  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
    });
    try {
      final comments = await _commentService.getCommentsByTaskId(widget.task.id);
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  /// 댓글 추가
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    final user = authProvider.currentUser!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    try {
      final comment = await _commentService.createComment(
        taskId: widget.task.id,
        userId: user.id,
        username: user.username,
        content: _commentController.text.trim(),
      );

      // Task에 댓글 ID 추가
      final currentTask = taskProvider.tasks.firstWhere(
        (t) => t.id == widget.task.id,
        orElse: () => widget.task,
      );
      
      // commentIds가 null이거나 잘못된 타입인 경우를 대비
      List<String> updatedCommentIds;
      try {
        updatedCommentIds = List<String>.from(currentTask.commentIds);
      } catch (e) {
        // commentIds가 null이거나 잘못된 타입인 경우 빈 리스트로 시작
        updatedCommentIds = [];
      }
      
      updatedCommentIds.add(comment.id);
      await taskProvider.updateTask(
        currentTask.copyWith(
          commentIds: updatedCommentIds,
          updatedAt: DateTime.now(),
        ),
      );

      _commentController.clear();
      await _loadComments();
      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 추가 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('댓글 추가 오류: $e');
      print('스택 트레이스: $stackTrace');
    }
  }

  /// 댓글 삭제
  Future<void> _deleteComment(String commentId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    final comment = _comments.firstWhere((c) => c.id == commentId);
    
    // 본인 댓글만 삭제 가능
    if (comment.userId != authProvider.currentUser!.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('본인의 댓글만 삭제할 수 있습니다'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      await _commentService.deleteComment(commentId);
      
      // Task에서 댓글 ID 제거
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final currentTask = taskProvider.tasks.firstWhere(
        (t) => t.id == widget.task.id,
        orElse: () => widget.task,
      );
      final updatedCommentIds = currentTask.commentIds.where((id) => id != commentId).toList();
      await taskProvider.updateTask(
        currentTask.copyWith(
          commentIds: updatedCommentIds,
          updatedAt: DateTime.now(),
        ),
      );

      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 삭제 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
                  // 중요도 배지
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    borderRadius: 20.0,
                    blur: 20.0,
                    gradientColors: [
                      currentTask.priority.color.withOpacity(0.3),
                      currentTask.priority.color.withOpacity(0.2),
                    ],
                    borderColor: currentTask.priority.color.withOpacity(0.5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: currentTask.priority.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          currentTask.priority.displayName,
                          style: TextStyle(
                            color: currentTask.priority.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      // 왼쪽: 타임라인
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상세 내용 (항상 맨 위)
                            _buildDetailTimelineItem(
                              context,
                              currentTask,
                              _isEditing,
                              () {
                                          if (_isEditing) {
                                            _saveTask(context, taskProvider);
                                          } else {
                                            setState(() {
                                              _isEditing = true;
                                            });
                                          }
                                        },
                              colorScheme,
                            ),
                            const SizedBox(height: 16),
                            // 타임라인 아이템들 (시간순 정렬)
                            if (_isLoadingComments)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else
                              FutureBuilder<List<TimelineItem>>(
                                future: _buildTimelineItems(currentTask),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  final timelineItems = snapshot.data!;
                                  
                                  return Column(
                                    children: timelineItems.map((item) {
                                      if (item.type == TimelineItemType.history) {
                                        final event = item.data as HistoryEvent;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: _buildHistoryItem(
                                            context,
                                            item.date,
                                            event.username,
                                            event.action,
                                            event.target,
                                            event.icon,
                                            colorScheme,
                                          ),
                                        );
                                      } else if (item.type == TimelineItemType.comment) {
                                        final comment = item.data as Comment;
                                        return _buildCommentTimelineItem(
                                          context,
                                          comment,
                                          colorScheme,
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    }).toList(),
                                  );
                                },
                              ),
                            // 댓글 입력
                            const SizedBox(height: 16),
                            _buildCommentInput(context, colorScheme),
                          ],
                        ),
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
                                        // 상태 변경 후 타임라인 업데이트를 위해 setState 호출
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 중요도
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
                                        '중요도',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.priority_high, size: 16, color: colorScheme.onSurface.withOpacity(0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButton<TaskPriority>(
                                    value: _selectedPriority,
                                    isExpanded: true,
                                    items: TaskPriority.values.map((priority) {
                                      return DropdownMenuItem(
                                        value: priority,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: priority.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${priority.displayName} - ${priority.description}',
                                              style: TextStyle(
                                                color: priority.color,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedPriority = value;
                                        });
                                        taskProvider.updateTask(
                                          currentTask.copyWith(
                                            priority: value,
                                            updatedAt: DateTime.now(),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 기간 (시작일 ~ 종료일)
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
                                        '기간',
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
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // 시작일
                                      Expanded(
                                        child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                              lastDate: _endDate ?? DateTime(2030),
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
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: colorScheme.surface.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: colorScheme.onSurface.withOpacity(0.1),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '시작일',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                      _startDate != null
                                          ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                                          : '날짜 선택',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _startDate != null
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withOpacity(0.5),
                                                    fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 12),
                                      // 종료일
                                      Expanded(
                                        child: InkWell(
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
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: colorScheme.surface.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: colorScheme.onSurface.withOpacity(0.1),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '종료일',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                      _endDate != null
                                          ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                          : '날짜 선택',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _endDate != null
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withOpacity(0.5),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                      ),
                                    ),
                                      ),
                                    ],
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
                                                    backgroundColor: AvatarColor.getColorForUser(member.id),
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
                              backgroundColor: AvatarColor.getColorForUser(user.id),
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

  /// 생성자 이름 가져오기
  String _getCreatorUsername(Task task) {
    // 실제로는 태스크에 creatorId가 있어야 하지만, 현재는 없으므로 기본값 반환
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.currentUser?.username ?? 'Unknown';
  }

  /// 타임라인 아이템들 빌드 (시간순 정렬)
  Future<List<TimelineItem>> _buildTimelineItems(Task task) async {
    final List<TimelineItem> items = [];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    // 이슈 생성 기록
    items.add(TimelineItem(
      type: TimelineItemType.history,
      date: task.createdAt,
      data: HistoryEvent(
        username: _getCreatorUsername(task),
        action: 'opened this',
        icon: Icons.circle_outlined,
      ),
    ));

    // 할당 히스토리 (할당된 멤버가 있고, 할당 시간이 생성 시간 이후인 경우만)
    if (task.assignedMemberIds.isNotEmpty) {
      final members = await _loadAssignedMembers(task.assignedMemberIds);
      for (final member in members) {
        // 할당은 updatedAt을 사용하되, 코멘트와 비교해서 정확한 순서를 맞춤
        final assignmentDate = task.updatedAt.isAfter(task.createdAt) 
            ? task.updatedAt 
            : task.createdAt.add(const Duration(seconds: 1));
        
        items.add(TimelineItem(
          type: TimelineItemType.history,
          date: assignmentDate,
          data: HistoryEvent(
            username: currentUser?.username ?? 'Unknown',
            action: 'assigned',
            target: Text(
              member.username,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            icon: Icons.person_outline,
          ),
        ));
      }
    }

    // 코멘트 추가
    for (final comment in _comments) {
      items.add(TimelineItem(
        type: TimelineItemType.comment,
        date: comment.createdAt,
        data: comment,
      ));
    }

    // 상태 변경 히스토리 (상태가 backlog가 아니고, updatedAt이 생성 시간 이후인 경우)
    // 상태 변경은 코멘트와 비교해서 정확한 순서를 맞춤
    if (task.status != TaskStatus.backlog && task.updatedAt.isAfter(task.createdAt)) {
      // 코멘트가 있으면 가장 최근 코멘트 이후에 상태 변경이 일어났다고 가정
      // 코멘트가 없으면 updatedAt 사용
      DateTime statusChangeDate = task.updatedAt;
      if (_comments.isNotEmpty) {
        final latestComment = _comments.reduce((a, b) => 
          a.createdAt.isAfter(b.createdAt) ? a : b);
        // 상태 변경이 코멘트 이후에 일어났다면 코멘트 시간보다 조금 늦게
        if (task.updatedAt.isAfter(latestComment.createdAt)) {
          statusChangeDate = task.updatedAt;
        } else {
          // 상태 변경이 코멘트 이전에 일어났다면 코멘트 시간보다 조금 이전
          statusChangeDate = latestComment.createdAt.subtract(const Duration(seconds: 1));
        }
      }
      
      items.add(TimelineItem(
        type: TimelineItemType.history,
        date: statusChangeDate,
        data: HistoryEvent(
          username: _getCreatorUsername(task),
          action: 'moved this to',
          target: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: task.status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                task.status.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: task.status.color,
                ),
              ),
            ],
          ),
          icon: Icons.view_kanban_outlined,
        ),
      ));
    }

    // 시간순으로 정렬 (오래된 것부터)
    items.sort((a, b) => a.date.compareTo(b.date));

    return items;
  }

  /// 히스토리 아이템 빌드 (GitHub 스타일 - 작은 아이콘과 텍스트)
  Widget _buildHistoryItem(
    BuildContext context,
    DateTime date,
    String username,
    String action,
    Widget? target,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작은 아이콘 (아바타 대신)
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 16,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 8),
          // 내용
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  ' $action ',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                if (target != null) target,
                Text(
                  ' ${_formatRelativeDate(date)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 타임라인 아이템 빌드 (코멘트용 - 아바타 포함)
  Widget _buildTimelineItem(
    BuildContext context,
    DateTime date,
    String username,
    String action,
    Widget? content,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 아바타
        CircleAvatar(
          radius: 16,
          backgroundColor: AvatarColor.getColorForUser(username),
          child: Text(
            username[0].toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 내용
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatRelativeDate(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              if (content != null) ...[
                const SizedBox(height: 8),
                content,
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 상대적 날짜 포맷팅 (예: "5 days ago", "yesterday")
  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        }
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 14) {
      return 'last week';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// 설명 타임라인 아이템
  Widget _buildDescriptionTimelineItem(
    BuildContext context,
    String description,
    DateTime date,
    String username,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 44), // 아바타 너비 + 간격
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 12.0,
            blur: 20.0,
            gradientColors: [
              colorScheme.surface.withOpacity(0.4),
              colorScheme.surface.withOpacity(0.3),
            ],
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 상세 내용 타임라인 아이템
  Widget _buildDetailTimelineItem(
    BuildContext context,
    Task task,
    bool isEditing,
    VoidCallback onEditToggle,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 44), // 아바타 너비 + 간격
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 12.0,
            blur: 20.0,
            gradientColors: [
              colorScheme.surface.withOpacity(0.4),
              colorScheme.surface.withOpacity(0.3),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        isEditing ? Icons.check : Icons.edit,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      onPressed: onEditToggle,
                      tooltip: isEditing ? '저장' : '편집',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isEditing)
                  TextField(
                    controller: _detailController,
                    maxLines: null,
                    minLines: 8,
                    decoration: InputDecoration(
                      hintText: '상세 내용을 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  )
                else
                  Text(
                    task.detail.isEmpty
                        ? '상세 내용이 없습니다. 편집 버튼을 눌러 추가하세요.'
                        : task.detail,
                    style: TextStyle(
                      fontSize: 14,
                      color: task.detail.isEmpty
                          ? colorScheme.onSurface.withOpacity(0.5)
                          : colorScheme.onSurface.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 댓글 타임라인 아이템 (코멘트 스타일 - 아바타와 박스)
  Widget _buildCommentTimelineItem(
    BuildContext context,
    Comment comment,
    ColorScheme colorScheme,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isMyComment = comment.userId == (authProvider.currentUser?.id ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AvatarColor.getColorForUser(comment.userId),
            child: Text(
              comment.username[0].toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatRelativeDate(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    if (isMyComment) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Author',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isMyComment)
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        onPressed: () => _deleteComment(comment.id),
                        tooltip: '삭제',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 8.0,
                  blur: 15.0,
                  gradientColors: [
                    colorScheme.surface.withOpacity(0.3),
                    colorScheme.surface.withOpacity(0.2),
                  ],
                  child: Text(
                    comment.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 댓글 입력 위젯
  Widget _buildCommentInput(BuildContext context, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AvatarColor.getColorForUser(
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? 
            Provider.of<AuthProvider>(context, listen: false).currentUser?.username ?? 'U'
          ),
          child: Text(
            (Provider.of<AuthProvider>(context, listen: false).currentUser?.username ?? 'U')[0].toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassContainer(
                padding: const EdgeInsets.all(12),
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.surface.withOpacity(0.4),
                  colorScheme.surface.withOpacity(0.3),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _commentController,
                      maxLines: null,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _addComment,
                          child: Text(
                            'Comment',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    }
  }
}

