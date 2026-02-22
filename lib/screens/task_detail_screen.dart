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
import '../utils/api_client.dart';
import '../widgets/glass_container.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../utils/avatar_color.dart';

/// 遺숈뿬?ｊ린 Intent
class _PasteIntent extends Intent {
  const _PasteIntent();
}

/// 肄붾찘???꾩넚 Intent (Ctrl+Enter)
class _SubmitCommentIntent extends Intent {
  const _SubmitCommentIntent();
}

/// ??꾨씪???꾩씠?????
enum TimelineItemType {
  history,
  comment,
  detail,
}

/// ??꾨씪???꾩씠???곗씠???대옒??
class TimelineItem {
  final TimelineItemType type;
  final DateTime date;
  final dynamic data; // HistoryEvent ?먮뒗 Comment

  TimelineItem({
    required this.type,
    required this.date,
    required this.data,
  });
}

/// ?덉뒪?좊━ ?대깽???곗씠???대옒??
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

/// ?쒖뒪???곸꽭 ?붾㈃ - GitHub ?댁뒋 ?ㅽ???
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
  List<TimelineItem>? _timelineItems;  // ??꾨씪???꾩씠??罹먯떆
  String? _editingCommentId;  // ?몄쭛 以묒씤 肄붾찘??ID
  late TextEditingController _editCommentController;  // ?몄쭛??而⑦듃濡ㅻ윭
  List<XFile> _selectedCommentImages = [];  // ?볤????좏깮???대?吏 (???곗뒪?ы넲 怨듯넻)
  List<XFile> _selectedDetailImages = [];    // ?곸꽭 ?댁슜???좏깮???대?吏
  List<String> _uploadedCommentImageUrls = [];  // ?낅줈?쒕맂 ?볤? ?대?吏 URL
  List<String> _uploadedDetailImageUrls = [];   // ?낅줈?쒕맂 ?곸꽭 ?댁슜 ?대?吏 URL
  List<User>? _assignedMembers;  // ?좊떦?????罹먯떆
  bool _isInitialLoad = true;  // 珥덇린 濡쒕뱶 ?щ?
  List<String>? _lastAssignedMemberIds;  // ?댁쟾 ?좊떦?????ID (?숆린???뺤씤??

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

    // 珥덇린 濡쒕뱶 ???ㅽ겕濡ㅼ씠 留??꾨옒濡?媛吏 ?딅룄濡?由ъ뒪??異붽?
    _timelineScrollController.addListener(() {
      if (_isInitialLoad && _timelineScrollController.hasClients) {
        // 珥덇린 濡쒕뱶 以묒뿉 ?ㅽ겕濡ㅼ씠 留??꾨옒濡?媛?ㅺ퀬 ?섎㈃ 留??꾨줈 ?섎룎由?
        if (_timelineScrollController.offset > 10) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isInitialLoad && _timelineScrollController.hasClients) {
              _timelineScrollController.jumpTo(0.0);
            }
          });
        }
      }
    });

    // ?ㅼ떆媛??볤? 媛깆떊 由ъ뒪???깅줉
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskProvider = context.read<TaskProvider>();
      taskProvider.addCommentListener(widget.task.id, _onCommentCreated);
    });

    // 珥덇린 ?곗씠??濡쒕뱶 (??踰덉뿉 泥섎━?섏뿬 setState 理쒖냼??
    _loadInitialData();
  }

  /// WebSocket?쇰줈 ?볤? ?앹꽦 ?대깽???섏떊 ???몄텧
  void _onCommentCreated() {
    if (mounted) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    // ?ㅼ떆媛??볤? 媛깆떊 由ъ뒪???댁젣
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

  /// 珥덇린 ?곗씠??濡쒕뱶 (?깅뒫 理쒖쟻?? ??踰덉뿉 泥섎━)
  // 梨꾪똿 ?붾㈃怨??숈씪?섍쾶 ?곷?寃쎈줈 ?대?吏瑜??덈?寃쎈줈濡?蹂??  String _resolveImageUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${ApiClient.baseUrl}$trimmed';
    }
    return '${ApiClient.baseUrl}/$trimmed';
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingComments = true;
    });
    
    try {
      // ?볤?怨??좊떦????먯쓣 ?숈떆??濡쒕뱶
      final results = await Future.wait([
        _commentService.getCommentsByTaskId(widget.task.id),
        _loadAssignedMembersData(),
      ]);
      
      final comments = results[0] as List<Comment>;
      final members = results[1] as List<User>?;
      
      // ??踰덈쭔 setState ?몄텧
      setState(() {
        _comments = comments;
        _assignedMembers = members;
        _isLoadingComments = false;
      });
      
      // ??꾨씪???꾩씠???낅뜲?댄듃 (setState??_loadTimelineItems ?대??먯꽌 ?몄텧)
      await _loadTimelineItems();
      
      // ?좊떦?????紐⑸줉??鍮꾩뼱?덉?留??쒖뒪?ъ뿉 ?좊떦????먯씠 ?덈떎硫??ㅼ떆 濡쒕뱶
      if ((members == null || members.isEmpty) && widget.task.assignedMemberIds.isNotEmpty) {
        await _loadAssignedMembers();
      }
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  /// ?볤? 濡쒕뱶
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
      // 肄붾찘??濡쒕뱶 ????꾨씪???꾩씠???낅뜲?댄듃 (?듭뀡)
      if (updateTimeline) {
        await _loadTimelineItems();
      }
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }
  
  /// ?좊떦??????곗씠??濡쒕뱶 (諛섑솚媛??덉쓬)
  Future<List<User>?> _loadAssignedMembersData() async {
    final taskProvider = context.read<TaskProvider>();
    // 理쒖떊 ?쒖뒪???뺣낫 媛?몄삤湲?(taskProvider?먯꽌 癒쇱? 李얘퀬, ?놁쑝硫?widget.task ?ъ슜)
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    
    // ?좊떦????먯씠 ?놁쑝硫?鍮?由ъ뒪??諛섑솚
    if (currentTask.assignedMemberIds.isEmpty) {
      return [];
    }
    
    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      final members = allUsers.where((user) => currentTask.assignedMemberIds.contains(user.id)).toList();
      
      // ?좊떦?????ID媛 ?덉?留??ъ슜?먮? 李얠? 紐삵븳 寃쎌슦??鍮?由ъ뒪??諛섑솚?섏? ?딄퀬 濡쒓렇 異쒕젰
      if (members.isEmpty && currentTask.assignedMemberIds.isNotEmpty) {
        print('[TaskDetailScreen] ?좊떦?????ID: ${currentTask.assignedMemberIds}, 李얠? ?ъ슜?? ${members.length}紐?);
      }
      
      return members;
    } catch (e) {
      print('[TaskDetailScreen] ?좊떦?????濡쒕뱶 ?ㅽ뙣: $e');
      return [];
    }
  }

  /// ??꾨씪???꾩씠??濡쒕뱶 (?ㅽ겕濡??꾩튂 ?좎?)
  Future<void> _loadTimelineItems({bool scrollToBottom = false}) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    
    // 珥덇린 濡쒕뱶 ?쒖뿉???ㅽ겕濡ㅼ쓣 留??꾨줈 ?좎??댁빞 ?섎?濡???ν븯吏 ?딆쓬
    double? savedScrollPosition;
    final bool hadClients = _timelineScrollController.hasClients;
    if (!scrollToBottom && hadClients && !_isInitialLoad) {
      savedScrollPosition = _timelineScrollController.offset;
    }
    
      final timelineItems = _buildTimelineItems(currentTask);
    
    if (mounted) {
      // setState瑜??몄텧?섍린 ?꾩뿉 ?ㅽ겕濡??꾩튂瑜?誘몃━ ???
      final maxScrollBefore = hadClients 
          ? _timelineScrollController.position.maxScrollExtent 
          : 0.0;
      
      setState(() {
        _timelineItems = timelineItems;
      });
      
      // setState ???ㅽ겕濡??꾩튂 蹂듭썝 ?먮뒗 留??꾨옒濡??대룞
      if (scrollToBottom) {
        // 肄붾찘??異붽? ??留??꾨옒濡??대룞 - ?щ윭 踰??쒕룄?섏뿬 ?뺤떎?섍쾶
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isInitialLoad) {
            _scrollToBottom();
          }
        });
      } else if (savedScrollPosition != null && !_isInitialLoad) {
        // ??λ맂 ?꾩튂濡?蹂듭썝 (珥덇린 濡쒕뱶媛 ?꾨땺 ?뚮쭔)
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
        // 珥덇린 濡쒕뱶 ???ㅽ겕濡ㅼ쓣 留??꾨줈 ?좎? (?묒뾽 移대뱶 吏꾩엯 ??
        // ?щ윭 踰??쒕룄?섏뿬 ?뺤떎?섍쾶 留??꾨줈 ?좎?
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_timelineScrollController.hasClients) return;
          // 媛뺤젣濡?留??꾨줈 ?대룞
          _timelineScrollController.jumpTo(0.0);
        });
        // 異붽? ?쒕룄: ?덉씠?꾩썐 ?꾨즺 ???ㅼ떆 ?뺤씤
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
          // 珥덇린 濡쒕뱶 ?꾨즺 ?쒖떆 (紐⑤뱺 ?ㅽ겕濡??쒕룄媛 ?앸궃 ??
          _isInitialLoad = false;
        });
      }
      // 珥덇린 濡쒕뱶媛 ?꾨땲怨???λ맂 ?꾩튂???녿뒗 寃쎌슦 ?ㅽ겕濡??꾩튂瑜?蹂寃쏀븯吏 ?딆쓬
    }
  }

  /// 留??꾨옒濡??ㅽ겕濡?(?щ윭 踰??쒕룄?섏뿬 ?뺤떎?섍쾶)
  void _scrollToBottom() {
    if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
    
    // 利됱떆 ?쒕룄
    final maxScroll = _timelineScrollController.position.maxScrollExtent;
    _timelineScrollController.jumpTo(maxScroll);
    
    // ?쎄컙??吏?????ㅼ떆 ?쒕룄 (?덉씠?꾩썐???꾩쟾???꾨즺????
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
      final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
      _timelineScrollController.animateTo(
        maxScrollAfter,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
    
    // 異붽? 吏??????踰????쒕룄 (?대?吏 濡쒕뵫 ?깆쑝濡??믪씠媛 蹂寃쎈맆 ???덉쓬)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
      final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
      _timelineScrollController.jumpTo(maxScrollAfter);
    });
  }

  /// 遺?쒕읇寃?留??꾨옒濡??ㅽ겕濡?(移댁뭅?ㅽ넚 ?ㅽ???
  void _scrollToBottomSmooth() {
    if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
    
    // 利됱떆 ?쒕룄 (?덉씠?꾩썐???대? ?꾨즺??寃쎌슦)
    final maxScroll = _timelineScrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      _timelineScrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    
    // ?덉씠?꾩썐 ?꾨즺 ???ㅼ떆 ?쒕룄
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
    
    // ?대?吏 濡쒕뵫 ?깆쑝濡??믪씠媛 蹂寃쎈맆 ???덉쑝誘濡???踰????쒕룄
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad) return;
      final maxScrollFinal = _timelineScrollController.position.maxScrollExtent;
      if (maxScrollFinal > 0) {
        _timelineScrollController.jumpTo(maxScrollFinal);
      }
    });
  }

  /// ?대?吏 ?좏깮 (?볤???
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
            content: Text('?대?吏 ?좏깮 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// ?대?吏 ?좏깮 (?곸꽭 ?댁슜??
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
            content: Text('?대?吏 ?좏깮 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// ?볤? 異붽?
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty && _selectedCommentImages.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    final user = authProvider.currentUser!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    try {
      // ?대?吏 ?낅줈??
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

      // Task???볤? ID 異붽?
      final currentTask = taskProvider.tasks.firstWhere(
        (t) => t.id == widget.task.id,
        orElse: () => widget.task,
      );
      
      // commentIds媛 null?닿굅???섎せ????낆씤 寃쎌슦瑜??鍮?
      List<String> updatedCommentIds;
      try {
        updatedCommentIds = List<String>.from(currentTask.commentIds);
      } catch (e) {
        // commentIds媛 null?닿굅???섎せ????낆씤 寃쎌슦 鍮?由ъ뒪?몃줈 ?쒖옉
        updatedCommentIds = [];
      }
      
      updatedCommentIds.add(comment.id);
      
      
      await taskProvider.updateTask(
        currentTask.copyWith(
          commentIds: updatedCommentIds,
          updatedAt: DateTime.now(),
        ),
      );

      // ?낅젰 ?꾨뱶 珥덇린??
      _commentController.clear();
      _selectedCommentImages.clear();
      _uploadedCommentImageUrls.clear();
      
      // ?숆????낅뜲?댄듃: 利됱떆 濡쒖뺄 ?곹깭???볤? 異붽? (移댁뭅?ㅽ넚泥섎읆 遺?쒕읇寃?
      setState(() {
        _comments.add(comment);
      });
      
      // ??꾨씪?몄뿉 ???볤?留?遺?쒕읇寃?異붽?
      await _addCommentToTimeline(comment);
      
      // 諛깃렇?쇱슫?쒖뿉???쒕쾭 ?숆린??(?ъ슜??寃쏀뿕???곹뼢 ?놁쓬)
      _loadComments(updateTimeline: false).catchError((e) {
        // ?숆린???ㅽ뙣?대룄 ?대? 濡쒖뺄??異붽??섏뼱 ?덉쑝誘濡?臾댁떆
      });
    } catch (e) {
      if (mounted) {
        print('[ERROR] ?볤? 異붽? ?ㅽ뙣: $e');
        print('[ERROR] task_id: ${widget.task.id}');
        print('[ERROR] content: ${_commentController.text}');
        print('[ERROR] imageUrls: ${_selectedCommentImages.length}媛?);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('?볤? 異붽? 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// ?볤? ?몄쭛 ?쒖옉
  void _startEditComment(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _editCommentController.text = comment.content;
    });
  }

  /// ?볤? ?몄쭛 痍⑥냼
  void _cancelEditComment() {
    setState(() {
      _editingCommentId = null;
      _editCommentController.clear();
    });
  }

  /// ?볤? ?낅뜲?댄듃
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
      
      // 濡쒖뺄 肄붾찘??由ъ뒪???낅뜲?댄듃
      final index = _comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        setState(() {
          _comments[index] = updatedComment;
          _editingCommentId = null;
          _editCommentController.clear();
        });
      }

      // ??꾨씪???낅뜲?댄듃
      await _loadTimelineItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('?볤? ?섏젙 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// ?볤? ??젣
  Future<void> _deleteComment(String commentId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    final comment = _comments.firstWhere((c) => c.id == commentId);
    
    // 蹂몄씤 ?볤?留???젣 媛??
    if (comment.userId != authProvider.currentUser!.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('蹂몄씤???볤?留???젣?????덉뒿?덈떎'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      await _commentService.deleteComment(commentId);
      
      // Task?먯꽌 ?볤? ID ?쒓굅
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
            content: Text('?볤? ??젣 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // context.read瑜??ъ슜?섏뿬 遺덊븘?뷀븳 由щ퉴??諛⑹?
    final taskProvider = context.read<TaskProvider>();
    final projectProvider = context.read<ProjectProvider>();
    final currentProject = projectProvider.currentProject;
    
    // 理쒖떊 ?쒖뒪???뺣낫 媛?몄삤湲?
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    
    // ?좊떦?????ID媛 蹂寃쎈릺?덈뒗吏 ?뺤씤?섍퀬 ?숆린??
    final currentAssignedIds = currentTask.assignedMemberIds;
    if (_lastAssignedMemberIds == null || 
        !listEquals(_lastAssignedMemberIds!, currentAssignedIds)) {
      _lastAssignedMemberIds = List.from(currentAssignedIds);
      // ?ㅼ쓬 ?꾨젅?꾩뿉???좊떦?????紐⑸줉 ?ㅼ떆 濡쒕뱶
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
          onTap: () {}, // ?대? ?대┃ ?대깽?몃? 留됱븘??諛붽묑 ?곸뿭 ?대┃留?媛먯??섎룄濡?
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
              // ?ㅻ뜑
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
                  // 以묒슂??諛곗?
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
                  // ?곹깭 諛곗?
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
                  // ?リ린 踰꾪듉
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 硫붿씤 而⑦뀗痢?
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ?쇱そ: ??꾨씪??
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        controller: _timelineScrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ?곸꽭 ?댁슜 (??긽 留???
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
                            // ??꾨씪???꾩씠?쒕뱾 (?쒓컙???뺣젹)
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
                            // ?볤? ?낅젰
                            const SizedBox(height: 16),
                            _buildCommentInput(context, colorScheme),
                          ],
                        ),
                      ),
                    ),
                      const SizedBox(width: 24),
                      // ?ㅻⅨ履? ?ъ씠?쒕컮
                      SizedBox(
                        width: 280,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // ?꾨줈?앺듃
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
                                          '?꾨줈?앺듃',
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
                            // ?곹깭
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
                                        '?곹깭',
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
                                        // ?곹깭 蹂寃?????꾨씪???낅뜲?댄듃
                                        await _loadTimelineItems();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 以묒슂??
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
                                        '以묒슂??,
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
                                        // 以묒슂??蹂寃?????꾨씪???낅뜲?댄듃
                                        await _loadTimelineItems();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 湲곌컙 (?쒖옉??~ 醫낅즺??
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
                                        '湲곌컙',
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
                                      // ?쒖옉??
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
                                                  '?쒖옉??,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                      _startDate != null
                                          ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                                          : '?좎쭨 ?좏깮',
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
                                      // 醫낅즺??
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
                                                  '醫낅즺??,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                      _endDate != null
                                          ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                          : '?좎쭨 ?좏깮',
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
                            // ?좊떦?????
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
                                        '?좊떦?????,
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
                                        tooltip: '????좊떦',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (currentTask.assignedMemberIds.isEmpty)
                                    Text(
                                      '?좊떦????먯씠 ?놁뒿?덈떎',
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
                            // ?앹꽦??
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
                                    '?앹꽦??,
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
      // ?대?吏 ?낅줈??
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
            content: Text('?쒖뒪?????以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// ?좊떦?????紐⑸줉 濡쒕뱶
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

  /// ????좊떦 ?ㅼ씠?쇰줈洹?
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
            content: const Text('?좊떦?????덈뒗 ??먯씠 ?놁뒿?덈떎'),
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
                      '????좊떦',
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
                              // ??紐낅쭔 ?좏깮 媛?ν븯?꾨줉 湲곗〈 ?좊떦???泥?
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
                                // 硫붿씤?붾㈃ ?낅뜲?댄듃瑜??꾪빐 ?쒖뒪??紐⑸줉 ?ㅼ떆 濡쒕뱶
                                await taskProvider.loadTasks();
                              }
                              Navigator.of(context).pop();
                              // ?좊떦?????紐⑸줉 ?ㅼ떆 濡쒕뱶
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
                            '?リ린',
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
          content: Text('?ㅻ쪟 諛쒖깮: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  /// ?좊떦??????쒓굅
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
    // ?좊떦?????紐⑸줉 ?ㅼ떆 濡쒕뱶
    await _loadAssignedMembers();
  }

  /// ?앹꽦???대쫫 媛?몄삤湲?
  String _getCreatorUsername(Task task) {
    // ?ㅼ젣濡쒕뒗 ?쒖뒪?ъ뿉 creatorId媛 ?덉뼱???섏?留? ?꾩옱???놁쑝誘濡?湲곕낯媛?諛섑솚
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.currentUser?.username ?? 'Unknown';
  }

  /// ???볤?????꾨씪?몄뿉 遺?쒕읇寃?異붽?
  Future<void> _addCommentToTimeline(Comment comment) async {
    // ?꾩옱 ??꾨씪???꾩씠??媛?몄삤湲?
    final currentItems = _timelineItems ?? [];
    
    // ???볤? ?꾩씠???앹꽦
    final newCommentItem = TimelineItem(
      type: TimelineItemType.comment,
      date: comment.createdAt,
      data: comment,
    );
    
    // 湲곗〈 ?꾩씠?쒖뿉 ???볤? 異붽?
    final updatedItems = List<TimelineItem>.from(currentItems);
    updatedItems.add(newCommentItem);
    
    // ?쒓컙?쒖쑝濡??뺣젹
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
      
      // 遺?쒕읇寃?留??꾨옒濡??ㅽ겕濡?- ?щ윭 踰??쒕룄?섏뿬 ?뺤떎?섍쾶
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomSmooth();
      });
      
      // 異붽? ?쒕룄: ?좊땲硫붿씠???꾨즺 ???ㅼ떆 ?ㅽ겕濡?
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _scrollToBottomSmooth();
        }
      });
    }
  }

  /// ??꾨씪???꾩씠?쒕뱾 鍮뚮뱶 (?쒓컙???뺣젹)
  List<TimelineItem> _buildTimelineItems(Task task) {
    final List<TimelineItem> items = [];
    final colorScheme = Theme.of(context).colorScheme;

    // ?댁뒋 ?앹꽦 湲곕줉
    items.add(TimelineItem(
      type: TimelineItemType.history,
      date: task.createdAt,
      data: HistoryEvent(
        username: _getCreatorUsername(task),
        action: 'opened this',
        icon: Icons.circle_outlined,
      ),
    ));

    // ?좊떦 ?덉뒪?좊━ (?ㅼ젣 ?좊떦 湲곕줉 ?ъ슜)
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

    // 肄붾찘??異붽?
    for (final comment in _comments) {
      items.add(TimelineItem(
        type: TimelineItemType.comment,
        date: comment.createdAt,
        data: comment,
      ));
    }

    // ?곹깭 蹂寃??덉뒪?좊━ (?ㅼ젣 ?곹깭 蹂寃?湲곕줉 ?ъ슜)
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
    
    // 以묒슂??蹂寃??덉뒪?좊━
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
    
    // ?쒓컙?쒖쑝濡??뺣젹 (?ㅻ옒??寃껊???- 理쒖떊 ??ぉ???꾨옒???쒖떆??
    // 紐⑤뱺 ?좎쭨瑜?UTC濡?蹂?섑븯????꾩〈 李⑥씠 臾몄젣 ?닿껐
    items.sort((a, b) {
      // Local ??꾩〈??UTC濡?蹂??
      final aUtc = a.date.isUtc ? a.date : a.date.toUtc();
      final bUtc = b.date.isUtc ? b.date : b.date.toUtc();
      
      // UTC濡?蹂?섑븳 ??millisecondsSinceEpoch 鍮꾧탳
      final aMs = aUtc.millisecondsSinceEpoch;
      final bMs = bUtc.millisecondsSinceEpoch;
      return aMs.compareTo(bMs);
    });

    return items;
  }

  /// ?덉뒪?좊━ ?꾩씠??鍮뚮뱶 (GitHub ?ㅽ???- ?묒? ?꾩씠肄섍낵 ?띿뒪??
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
          // ?묒? ?꾩씠肄?(?꾨컮? ???
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
          // ?댁슜
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

  /// ??꾨씪???꾩씠??鍮뚮뱶 (肄붾찘?몄슜 - ?꾨컮? ?ы븿)
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
        // ?꾨컮?
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
        // ?댁슜
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

  /// ?곷????좎쭨 ?щ㎎??(?? "5 days ago", "yesterday")
  /// ?곷? ?좎쭨 ?щ㎎??(?쒓뎅 ?쒓컙 湲곗?)
  String _formatRelativeDate(DateTime date) {
    // UTC ?좎쭨瑜?濡쒖뺄 ?쒓컙(?쒓뎅 ?쒓컙)?쇰줈 蹂??
    final localDate = date.isUtc ? date.toLocal() : date;
    final now = DateTime.now(); // ?대? 濡쒖뺄 ?쒓컙
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

  /// ?ㅻ챸 ??꾨씪???꾩씠??
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
        const SizedBox(width: 44), // ?꾨컮? ?덈퉬 + 媛꾧꺽
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

  /// ?곸꽭 ?댁슜 ??꾨씪???꾩씠??
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
        const SizedBox(width: 44), // ?꾨컮? ?덈퉬 + 媛꾧꺽
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
                // 硫붿씤 而⑦뀗痢?(理쒖긽??諛곗튂)
                Padding(
                  padding: const EdgeInsets.only(right: 36), // ?고븘 ?꾩씠肄?怨듦컙 ?뺣낫
                  child: isEditing
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _detailController,
                              maxLines: null,
                              minLines: 8,
                              decoration: InputDecoration(
                                hintText: '?곸꽭 ?댁슜???낅젰?섏꽭??..',
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
                            // ?좏깮???대?吏 誘몃━蹂닿린
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
                              tooltip: '?대?吏 異붽?',
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
                                '?곸꽭 ?댁슜???놁뒿?덈떎. ?몄쭛 踰꾪듉???뚮윭 異붽??섏꽭??',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  height: 1.5,
                                ),
                              ),
                            // ?대?吏 ?쒖떆
                            if (task.detailImageUrls.isNotEmpty) ...[
                              if (task.detail.isNotEmpty) const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: () {
                                  final allImageUrls = task.detailImageUrls
                                      .map(_resolveImageUrl)
                                      .toList();
                                  return allImageUrls.map((imageUrl) {
                                    return GestureDetector(
                                      onTap: () => _showImageDialog(context, imageUrl, allImageUrls),
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
                                  }).toList();
                                }(),
                              ),
                            ],
                          ],
                        ),
                ),
                // ?고븘 ?꾩씠肄?(?ㅻⅨ履??곷떒 怨좎젙)
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
                    tooltip: isEditing ? '??? : '?몄쭛',
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

  /// ?볤? ??꾨씪???꾩씠??(肄붾찘???ㅽ???- ?꾨컮?? 諛뺤뒪)
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
                                Text('?몄쭛'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('??젣', style: TextStyle(color: Colors.red)),
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
                                hintText: '?볤????섏젙?섏꽭??..',
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
                                    '痍⑥냼',
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
                                  child: const Text('???),
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
                            // ?대?吏 ?쒖떆
                            if (comment.imageUrls.isNotEmpty) ...[
                              if (comment.content.isNotEmpty) const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: () {
                                  final allImageUrls = comment.imageUrls
                                      .map(_resolveImageUrl)
                                      .toList();
                                  return allImageUrls.map((imageUrl) {
                                    return GestureDetector(
                                      onTap: () => _showImageDialog(context, imageUrl, allImageUrls),
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
                                  }).toList();
                                }(),
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

  /// ?볤? ?낅젰 ?꾩젽
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
                        content: const Text('?대?吏 ?뚯씪留??쒕∼?????덉뒿?덈떎. (png, jpg, jpeg, gif, webp)'),
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
                          // Shift+Enter??以꾨컮轅? Enter留??꾨Ⅴ硫??꾩넚
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
                                  hintText: 'Add a comment... (Enter濡??꾩넚, Shift+Enter濡?以꾨컮轅? ?대?吏瑜??쒕옒洹명븯嫄곕굹 Ctrl+V濡?遺숈뿬?ｊ린)',
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
                                // onSubmitted ?쒓굅 - KeyboardListener媛 Enter ?ㅻ? 泥섎━??
                              ),
                              // ?좏깮???대?吏 誘몃━蹂닿린
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
                                    tooltip: '?대?吏 異붽?',
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

  /// 遺숈뿬?ｊ린 泥섎━
  Future<void> _handlePaste() async {
    if (!_commentFocusNode.hasFocus) return;
    
    try {
      // 癒쇱? ?띿뒪???대┰蹂대뱶 ?뺤씤
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
        // ?띿뒪?멸? ?덉쑝硫?TextField??遺숈뿬?ｊ린
        final text = clipboardData.text!;
        final currentText = _commentController.text;
        final selection = _commentController.selection;
        
        if (selection.isValid) {
          // ?좏깮???띿뒪?멸? ?덉쑝硫?援먯껜, ?놁쑝硫?而ㅼ꽌 ?꾩튂???쎌엯
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
          // 而ㅼ꽌媛 ?놁쑝硫??앹뿉 異붽?
          _commentController.text = currentText + text;
          _commentController.selection = TextSelection.collapsed(
            offset: _commentController.text.length,
          );
        }
        return;
      }
      
      // ?띿뒪?멸? ?놁쑝硫??대?吏 ?뺤씤 (Windows?먯꽌留?
      if (Platform.isWindows) {
        const platform = MethodChannel('com.sync/clipboard');
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
                        content: const Text('?대?吏 ?뚯씪留?遺숈뿬?ｌ쓣 ???덉뒿?덈떎. (png, jpg, jpeg, gif, webp)'),
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
          // ?뚮옯??梨꾨꼸???녾굅???ㅽ뙣??寃쎌슦 臾댁떆
        }
      }
      
      // ?띿뒪?몃룄 ?대?吏???놁쑝硫??꾨Т寃껊룄 ?섏? ?딆쓬 (?먮윭 硫붿떆吏 ?쒓굅)
    } catch (e) {
      // ?먮윭 諛쒖깮 ??臾댁떆
    }
  }

  /// ?좎쭨 ?щ㎎??
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

  /// ?대?吏 ?뺣? ?ㅼ씠?쇰줈洹??쒖떆
  void _showImageDialog(BuildContext context, String imageUrl, List<String> allImageUrls) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedImageUrl = _resolveImageUrl(imageUrl);
    final resolvedAllImageUrls = allImageUrls.map(_resolveImageUrl).toList();
    final matchedIndex = resolvedAllImageUrls.indexOf(resolvedImageUrl);
    final currentIndex = matchedIndex >= 0 ? matchedIndex : 0;
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
                // ?대?吏 酉곗뼱
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.network(
                          resolvedImageUrl,
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
                                    '?대?吏瑜?遺덈윭?????놁뒿?덈떎',
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
                // ?リ린 踰꾪듉
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
                // ?щ윭 ?대?吏媛 ?덉쓣 寃쎌슦 ?ㅻ퉬寃뚯씠??踰꾪듉
                if (resolvedAllImageUrls.length > 1) ...[
                  // ?댁쟾 ?대?吏
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
                            _showImageDialog(
                              context,
                              resolvedAllImageUrls[currentIndex - 1],
                              resolvedAllImageUrls,
                            );
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                    ),
                  // ?ㅼ쓬 ?대?吏
                  if (currentIndex < resolvedAllImageUrls.length - 1)
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
                            _showImageDialog(
                              context,
                              resolvedAllImageUrls[currentIndex + 1],
                              resolvedAllImageUrls,
                            );
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                    ),
                  // ?대?吏 ?몃뜳???쒖떆
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
                          '${currentIndex + 1} / ${resolvedAllImageUrls.length}',
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

/// XFile 誘몃━蹂닿린 (???곗뒪?ы넲 怨듯넻, Image.file ?泥?
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

