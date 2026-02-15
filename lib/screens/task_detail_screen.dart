import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/task.dart';
import '../models/user.dart';
import '../models/comment.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import '../services/upload_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../utils/avatar_color.dart';

/// 붙여넣기 Intent
class _PasteIntent extends Intent {
  const _PasteIntent();
}

/// 코멘트 전송 Intent (Ctrl+Enter)
class _SubmitCommentIntent extends Intent {
  const _SubmitCommentIntent();
}

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
  final UploadService _uploadService = UploadService();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _timelineScrollController = ScrollController();
  bool _isCommentDropHover = false;
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  List<TimelineItem>? _timelineItems;  // 타임라인 아이템 캐시
  String? _editingCommentId;  // 편집 중인 코멘트 ID
  late TextEditingController _editCommentController;  // 편집용 컨트롤러
  List<XFile> _selectedCommentImages = [];  // 댓글용 선택된 이미지 (웹/데스크톱 공통)
  List<XFile> _selectedDetailImages = [];    // 상세 내용용 선택된 이미지
  List<String> _uploadedCommentImageUrls = [];  // 업로드된 댓글 이미지 URL
  List<String> _uploadedDetailImageUrls = [];   // 업로드된 상세 내용 이미지 URL
  List<User>? _assignedMembers;  // 할당된 팀원 캐시
  bool _isInitialLoad = true;  // 초기 로드 여부
  List<String>? _lastAssignedMemberIds;  // 이전 할당된 팀원 ID (동기화 확인용)

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _detailController = TextEditingController(text: widget.task.detail);
    _commentController = TextEditingController();
    _editCommentController = TextEditingController();
    _selectedStatus = widget.task.status;
    _selectedPriority = widget.task.priority;
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;

    // 초기 로드 시 스크롤이 맨 아래로 가지 않도록 리스너 추가
    _timelineScrollController.addListener(() {
      if (_isInitialLoad && _timelineScrollController.hasClients) {
        // 초기 로드 중에 스크롤이 맨 아래로 가려고 하면 맨 위로 되돌림
        if (_timelineScrollController.offset > 10) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isInitialLoad && _timelineScrollController.hasClients) {
              _timelineScrollController.jumpTo(0.0);
            }
          });
        }
      }
    });

    // 실시간 댓글 갱신 리스너 등록
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskProvider = context.read<TaskProvider>();
      taskProvider.addCommentListener(widget.task.id, _onCommentCreated);
    });

    // 초기 데이터 로드 (한 번에 처리하여 setState 최소화)
    _loadInitialData();
  }

  /// WebSocket으로 댓글 생성 이벤트 수신 시 호출
  void _onCommentCreated() {
    if (mounted) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    // 실시간 댓글 갱신 리스너 해제
    final taskProvider = context.read<TaskProvider>();
    taskProvider.removeCommentListener(widget.task.id, _onCommentCreated);

    _titleController.dispose();
    _descriptionController.dispose();
    _detailController.dispose();
    _commentController.dispose();
    _editCommentController.dispose();
    _commentFocusNode.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  /// 초기 데이터 로드 (성능 최적화: 한 번에 처리)
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingComments = true;
    });
    
    try {
      // 댓글과 할당된 팀원을 동시에 로드
      final results = await Future.wait([
        _commentService.getCommentsByTaskId(widget.task.id),
        _loadAssignedMembersData(),
      ]);
      
      final comments = results[0] as List<Comment>;
      final members = results[1] as List<User>?;
      
      // 한 번만 setState 호출
      setState(() {
        _comments = comments;
        _assignedMembers = members;
        _isLoadingComments = false;
      });
      
      // 타임라인 아이템 업데이트 (setState는 _loadTimelineItems 내부에서 호출)
      await _loadTimelineItems();
      
      // 할당된 팀원 목록이 비어있지만 태스크에 할당된 팀원이 있다면 다시 로드
      if ((members == null || members.isEmpty) && widget.task.assignedMemberIds.isNotEmpty) {
        await _loadAssignedMembers();
      }
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  /// 댓글 로드
  Future<void> _loadComments({bool updateTimeline = true}) async {
    setState(() {
      _isLoadingComments = true;
    });
    try {
      final comments = await _commentService.getCommentsByTaskId(widget.task.id);
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
      // 코멘트 로드 후 타임라인 아이템 업데이트 (옵션)
      if (updateTimeline) {
        await _loadTimelineItems();
      }
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }
  
  /// 할당된 팀원 데이터 로드 (반환값 있음)
  Future<List<User>?> _loadAssignedMembersData() async {
    final taskProvider = context.read<TaskProvider>();
    // 최신 태스크 정보 가져오기 (taskProvider에서 먼저 찾고, 없으면 widget.task 사용)
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    
    // 할당된 팀원이 없으면 빈 리스트 반환
    if (currentTask.assignedMemberIds.isEmpty) {
      return [];
    }
    
    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      final members = allUsers.where((user) => currentTask.assignedMemberIds.contains(user.id)).toList();
      
      // 할당된 팀원 ID가 있지만 사용자를 찾지 못한 경우도 빈 리스트 반환하지 않고 로그 출력
      if (members.isEmpty && currentTask.assignedMemberIds.isNotEmpty) {
        print('[TaskDetailScreen] 할당된 팀원 ID: ${currentTask.assignedMemberIds}, 찾은 사용자: ${members.length}명');
      }
      
      return members;
    } catch (e) {
      print('[TaskDetailScreen] 할당된 팀원 로드 실패: $e');
      return [];
    }
  }

  /// 타임라인 아이템 로드 (스크롤 위치 유지)
  Future<void> _loadTimelineItems({bool scrollToBottom = false}) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    
    // 초기 로드 시에는 스크롤을 맨 위로 유지해야 하므로 저장하지 않음
    double? savedScrollPosition;
    final bool hadClients = _timelineScrollController.hasClients;
    if (!scrollToBottom && hadClients && !_isInitialLoad) {
      savedScrollPosition = _timelineScrollController.offset;
    }
    
      final timelineItems = _buildTimelineItems(currentTask);
    
    if (mounted) {
      // setState를 호출하기 전에 스크롤 위치를 미리 저장
      final maxScrollBefore = hadClients 
          ? _timelineScrollController.position.maxScrollExtent 
          : 0.0;
      
      setState(() {
        _timelineItems = timelineItems;
      });
      
      // setState 후 스크롤 위치 복원 또는 맨 아래로 이동
      if (scrollToBottom) {
        // 코멘트 추가 시 맨 아래로 이동 - 여러 번 시도하여 확실하게
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isInitialLoad) {
            _scrollToBottom();
          }
        });
      } else if (savedScrollPosition != null && !_isInitialLoad) {
        // 저장된 위치로 복원 (초기 로드가 아닐 때만)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
          final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
          final scrollDelta = maxScrollAfter - maxScrollBefore;
          final adjustedPosition = savedScrollPosition! + scrollDelta;
          
          _timelineScrollController.jumpTo(
            adjustedPosition.clamp(0.0, maxScrollAfter),
          );
        });
      } else if (_isInitialLoad) {
        // 초기 로드 시 스크롤을 맨 위로 유지 (작업 카드 진입 시)
        // 여러 번 시도하여 확실하게 맨 위로 유지
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_timelineScrollController.hasClients) return;
          // 강제로 맨 위로 이동
          _timelineScrollController.jumpTo(0.0);
        });
        // 추가 시도: 레이아웃 완료 후 다시 확인
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted || !_timelineScrollController.hasClients || !_isInitialLoad) return;
          _timelineScrollController.jumpTo(0.0);
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted || !_timelineScrollController.hasClients || !_isInitialLoad) return;
          if (_timelineScrollController.offset > 0) {
            _timelineScrollController.jumpTo(0.0);
          }
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted || !_timelineScrollController.hasClients || !_isInitialLoad) return;
          if (_timelineScrollController.offset > 0) {
            _timelineScrollController.jumpTo(0.0);
          }
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || !_timelineScrollController.hasClients || !_isInitialLoad) return;
          if (_timelineScrollController.offset > 0) {
            _timelineScrollController.jumpTo(0.0);
          }
          // 초기 로드 완료 표시 (모든 스크롤 시도가 끝난 후)
          _isInitialLoad = false;
        });
      }
      // 초기 로드가 아니고 저장된 위치도 없는 경우 스크롤 위치를 변경하지 않음
    }
  }

  /// 맨 아래로 스크롤 (여러 번 시도하여 확실하게)
  void _scrollToBottom() {
    if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
    
    // 즉시 시도
    final maxScroll = _timelineScrollController.position.maxScrollExtent;
    _timelineScrollController.jumpTo(maxScroll);
    
    // 약간의 지연 후 다시 시도 (레이아웃이 완전히 완료된 후)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
      final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
      _timelineScrollController.animateTo(
        maxScrollAfter,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
    
    // 추가 지연 후 한 번 더 시도 (이미지 로딩 등으로 높이가 변경될 수 있음)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
      final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
      _timelineScrollController.jumpTo(maxScrollAfter);
    });
  }

  /// 부드럽게 맨 아래로 스크롤 (카카오톡 스타일)
  void _scrollToBottomSmooth() {
    if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
    
    // 즉시 시도 (레이아웃이 이미 완료된 경우)
    final maxScroll = _timelineScrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      _timelineScrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    
    // 레이아웃 완료 후 다시 시도
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
      final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
      if (maxScrollAfter > 0) {
        _timelineScrollController.animateTo(
          maxScrollAfter,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
    
    // 이미지 로딩 등으로 높이가 변경될 수 있으므로 한 번 더 시도
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
      final maxScrollFinal = _timelineScrollController.position.maxScrollExtent;
      if (maxScrollFinal > 0) {
        _timelineScrollController.jumpTo(maxScrollFinal);
      }
    });
  }

  /// 이미지 선택 (댓글용)
  Future<void> _pickCommentImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedCommentImages = List<XFile>.from(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 이미지 선택 (상세 내용용)
  Future<void> _pickDetailImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedDetailImages = List<XFile>.from(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 댓글 추가
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty && _selectedCommentImages.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    final user = authProvider.currentUser!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    try {
      // 이미지 업로드
      List<String> imageUrls = [];
      if (_selectedCommentImages.isNotEmpty) {
        imageUrls = await _uploadService.uploadImagesFromXFiles(_selectedCommentImages);
      }
      
      final comment = await _commentService.createComment(
        taskId: widget.task.id,
        userId: user.id,
        username: user.username,
        content: _commentController.text.trim(),
        imageUrls: imageUrls,
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

      // 입력 필드 초기화
      _commentController.clear();
      _selectedCommentImages.clear();
      _uploadedCommentImageUrls.clear();
      
      // 낙관적 업데이트: 즉시 로컬 상태에 댓글 추가 (카카오톡처럼 부드럽게)
      setState(() {
        _comments.add(comment);
      });
      
      // 타임라인에 새 댓글만 부드럽게 추가
      await _addCommentToTimeline(comment);
      
      // 백그라운드에서 서버 동기화 (사용자 경험에 영향 없음)
      _loadComments(updateTimeline: false).catchError((e) {
        // 동기화 실패해도 이미 로컬에 추가되어 있으므로 무시
      });
    } catch (e) {
      if (mounted) {
        print('[ERROR] 댓글 추가 실패: $e');
        print('[ERROR] task_id: ${widget.task.id}');
        print('[ERROR] content: ${_commentController.text}');
        print('[ERROR] imageUrls: ${_selectedCommentImages.length}개');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 추가 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// 댓글 편집 시작
  void _startEditComment(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _editCommentController.text = comment.content;
    });
  }

  /// 댓글 편집 취소
  void _cancelEditComment() {
    setState(() {
      _editingCommentId = null;
      _editCommentController.clear();
    });
  }

  /// 댓글 업데이트
  Future<void> _updateComment(String commentId) async {
    if (_editCommentController.text.trim().isEmpty) {
      _cancelEditComment();
      return;
    }

    try {
      final comment = _comments.firstWhere((c) => c.id == commentId);
      final updatedComment = comment.copyWith(
        content: _editCommentController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await _commentService.updateComment(updatedComment);
      
      // 로컬 코멘트 리스트 업데이트
      final index = _comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        setState(() {
          _comments[index] = updatedComment;
          _editingCommentId = null;
          _editCommentController.clear();
        });
      }

      // 타임라인 업데이트
      await _loadTimelineItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 수정 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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
    // context.read를 사용하여 불필요한 리빌드 방지
    final taskProvider = context.read<TaskProvider>();
    final projectProvider = context.read<ProjectProvider>();
    final currentProject = projectProvider.currentProject;
    
    // 최신 태스크 정보 가져오기
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    
    // 할당된 팀원 ID가 변경되었는지 확인하고 동기화
    final currentAssignedIds = currentTask.assignedMemberIds;
    if (_lastAssignedMemberIds == null || 
        !listEquals(_lastAssignedMemberIds!, currentAssignedIds)) {
      _lastAssignedMemberIds = List.from(currentAssignedIds);
      // 다음 프레임에서 할당된 팀원 목록 다시 로드
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAssignedMembers();
        }
      });
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: GestureDetector(
          onTap: () {}, // 내부 클릭 이벤트를 막아서 바깥 영역 클릭만 감지되도록
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1200,
              maxHeight: 800,
            ),
            child: GlassContainer(
          padding: const EdgeInsets.all(24.0),
          borderRadius: 20.0,
          blur: 25.0,
          gradientColors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.85),
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
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 왼쪽: 타임라인
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        controller: _timelineScrollController,
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
                                  if (_timelineItems == null)
                              const SizedBox.shrink()
                                  else
                              Column(
                                children: _timelineItems!.map((item) {
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
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      builder: (context, opacity, child) {
                                        return Opacity(
                                          opacity: opacity,
                                          child: Transform.translate(
                                            offset: Offset(0, 20 * (1 - opacity)),
                                            child: _buildCommentTimelineItem(
                                              context,
                                              comment,
                                              colorScheme,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }).toList(),
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
                        width: 280,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // 프로젝트
                            if (currentProject != null)
                              GlassContainer(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                                borderRadius: 15.0,
                                blur: 20.0,
                                gradientColors: [
                                  Colors.white.withOpacity(0.8),
                                  Colors.white.withOpacity(0.7),
                                ],
                              shadowBlurRadius: 6,
                              shadowOffset: const Offset(0, 2),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                Colors.white.withOpacity(0.8),
                                Colors.white.withOpacity(0.7),
                              ],
                              shadowBlurRadius: 6,
                              shadowOffset: const Offset(0, 2),
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
                                    onChanged: (value) async {
                                      if (value != null) {
                                        setState(() {
                                          _selectedStatus = value;
                                        });
                                        final authProvider = context.read<AuthProvider>();
                                        final currentUser = authProvider.currentUser;
                                        await taskProvider.changeTaskStatus(
                                          currentTask.id, 
                                          value,
                                          userId: currentUser?.id,
                                          username: currentUser?.username,
                                        );
                                        // 상태 변경 후 타임라인 업데이트
                                        await _loadTimelineItems();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 중요도
                            GlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                Colors.white.withOpacity(0.8),
                                Colors.white.withOpacity(0.7),
                              ],
                              shadowBlurRadius: 6,
                              shadowOffset: const Offset(0, 2),
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
                                    onChanged: (value) async {
                                      if (value != null) {
                                        setState(() {
                                          _selectedPriority = value;
                                        });
                                        final authProvider = context.read<AuthProvider>();
                                        final currentUser = authProvider.currentUser;
                                        await taskProvider.updateTask(
                                          currentTask.copyWith(
                                            priority: value,
                                            updatedAt: DateTime.now(),
                                          ),
                                          userId: currentUser?.id,
                                          username: currentUser?.username,
                                        );
                                        // 중요도 변경 후 타임라인 업데이트
                                        await _loadTimelineItems();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 기간 (시작일 ~ 종료일)
                            GlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                Colors.white.withOpacity(0.8),
                                Colors.white.withOpacity(0.7),
                              ],
                              shadowBlurRadius: 6,
                              shadowOffset: const Offset(0, 2),
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
                                          onTap: () => _openDateRangePicker(
                                            context,
                                            currentTask,
                                            taskProvider,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.7),
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
                                          onTap: () => _openDateRangePicker(
                                            context,
                                            currentTask,
                                            taskProvider,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.7),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                Colors.white.withOpacity(0.8),
                                Colors.white.withOpacity(0.7),
                              ],
                              shadowBlurRadius: 6,
                              shadowOffset: const Offset(0, 2),
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
                                  else if (_assignedMembers == null)
                                    const SizedBox.shrink()
                                  else
                                    Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _assignedMembers!.map((member) {
                                            return RepaintBoundary(
                                              child: GlassContainer(
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
                                                      AvatarColor.getInitial(member.username),
                                                      style: const TextStyle(
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
                                            ),
                                            );
                                          }).toList(),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 생성일
                            GlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                              borderRadius: 15.0,
                              blur: 20.0,
                              gradientColors: [
                                Colors.white.withOpacity(0.8),
                                Colors.white.withOpacity(0.7),
                              ],
                              shadowBlurRadius: 6,
                              shadowOffset: const Offset(0, 2),
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
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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

    try {
      // 이미지 업로드
      List<String> imageUrls = List<String>.from(currentTask.detailImageUrls);
      if (_selectedDetailImages.isNotEmpty) {
        final uploadedUrls = await _uploadService.uploadImagesFromXFiles(_selectedDetailImages);
        imageUrls.addAll(uploadedUrls);
      }

      await taskProvider.updateTask(
        currentTask.copyWith(
          detail: _detailController.text,
          detailImageUrls: imageUrls,
          updatedAt: DateTime.now(),
        ),
      );

      setState(() {
        _isEditing = false;
        _selectedDetailImages.clear();
        _uploadedDetailImageUrls.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('태스크 저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 할당된 팀원 목록 로드
  Future<void> _loadAssignedMembers() async {
    final taskProvider = context.read<TaskProvider>();
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    
    if (currentTask.assignedMemberIds.isEmpty) {
      setState(() {
        _assignedMembers = [];
      });
      return;
    }
    
    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      final members = allUsers.where((user) => currentTask.assignedMemberIds.contains(user.id)).toList();
      if (mounted) {
        setState(() {
          _assignedMembers = members;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _assignedMembers = [];
        });
      }
    }
  }

  /// 팀원 할당 다이얼로그
  Future<void> _openDateRangePicker(
    BuildContext context,
    Task currentTask,
    TaskProvider taskProvider,
  ) async {
    final result = await showTaskDateRangePickerDialog(
      context: context,
      initialStartDate: _startDate,
      initialEndDate: _endDate,
      minDate: DateTime(2020),
      maxDate: DateTime(2030),
    );

    if (result == null) return;

    setState(() {
      _startDate = result['startDate'];
      _endDate = result['endDate'];
    });

    await taskProvider.updateTask(
      currentTask.copyWith(
        startDate: result['startDate'],
        endDate: result['endDate'],
        updatedAt: DateTime.now(),
      ),
    );
  }

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
      
      if (projectMembers.isEmpty) {
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
                        itemCount: projectMembers.length,
                        itemBuilder: (context, index) {
                          final user = projectMembers[index];
                          final isAssigned = task.assignedMemberIds.contains(user.id);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AvatarColor.getColorForUser(user.id),
                              child: Text(
                                AvatarColor.getInitial(user.username),
                                style: const TextStyle(
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
                            trailing: isAssigned
                                ? Icon(
                                    Icons.check_circle,
                                    color: colorScheme.primary,
                                  )
                                : Icon(
                                    Icons.radio_button_unchecked,
                                    color: colorScheme.onSurface.withOpacity(0.3),
                                  ),
                            onTap: () async {
                              // 한 명만 선택 가능하도록 기존 할당을 대체
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              final currentUser = authProvider.currentUser;
                              if (currentUser != null) {
                                await taskProvider.updateTask(
                                  task.copyWith(
                                    assignedMemberIds: [user.id],
                                    updatedAt: DateTime.now(),
                                  ),
                                  userId: currentUser.id,
                                  username: currentUser.username,
                                );
                                // 메인화면 업데이트를 위해 태스크 목록 다시 로드
                                await taskProvider.loadTasks();
                              }
                              Navigator.of(context).pop();
                              // 할당된 팀원 목록 다시 로드
                              await _loadAssignedMembers();
                            },
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
    // 할당된 팀원 목록 다시 로드
    await _loadAssignedMembers();
  }

  /// 생성자 이름 가져오기
  String _getCreatorUsername(Task task) {
    // 실제로는 태스크에 creatorId가 있어야 하지만, 현재는 없으므로 기본값 반환
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.currentUser?.username ?? 'Unknown';
  }

  /// 새 댓글을 타임라인에 부드럽게 추가
  Future<void> _addCommentToTimeline(Comment comment) async {
    // 현재 타임라인 아이템 가져오기
    final currentItems = _timelineItems ?? [];
    
    // 새 댓글 아이템 생성
    final newCommentItem = TimelineItem(
      type: TimelineItemType.comment,
      date: comment.createdAt,
      data: comment,
    );
    
    // 기존 아이템에 새 댓글 추가
    final updatedItems = List<TimelineItem>.from(currentItems);
    updatedItems.add(newCommentItem);
    
    // 시간순으로 정렬
    updatedItems.sort((a, b) {
      final aUtc = a.date.isUtc ? a.date : a.date.toUtc();
      final bUtc = b.date.isUtc ? b.date : b.date.toUtc();
      final aMs = aUtc.millisecondsSinceEpoch;
      final bMs = bUtc.millisecondsSinceEpoch;
      return aMs.compareTo(bMs);
    });
    
    if (mounted) {
      setState(() {
        _timelineItems = updatedItems;
      });
      
      // 부드럽게 맨 아래로 스크롤 - 여러 번 시도하여 확실하게
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomSmooth();
      });
      
      // 추가 시도: 애니메이션 완료 후 다시 스크롤
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _scrollToBottomSmooth();
        }
      });
    }
  }

  /// 타임라인 아이템들 빌드 (시간순 정렬)
  List<TimelineItem> _buildTimelineItems(Task task) {
    final List<TimelineItem> items = [];
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

    // 할당 히스토리 (실제 할당 기록 사용)
    for (final history in task.assignmentHistory) {
      items.add(TimelineItem(
        type: TimelineItemType.history,
        date: history.assignedAt,
        data: HistoryEvent(
          username: history.assignedByUsername,
          action: 'assigned',
          target: Text(
            history.assignedUsername,
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

    // 코멘트 추가
    for (final comment in _comments) {
      items.add(TimelineItem(
        type: TimelineItemType.comment,
        date: comment.createdAt,
        data: comment,
      ));
    }

    // 상태 변경 히스토리 (실제 상태 변경 기록 사용)
    for (final history in task.statusHistory) {
      items.add(TimelineItem(
        type: TimelineItemType.history,
        date: history.changedAt,
        data: HistoryEvent(
          username: history.username,
          action: 'moved this to',
          target: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: history.toStatus.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                history.toStatus.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: history.toStatus.color,
                ),
              ),
            ],
          ),
          icon: Icons.view_kanban_outlined,
        ),
      ));
    }
    
    // 중요도 변경 히스토리
    for (final history in task.priorityHistory) {
      items.add(TimelineItem(
        type: TimelineItemType.history,
        date: history.changedAt,
        data: HistoryEvent(
          username: history.username,
          action: 'changed priority to',
          target: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: history.toPriority.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${history.toPriority.displayName} - ${history.toPriority.description}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: history.toPriority.color,
                ),
              ),
            ],
          ),
          icon: Icons.priority_high,
        ),
      ));
    }
    
    // 시간순으로 정렬 (오래된 것부터 - 최신 항목이 아래에 표시됨)
    // 모든 날짜를 UTC로 변환하여 타임존 차이 문제 해결
    items.sort((a, b) {
      // Local 타임존을 UTC로 변환
      final aUtc = a.date.isUtc ? a.date : a.date.toUtc();
      final bUtc = b.date.isUtc ? b.date : b.date.toUtc();
      
      // UTC로 변환한 후 millisecondsSinceEpoch 비교
      final aMs = aUtc.millisecondsSinceEpoch;
      final bMs = bUtc.millisecondsSinceEpoch;
      return aMs.compareTo(bMs);
    });

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
            AvatarColor.getInitial(username),
            style: const TextStyle(
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
  /// 상대 날짜 포맷팅 (한국 시간 기준)
  String _formatRelativeDate(DateTime date) {
    // UTC 날짜를 로컬 시간(한국 시간)으로 변환
    final localDate = date.isUtc ? date.toLocal() : date;
    final now = DateTime.now(); // 이미 로컬 시간
    final difference = now.difference(localDate);
    
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
              Colors.white.withOpacity(0.8),
              Colors.white.withOpacity(0.7),
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
              Colors.white.withOpacity(0.8),
              Colors.white.withOpacity(0.7),
            ],
            child: Stack(
              children: [
                // 메인 컨텐츠 (최상단 배치)
                Padding(
                  padding: const EdgeInsets.only(right: 36), // 연필 아이콘 공간 확보
                  child: isEditing
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            ),
                            // 선택된 이미지 미리보기
                            if (_selectedDetailImages.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedDetailImages.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: _XFileImage(
                                              xfile: _selectedDetailImages[index],
                                              width: 100,
                                              height: 100,
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _selectedDetailImages.removeAt(index);
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: Colors.white,
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
                            const SizedBox(height: 8),
                            IconButton(
                              icon: Icon(
                                Icons.image,
                                color: colorScheme.primary,
                              ),
                              onPressed: _pickDetailImages,
                              tooltip: '이미지 추가',
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.detail.isNotEmpty)
                              MarkdownBody(
                                data: task.detail,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                  p: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurface.withOpacity(0.85),
                                    height: 1.6,
                                  ),
                                ),
                              )
                            else
                              Text(
                                '상세 내용이 없습니다. 편집 버튼을 눌러 추가하세요.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  height: 1.5,
                                ),
                              ),
                            // 이미지 표시
                            if (task.detailImageUrls.isNotEmpty) ...[
                              if (task.detail.isNotEmpty) const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: task.detailImageUrls.map((imageUrl) {
                                  return GestureDetector(
                                    onTap: () => _showImageDialog(context, imageUrl, task.detailImageUrls),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 200,
                                            height: 200,
                                            color: Colors.white.withOpacity(0.7),
                                            child: Icon(
                                              Icons.broken_image,
                                              color: colorScheme.onSurface.withOpacity(0.5),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                ),
                // 연필 아이콘 (오른쪽 상단 고정)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
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
              AvatarColor.getInitial(comment.username),
              style: const TextStyle(
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
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _startEditComment(comment);
                          } else if (value == 'delete') {
                            _deleteComment(comment.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('편집'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('삭제', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 8.0,
                  blur: 15.0,
                  gradientColors: [
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.7),
                  ],
                  child: _editingCommentId == comment.id
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _editCommentController,
                              maxLines: null,
                              minLines: 3,
                              decoration: InputDecoration(
                                hintText: '댓글을 수정하세요...',
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
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _cancelEditComment,
                                  child: Text(
                                    '취소',
                                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () => _updateComment(comment.id),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('저장'),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (comment.content.isNotEmpty)
                              MarkdownBody(
                                data: comment.content,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                  p: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurface.withOpacity(0.85),
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            // 이미지 표시
                            if (comment.imageUrls.isNotEmpty) ...[
                              if (comment.content.isNotEmpty) const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: comment.imageUrls.map((imageUrl) {
                                  return GestureDetector(
                                    onTap: () => _showImageDialog(context, imageUrl, comment.imageUrls),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 200,
                                            height: 200,
                                            color: Colors.white.withOpacity(0.7),
                                            child: Icon(
                                              Icons.broken_image,
                                              color: colorScheme.onSurface.withOpacity(0.5),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
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
              DropTarget(
                onDragEntered: (_) {
                  setState(() => _isCommentDropHover = true);
                },
                onDragExited: (_) {
                  setState(() => _isCommentDropHover = false);
                },
                onDragDone: (details) {
                  setState(() => _isCommentDropHover = false);
                  final dropped = details.files
                      .where((file) => file.path.isNotEmpty && _isSupportedImageFile(file.path))
                      .map((file) => XFile(file.path))
                      .toList();
                  if (dropped.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('이미지 파일만 드롭할 수 있습니다. (png, jpg, jpeg, gif, webp)'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _selectedCommentImages.addAll(dropped);
                  });
                },
                child: Shortcuts(
                    shortcuts: {
                      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): const _PasteIntent(),
                      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): const _SubmitCommentIntent(),
                    },
                    child: Actions(
                      actions: {
                        _PasteIntent: CallbackAction<_PasteIntent>(
                          onInvoke: (intent) => _handlePaste(),
                        ),
                        _SubmitCommentIntent: CallbackAction<_SubmitCommentIntent>(
                          onInvoke: (intent) {
                            if (_commentController.text.trim().isNotEmpty || _selectedCommentImages.isNotEmpty) {
                              _addComment();
                            }
                            return null;
                          },
                        ),
                      },
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          // Shift+Enter는 줄바꿈, Enter만 누르면 전송
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed &&
                              _commentFocusNode.hasFocus) {
                            if (_commentController.text.trim().isNotEmpty || _selectedCommentImages.isNotEmpty) {
                              _addComment();
                            }
                          }
                        },
                        child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isCommentDropHover
                                ? colorScheme.primary.withOpacity(0.8)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: GlassContainer(
                          padding: const EdgeInsets.all(12),
                          borderRadius: 12.0,
                          blur: 20.0,
                          gradientColors: [
                            Colors.white.withOpacity(0.8),
                            Colors.white.withOpacity(0.7),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                maxLines: null,
                                minLines: 3,
                                textInputAction: TextInputAction.send,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment... (Enter로 전송, Shift+Enter로 줄바꿈, 이미지를 드래그하거나 Ctrl+V로 붙여넣기)',
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
                                // onSubmitted 제거 - KeyboardListener가 Enter 키를 처리함
                              ),
                              // 선택된 이미지 미리보기
                              if (_selectedCommentImages.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedCommentImages.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: _XFileImage(
                                                xfile: _selectedCommentImages[index],
                                                width: 100,
                                                height: 100,
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedCommentImages.removeAt(index);
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.white,
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
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.image,
                                      color: colorScheme.primary,
                                    ),
                                    onPressed: _pickCommentImages,
                                    tooltip: '이미지 추가',
                                  ),
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
                      ),
                        ),
                    ),
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isSupportedImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  /// 붙여넣기 처리
  Future<void> _handlePaste() async {
    if (!_commentFocusNode.hasFocus) return;
    
    try {
      // 먼저 텍스트 클립보드 확인
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
        // 텍스트가 있으면 TextField에 붙여넣기
        final text = clipboardData.text!;
        final currentText = _commentController.text;
        final selection = _commentController.selection;
        
        if (selection.isValid) {
          // 선택된 텍스트가 있으면 교체, 없으면 커서 위치에 삽입
          final newText = currentText.replaceRange(
            selection.start,
            selection.end,
            text,
          );
          _commentController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start + text.length),
          );
        } else {
          // 커서가 없으면 끝에 추가
          _commentController.text = currentText + text;
          _commentController.selection = TextSelection.collapsed(
            offset: _commentController.text.length,
          );
        }
        return;
      }
      
      // 텍스트가 없으면 이미지 확인 (Windows에서만)
      if (Platform.isWindows) {
        const platform = MethodChannel('com.dora/clipboard');
        try {
          final result = await platform.invokeMethod('getClipboardImage');
          if (result != null) {
            if (result is Map) {
              final type = result['type'];
              if (type == 'base64') {
                final data = result['data'];
                if (data is String && data.isNotEmpty) {
                  final imageBytes = base64Decode(data);
                  final xfile = XFile.fromData(
                    imageBytes,
                    name: 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
                  );
                  setState(() {
                    _selectedCommentImages.add(xfile);
                  });
                  return;
                }
              } else if (type == 'paths') {
                final List<dynamic>? rawPaths = result['data'] as List<dynamic>?;
                if (rawPaths != null && rawPaths.isNotEmpty) {
                  final dropped = rawPaths
                      .whereType<String>()
                      .where((path) => _isSupportedImageFile(path))
                      .map((path) => XFile(path))
                      .toList();

                  if (dropped.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('이미지 파일만 붙여넣을 수 있습니다. (png, jpg, jpeg, gif, webp)'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _selectedCommentImages.addAll(dropped);
                  });
                  return;
                }
              }
            } else if (result is String && result.isNotEmpty) {
              final imageBytes = base64Decode(result);
              final xfile = XFile.fromData(
                imageBytes,
                name: 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
              );
              setState(() {
                _selectedCommentImages.add(xfile);
              });
              return;
            }
          }
        } catch (e) {
          // 플랫폼 채널이 없거나 실패한 경우 무시
        }
      }
      
      // 텍스트도 이미지도 없으면 아무것도 하지 않음 (에러 메시지 제거)
    } catch (e) {
      // 에러 발생 시 무시
    }
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

  /// 이미지 확대 다이얼로그 표시
  void _showImageDialog(BuildContext context, String imageUrl, List<String> allImageUrls) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = allImageUrls.indexOf(imageUrl);
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * 0.85;
    final maxHeight = screenSize.height * 0.75;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Stack(
              children: [
                // 이미지 뷰어
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 400,
                              height: 400,
                              color: Colors.white.withOpacity(0.7),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 64,
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '이미지를 불러올 수 없습니다',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                // 닫기 버튼
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.6),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ),
                // 여러 이미지가 있을 경우 네비게이션 버튼
                if (allImageUrls.length > 1) ...[
                  // 이전 이미지
                  if (currentIndex > 0)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showImageDialog(context, allImageUrls[currentIndex - 1], allImageUrls);
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                    ),
                  // 다음 이미지
                  if (currentIndex < allImageUrls.length - 1)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showImageDialog(context, allImageUrls[currentIndex + 1], allImageUrls);
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                    ),
                  // 이미지 인덱스 표시
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${currentIndex + 1} / ${allImageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// XFile 미리보기 (웹/데스크톱 공통, Image.file 대체)
class _XFileImage extends StatelessWidget {
  const _XFileImage({
    required this.xfile,
    required this.width,
    required this.height,
  });

  final XFile xfile;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: xfile.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: BoxFit.cover,
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            width: width,
            height: height,
            child: Icon(Icons.broken_image, size: width * 0.5, color: Colors.grey),
          );
        }
        return SizedBox(
          width: width,
          height: height,
          child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
        );
      },
    );
  }
}

