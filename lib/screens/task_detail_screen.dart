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
import '../models/project.dart';
import '../models/user.dart';
import '../models/comment.dart';
import '../models/checklist.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import '../services/checklist_service.dart';
import '../services/upload_service.dart';
import '../utils/api_client.dart';
import '../widgets/glass_container.dart';
import '../widgets/checklist_widget.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../utils/avatar_color.dart';
import 'package:url_launcher/url_launcher.dart';

/// ?븐늿肉?節딅┛ Intent
class _PasteIntent extends Intent {
  const _PasteIntent();
}

/// ?꾨뗀李???袁⑸꽊 Intent (Ctrl+Enter)
class _SubmitCommentIntent extends Intent {
  const _SubmitCommentIntent();
}

/// ???袁⑥뵬???袁⑹뵠??????
enum TimelineItemType { history, comment, detail, checklist }

/// ???袁⑥뵬???袁⑹뵠???怨쀬뵠???????
class TimelineItem {
  final TimelineItemType type;
  final DateTime date;
  final dynamic data; // HistoryEvent ?癒?뮉 Comment

  TimelineItem({required this.type, required this.date, required this.data});
}

/// ??됰뮞?醫듼봺 ??源???怨쀬뵠???????
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

/// ??뽯뮞???怨멸쉭 ?遺얇늺 - GitHub ??곷뭼 ?????
class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

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
  bool _isTitleEditing = false;
  bool _isTitleHovering = false;
  final FocusNode _titleFocusNode = FocusNode();
  final CommentService _commentService = CommentService();
  final ChecklistService _checklistService = ChecklistService();
  final UploadService _uploadService = UploadService();
  List<Checklist> _checklists = [];
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _timelineScrollController = ScrollController();
  bool _isCommentDropHover = false;
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  List<TimelineItem>? _timelineItems; // ???袁⑥뵬???袁⑹뵠??筌?Ŋ??
  String? _editingCommentId; // ?紐꾩춿 餓λ쵐???꾨뗀李??ID
  late TextEditingController _editCommentController; // ?紐꾩춿???뚢뫂?껅에?살쑎
  List<XFile> _selectedCommentImages =
      []; // ?蹂????醫뤾문?????筌왖 (???怨쀫뮞?????⑤벏??
  List<XFile> _selectedDetailImages = []; // ?怨멸쉭 ??곸뒠???醫뤾문?????筌왖
  List<String> _uploadedCommentImageUrls = []; // ??낆쨮??뺣쭆 ?蹂? ???筌왖 URL
  List<String> _uploadedDetailImageUrls = []; // ??낆쨮??뺣쭆 ?怨멸쉭 ??곸뒠 ???筌왖 URL
  List<User>? _assignedMembers; // ?醫딅뼣??????筌?Ŋ??
  List<User> _projectMembers = []; // 프로젝트 전체 멤버 (체크리스트 할당용)
  bool _isInitialLoad = true; // ?λ뜃由?嚥≪뮆諭????
  List<String>? _lastAssignedMemberIds; // ??곸읈 ?醫딅뼣??????ID (??녿┛???類ㅼ뵥??
  List<User> _mentionCandidates = [];
  List<User> _filteredMentionUsers = [];
  bool _showMentionSuggestions = false;
  int _mentionStartIndex = -1;
  int _selectedMentionIndex = -1;
  bool _showHistoryLogs = true;
  List<Map<String, String>> _documentLinks = [];
  static const List<String> _commentReactionPresets = ['✅', '👍', '👀'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _detailController = TextEditingController(text: widget.task.detail);
    _commentController = TextEditingController();
    _editCommentController = TextEditingController();
    _selectedStatus = widget.task.status;
    _selectedPriority = widget.task.priority;
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;
    _documentLinks = List<Map<String, String>>.from(
      widget.task.documentLinks.map((e) => Map<String, String>.from(e)),
    );

    // ?λ뜃由?嚥≪뮆諭?????쎄쾿嚥▲끉??筌??袁⑥삋嚥?揶쎛筌왖 ??낅즲嚥??귐딅뮞???곕떽?
    _timelineScrollController.addListener(() {
      if (_isInitialLoad && _timelineScrollController.hasClients) {
        // ?λ뜃由?嚥≪뮆諭?餓λ쵐肉???쎄쾿嚥▲끉??筌??袁⑥삋嚥?揶쎛??블???롢늺 筌??袁⑥쨮 ??롫즼??
        if (_timelineScrollController.offset > 10) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isInitialLoad && _timelineScrollController.hasClients) {
              _timelineScrollController.jumpTo(0.0);
            }
          });
        }
      }
    });

    // ??쇰뻻揶??蹂? 揶쏄퉮???귐딅뮞???源낆쨯
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskProvider = context.read<TaskProvider>();
      taskProvider.addCommentListener(widget.task.id, _onCommentCreated);
    });

    // ?λ뜃由??怨쀬뵠??嚥≪뮆諭?(??甕곕뜆肉?筌ｌ꼶???뤿연 setState 筌ㅼ뮇???
    _loadInitialData();
  }

  /// WebSocket??곗쨮 ?蹂? ??밴쉐 ??源????뤿뻿 ???紐꾪뀱
  void _onCommentCreated() {
    if (mounted) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    // ??쇰뻻揶??蹂? 揶쏄퉮???귐딅뮞????곸젫
    final taskProvider = context.read<TaskProvider>();
    taskProvider.removeCommentListener(widget.task.id, _onCommentCreated);

    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _detailController.dispose();
    _commentController.dispose();
    _editCommentController.dispose();
    _commentFocusNode.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  /// ?λ뜃由??怨쀬뵠??嚥≪뮆諭?(?源낅뮟 筌ㅼ뮇??? ??甕곕뜆肉?筌ｌ꼶??
  /// Resolve image URL for local/relative paths
  String _resolveImageUrl(String url) {
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
      // ?蹂????醫딅뼣?????癒?뱽 ??덈뻻??嚥≪뮆諭?
      final results = await Future.wait([
        _commentService.getCommentsByTaskId(widget.task.id),
        _loadAssignedMembersData(),
        _checklistService.getChecklistsByTaskId(widget.task.id),
      ]);

      final comments = results[0] as List<Comment>;
      final members = results[1] as List<User>?;
      final checklists = results[2] as List<Checklist>;

      // ??甕곕뜄彛?setState ?紐꾪뀱
      setState(() {
        _comments = comments;
        _assignedMembers = members;
        _checklists = checklists;
        _isLoadingComments = false;
      });

      // ???袁⑥뵬???袁⑹뵠????낅쑓??꾨뱜 (setState??_loadTimelineItems ????癒?퐣 ?紐꾪뀱)
      await _loadTimelineItems();
      await _loadMentionCandidates();

      // ?醫딅뼣??????筌뤴뫖以????쑴堉???筌???뽯뮞??肉??醫딅뼣?????癒?뵠 ??덈뼄筌???쇰뻻 嚥≪뮆諭?
      if ((members == null || members.isEmpty) &&
          widget.task.assignedMemberIds.isNotEmpty) {
        await _loadAssignedMembers();
      }
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  /// ?蹂? 嚥≪뮆諭?
  // ===== 체크리스트 핸들러 =====

  void _syncChecklistsIntoTimeline() {
    final current = _timelineItems;
    if (current == null || current.isEmpty) return;

    final byId = <String, Checklist>{for (final c in _checklists) c.id: c};

    setState(() {
      _timelineItems = current.map((item) {
        if (item.type != TimelineItemType.checklist) return item;
        final existing = item.data as Checklist;
        final updated = byId[existing.id];
        if (updated == null) return item;
        // keep original timeline date ordering; only refresh the checklist payload
        return TimelineItem(type: item.type, date: item.date, data: updated);
      }).toList(growable: false);
    });
  }

  Future<void> _createChecklist() async {
    try {
      final checklist = await _checklistService.createChecklist(taskId: widget.task.id);
      setState(() => _checklists.add(checklist));
      await _loadTimelineItems(scrollToBottom: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('체크리스트 생성 실패: $e')));
      }
    }
  }

  Future<void> _updateChecklistTitle(String checklistId, String newTitle) async {
    try {
      final updated = await _checklistService.updateChecklist(checklistId, title: newTitle);
      setState(() {
        final idx = _checklists.indexWhere((c) => c.id == checklistId);
        if (idx != -1) _checklists[idx] = updated;
      });
      await _loadTimelineItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('체크리스트 이름 변경 실패: $e')));
      }
    }
  }

  Future<void> _deleteChecklist(String checklistId) async {
    try {
      await _checklistService.deleteChecklist(checklistId);
      setState(() => _checklists.removeWhere((c) => c.id == checklistId));
      await _loadTimelineItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('체크리스트 삭제 실패: $e')));
      }
    }
  }

  Future<void> _addChecklistItem(String checklistId, String itemContent) async {
    try {
      final item = await _checklistService.addItem(checklistId: checklistId, content: itemContent);
      if (!mounted) return;
      setState(() {
        final idx = _checklists.indexWhere((c) => c.id == checklistId);
        if (idx != -1) {
          _checklists[idx] = _checklists[idx].copyWith(
            items: [..._checklists[idx].items, item],
          );
        }
      });
      _syncChecklistsIntoTimeline();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('항목 추가 실패: $e')));
      }
    }
  }

  Future<void> _toggleChecklistItem(String itemId, bool checked) async {
    try {
      final updated = await _checklistService.updateItem(itemId, isChecked: checked);
      _replaceChecklistItem(updated);
      _syncChecklistsIntoTimeline();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('항목 수정 실패: $e')));
      }
    }
  }

  Future<void> _deleteChecklistItem(String itemId) async {
    try {
      await _checklistService.deleteItem(itemId);
      for (var i = 0; i < _checklists.length; i++) {
        final newItems = _checklists[i].items.where((it) => it.id != itemId).toList();
        if (newItems.length != _checklists[i].items.length) {
          _checklists[i] = _checklists[i].copyWith(items: newItems);
          break;
        }
      }
      if (!mounted) return;
      setState(() {});
      _syncChecklistsIntoTimeline();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('항목 삭제 실패: $e')));
      }
    }
  }

  Future<void> _updateChecklistItem(String itemId, {String? assigneeId, DateTime? dueDate}) async {
    try {
      final updated = await _checklistService.updateItem(itemId, assigneeId: assigneeId, dueDate: dueDate);
      _replaceChecklistItem(updated);
      _syncChecklistsIntoTimeline();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('항목 업데이트 실패: $e')));
      }
    }
  }

  void _replaceChecklistItem(ChecklistItem updated) {
    setState(() {
      for (var i = 0; i < _checklists.length; i++) {
        final idx = _checklists[i].items.indexWhere((it) => it.id == updated.id);
        if (idx != -1) {
          final newItems = List<ChecklistItem>.from(_checklists[i].items);
          newItems[idx] = updated;
          _checklists[i] = _checklists[i].copyWith(items: newItems);
          break;
        }
      }
    });
  }

  Future<void> _loadComments({bool updateTimeline = true}) async {
    setState(() {
      _isLoadingComments = true;
    });
    try {
      final comments = await _commentService.getCommentsByTaskId(
        widget.task.id,
      );
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
      // ?꾨뗀李??嚥≪뮆諭??????袁⑥뵬???袁⑹뵠????낅쑓??꾨뱜 (????
      if (updateTimeline) {
        await _loadTimelineItems();
      }
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  /// ?醫딅뼣???????怨쀬뵠??嚥≪뮆諭?(獄쏆꼹?싧첎???됱벉)
  Future<List<User>?> _loadAssignedMembersData() async {
    final taskProvider = context.read<TaskProvider>();
    // 筌ㅼ뮇????뽯뮞???類ｋ궖 揶쎛?紐꾩궎疫?(taskProvider?癒?퐣 ?믪눘? 筌≪뼐?? ??곸몵筌?widget.task ????
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );

    // ?醫딅뼣?????癒?뵠 ??곸몵筌????귐딅뮞??獄쏆꼹??
    if (currentTask.assignedMemberIds.isEmpty) {
      return [];
    }

    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      final members = allUsers
          .where((user) => currentTask.assignedMemberIds.contains(user.id))
          .toList();

      // ?醫딅뼣??????ID揶쎛 ???筌?????癒? 筌≪뼚? 筌륁궢釉?野껋럩??????귐딅뮞??獄쏆꼹???? ??꾪?嚥≪뮄???곗뮆??
      if (members.isEmpty && currentTask.assignedMemberIds.isNotEmpty) {
        print(
          '[TaskDetailScreen] Assigned member IDs: ${currentTask.assignedMemberIds}, found users: ${members.length}',
        );
      }

      return members;
    } catch (e) {
      print('[TaskDetailScreen] ?醫딅뼣??????嚥≪뮆諭???쎈솭: $e');
      return [];
    }
  }

  Future<void> _loadMentionCandidates() async {
    try {
      final projectProvider = context.read<ProjectProvider>();
      Project? project = projectProvider.currentProject;
      if (project == null) {
        try {
          project = projectProvider.projects.firstWhere(
            (p) => p.id == widget.task.projectId,
          );
        } catch (_) {}
      }
      if (project == null) {
        if (mounted) {
          setState(() {
            _mentionCandidates = [];
            _filteredMentionUsers = [];
            _showMentionSuggestions = false;
            _mentionStartIndex = -1;
          });
        }
        return;
      }

      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      final projectMembers = allUsers
          .where((u) => project!.teamMemberIds.contains(u.id))
          .toList();
      final candidates = projectMembers
          .where((u) => u.id != currentUserId)
          .toList();

      if (!mounted) return;
      setState(() {
        _mentionCandidates = candidates;
        _projectMembers = projectMembers;
      });
    } catch (_) {
      // noop
    }
  }

  void _handleCommentChanged(String text) {
    final cursor = _commentController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      if (_showMentionSuggestions) {
        setState(() {
          _showMentionSuggestions = false;
          _filteredMentionUsers = [];
          _mentionStartIndex = -1;
          _selectedMentionIndex = -1;
        });
      }
      return;
    }

    final prefix = text.substring(0, cursor);
    final match = RegExp(r'@([A-Za-z0-9_]*)$').firstMatch(prefix);
    if (match == null) {
      if (_showMentionSuggestions) {
        setState(() {
          _showMentionSuggestions = false;
          _filteredMentionUsers = [];
          _mentionStartIndex = -1;
          _selectedMentionIndex = -1;
        });
      }
      return;
    }

    final query = (match.group(1) ?? '').toLowerCase();
    final filtered = _mentionCandidates
        .where((u) => u.username.toLowerCase().contains(query))
        .take(6)
        .toList();

    setState(() {
      _mentionStartIndex = match.start;
      _filteredMentionUsers = filtered;
      _showMentionSuggestions = filtered.isNotEmpty;
      _selectedMentionIndex = filtered.isNotEmpty ? 0 : -1;
    });
  }

  void _insertMention(User user) {
    if (_mentionStartIndex < 0) return;
    final text = _commentController.text;
    final cursor = _commentController.selection.baseOffset;
    if (cursor < _mentionStartIndex || cursor > text.length) return;

    final mention = '@${user.username} ';
    final updated = text.replaceRange(_mentionStartIndex, cursor, mention);
    final offset = _mentionStartIndex + mention.length;

    _commentController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: offset),
    );

    setState(() {
      _showMentionSuggestions = false;
      _filteredMentionUsers = [];
      _mentionStartIndex = -1;
      _selectedMentionIndex = -1;
    });

    _commentFocusNode.requestFocus();
  }

  /// 설명/댓글 공통 마크다운 스타일시트
  MarkdownStyleSheet _buildMarkdownStyleSheet(ColorScheme colorScheme) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurface.withValues(alpha: 0.85),
        height: 1.6,
      ),
      a: const TextStyle(
        fontSize: 14,
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: Color(0xFF2563EB),
      ),
      code: TextStyle(
        fontSize: 13,
        backgroundColor: colorScheme.surfaceContainerHighest,
        color: colorScheme.onSurface,
      ),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      del: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurface.withValues(alpha: 0.45),
        decoration: TextDecoration.lineThrough,
        height: 1.6,
      ),
    );
  }

  Widget _buildMentionRichText(
    Comment comment,
    String content,
    ColorScheme colorScheme,
  ) {
    // 실제 유저 목록에 있는 @mention만 링크로 변환해 파란색 표시
    final knownUsernames = _mentionCandidates
        .map((u) => u.username.toLowerCase())
        .toSet();
    final processed = _normalizeMarkdownNewlines(content).replaceAllMapped(
      RegExp(r'@([^\s@]+)'),
      (m) {
        final name = m.group(1)!;
        if (knownUsernames.contains(name.toLowerCase())) {
          return '[${m.group(0)}](#)';
        }
        return m.group(0)!;
      },
    );

    return Builder(
      builder: (context) {
        int cbIdx = 0;
        return Actions(
          actions: {
            CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
              onInvoke: (_) {
                Clipboard.setData(ClipboardData(text: comment.content));
                return null;
              },
            ),
          },
          child: SelectionArea(
            child: MarkdownBody(
              data: _addCheckboxStrikethrough(processed),
              selectable: false,
              softLineBreak: true,
              onTapLink: (text, href, title) {},
              checkboxBuilder: (bool value) {
                final idx = cbIdx++;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onCommentCheckboxTap(comment, idx, value),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4, top: 2),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: value,
                        onChanged: null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: colorScheme.primary),
                        activeColor: colorScheme.primary,
                      ),
                    ),
                  ),
                );
              },
              styleSheet: _buildMarkdownStyleSheet(colorScheme),
            ),
          ),
        );
      },
    );
  }

  /// ???袁⑥뵬???袁⑹뵠??嚥≪뮆諭?(??쎄쾿嚥??袁⑺뒄 ?醫?)
  Future<void> _loadTimelineItems({bool scrollToBottom = false}) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );

    // ?λ뜃由?嚥≪뮆諭???뽯퓠????쎄쾿嚥▲끉??筌??袁⑥쨮 ?醫???곷튊 ???嚥????館釉?쭪? ??놁벉
    double? savedScrollPosition;
    final bool hadClients = _timelineScrollController.hasClients;
    if (!scrollToBottom && hadClients && !_isInitialLoad) {
      savedScrollPosition = _timelineScrollController.offset;
    }

    final timelineItems = _buildTimelineItems(currentTask);

    if (mounted) {
      // setState???紐꾪뀱??띾┛ ?袁⑸퓠 ??쎄쾿嚥??袁⑺뒄??沃섎챶??????
      final maxScrollBefore = hadClients
          ? _timelineScrollController.position.maxScrollExtent
          : 0.0;

      setState(() {
        _timelineItems = timelineItems;
      });

      // setState ????쎄쾿嚥??袁⑺뒄 癰귣벊???癒?뮉 筌??袁⑥삋嚥???猷?
      if (scrollToBottom) {
        // ?꾨뗀李???곕떽? ??筌??袁⑥삋嚥???猷?- ????甕???뺣즲??뤿연 ?類ㅻ뼄??띿쓺
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isInitialLoad) {
            _scrollToBottom();
          }
        });
      } else if (savedScrollPosition != null && !_isInitialLoad) {
        // ???貫留??袁⑺뒄嚥?癰귣벊??(?λ뜃由?嚥≪뮆諭뜹첎? ?袁⑤빜 ???춸)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !_timelineScrollController.hasClients ||
              _isInitialLoad)
            return;
          final maxScrollAfter =
              _timelineScrollController.position.maxScrollExtent;
          final scrollDelta = maxScrollAfter - maxScrollBefore;
          final adjustedPosition = savedScrollPosition! + scrollDelta;

          _timelineScrollController.jumpTo(
            adjustedPosition.clamp(0.0, maxScrollAfter),
          );
        });
      } else if (_isInitialLoad) {
        // ?λ뜃由?嚥≪뮆諭?????쎄쾿嚥▲끉??筌??袁⑥쨮 ?醫? (?臾믩씜 燁삳?諭?筌욊쑴????
        // ????甕???뺣즲??뤿연 ?類ㅻ뼄??띿쓺 筌??袁⑥쨮 ?醫?
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_timelineScrollController.hasClients) return;
          // 揶쏅벡?ｆ에?筌??袁⑥쨮 ??猷?
          _timelineScrollController.jumpTo(0.0);
        });
        // ?곕떽? ??뺣즲: ??됱뵠?袁⑹뜍 ?袁⑥┷ ????쇰뻻 ?類ㅼ뵥
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted ||
              !_timelineScrollController.hasClients ||
              !_isInitialLoad)
            return;
          _timelineScrollController.jumpTo(0.0);
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted ||
              !_timelineScrollController.hasClients ||
              !_isInitialLoad)
            return;
          if (_timelineScrollController.offset > 0) {
            _timelineScrollController.jumpTo(0.0);
          }
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted ||
              !_timelineScrollController.hasClients ||
              !_isInitialLoad)
            return;
          if (_timelineScrollController.offset > 0) {
            _timelineScrollController.jumpTo(0.0);
          }
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted ||
              !_timelineScrollController.hasClients ||
              !_isInitialLoad)
            return;
          if (_timelineScrollController.offset > 0) {
            _timelineScrollController.jumpTo(0.0);
          }
          // ?λ뜃由?嚥≪뮆諭??袁⑥┷ ??뽯뻻 (筌뤴뫀諭???쎄쾿嚥???뺣즲揶쎛 ??멸텆 ??
          _isInitialLoad = false;
        });
      }
      // ?λ뜃由?嚥≪뮆諭뜹첎? ?袁⑤빍?????貫留??袁⑺뒄????용뮉 野껋럩????쎄쾿嚥??袁⑺뒄??癰궰野껋?釉?쭪? ??놁벉
    }
  }

  /// 筌??袁⑥삋嚥???쎄쾿嚥?(????甕???뺣즲??뤿연 ?類ㅻ뼄??띿쓺)
  void _scrollToBottom() {
    if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad)
      return;

    // 筌앸맩????뺣즲
    final maxScroll = _timelineScrollController.position.maxScrollExtent;
    _timelineScrollController.jumpTo(maxScroll);

    // ??꾩퍢??筌왖??????쇰뻻 ??뺣즲 (??됱뵠?袁⑹뜍???袁⑹읈???袁⑥┷????
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad)
        return;
      final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
      _timelineScrollController.animateTo(
        maxScrollAfter,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });

    // ?곕떽? 筌왖??????甕?????뺣즲 (???筌왖 嚥≪뮆逾??源놁몵嚥??誘れ뵠揶쎛 癰궰野껋럥留?????됱벉)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad)
        return;
      final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
      _timelineScrollController.jumpTo(maxScrollAfter);
    });
  }

  /// ?봔??뺤쓦野?筌??袁⑥삋嚥???쎄쾿嚥?(燁삳똻萸??쎈꽊 ?????
  void _scrollToBottomSmooth() {
    if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad)
      return;

    // 筌앸맩????뺣즲 (??됱뵠?袁⑹뜍????? ?袁⑥┷??野껋럩??
    final maxScroll = _timelineScrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      _timelineScrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }

    // ??됱뵠?袁⑹뜍 ?袁⑥┷ ????쇰뻻 ??뺣즲
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad)
        return;
      final maxScrollAfter = _timelineScrollController.position.maxScrollExtent;
      if (maxScrollAfter > 0) {
        _timelineScrollController.animateTo(
          maxScrollAfter,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });

    // ???筌왖 嚥≪뮆逾??源놁몵嚥??誘れ뵠揶쎛 癰궰野껋럥留?????됱몵沃샕嚥???甕?????뺣즲
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !_timelineScrollController.hasClients || _isInitialLoad)
        return;
      final maxScrollFinal = _timelineScrollController.position.maxScrollExtent;
      if (maxScrollFinal > 0) {
        _timelineScrollController.jumpTo(maxScrollFinal);
      }
    });
  }

  /// ???筌왖 ?醫뤾문 (?蹂???
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

  /// ???筌왖 ?醫뤾문 (?怨멸쉭 ??곸뒠??
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

  /// ?蹂? ?곕떽?
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty &&
        _selectedCommentImages.isEmpty)
      return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    final user = authProvider.currentUser!;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    try {
      // ???筌왖 ??낆쨮??
      List<String> imageUrls = [];
      if (_selectedCommentImages.isNotEmpty) {
        imageUrls = await _uploadService.uploadImagesFromXFiles(
          _selectedCommentImages,
        );
      }

      final comment = await _commentService.createComment(
        taskId: widget.task.id,
        userId: user.id,
        username: user.username,
        content: _commentController.text.trim(),
        imageUrls: imageUrls,
      );

      // Task???蹂? ID ?곕떽?
      final currentTask = taskProvider.tasks.firstWhere(
        (t) => t.id == widget.task.id,
        orElse: () => widget.task,
      );

      // commentIds揶쎛 null??욧탢????롢걵??????놁뵥 野껋럩??몴?????
      List<String> updatedCommentIds;
      try {
        updatedCommentIds = List<String>.from(currentTask.commentIds);
      } catch (e) {
        // commentIds揶쎛 null??욧탢????롢걵??????놁뵥 野껋럩?????귐딅뮞?紐껋쨮 ??뽰삂
        updatedCommentIds = [];
      }

      updatedCommentIds.add(comment.id);

      await taskProvider.updateTask(
        currentTask.copyWith(
          commentIds: updatedCommentIds,
          updatedAt: DateTime.now(),
        ),
      );

      // ??낆젾 ?袁⑤굡 ?λ뜃由??
      _commentController.clear();
      _selectedCommentImages.clear();
      _uploadedCommentImageUrls.clear();
      _showMentionSuggestions = false;
      _filteredMentionUsers = [];
      _mentionStartIndex = -1;

      // ???????낅쑓??꾨뱜: 筌앸맩??嚥≪뮇類??怨밴묶???蹂? ?곕떽? (燁삳똻萸??쎈꽊筌ｌ꼶???봔??뺤쓦野?
      setState(() {
        _comments.add(comment);
      });

      // ???袁⑥뵬?紐꾨퓠 ???蹂?筌??봔??뺤쓦野??곕떽?
      await _addCommentToTimeline(comment);

      // 獄쏄퉫???깆뒲??뽯퓠????뺤쒔 ??녿┛??(?????野껋?肉???怨밸샨 ??곸벉)
      _loadComments(updateTimeline: false).catchError((e) {
        // ??녿┛????쎈솭??猷???? 嚥≪뮇類???곕떽???뤿선 ??됱몵沃샕嚥??얜똻??
      });
    } catch (e) {
      if (mounted) {
        print('[ERROR] ?蹂? ?곕떽? ??쎈솭: $e');
        print('[ERROR] task_id: ${widget.task.id}');
        print('[ERROR] content: ${_commentController.text}');
        print('[ERROR] imageUrls: ${_selectedCommentImages.length}개');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 작성 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// ?蹂? ?紐꾩춿 ??뽰삂
  void _startEditComment(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _editCommentController.text = comment.content;
    });
  }

  /// ?蹂? ?紐꾩춿 ?띯뫁??
  void _cancelEditComment() {
    setState(() {
      _editingCommentId = null;
      _editCommentController.clear();
    });
  }

  /// ?蹂? ??낅쑓??꾨뱜
  Future<void> _updateComment(String commentId) async {
    if (_editCommentController.text.trim().isEmpty) {
      _cancelEditComment();
      return;
    }

    try {
      await _updateCommentContent(
        commentId,
        _editCommentController.text.trim(),
        clearEditingState: true,
      );
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

  Future<void> _updateCommentContent(
    String commentId,
    String newContent, {
    bool clearEditingState = false,
  }) async {
    final comment = _comments.firstWhere((c) => c.id == commentId);
    final updatedComment = comment.copyWith(
      content: newContent,
      updatedAt: DateTime.now(),
    );

    await _commentService.updateComment(updatedComment);

    if (!mounted) return;
    final index = _comments.indexWhere((c) => c.id == commentId);
    if (index != -1) {
      setState(() {
        _comments[index] = updatedComment;
        if (clearEditingState) {
          _editingCommentId = null;
          _editCommentController.clear();
        }
      });
    }

    await _loadTimelineItems();
  }

  Future<void> _onCommentCheckboxTap(
    Comment comment,
    int index,
    bool currentValue,
  ) async {
    try {
      final toggled = _toggleNthCheckbox(comment.content, index, !currentValue);
      final newContent = _addCheckboxStrikethrough(toggled);
      await _updateCommentContent(comment.id, newContent);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 체크박스 업데이트 중 오류가 발생했습니다: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  bool _hasCommentReacted(Comment comment, String emoji, String? userId) {
    if (userId == null) return false;
    return comment.reactions[emoji]?.contains(userId) ?? false;
  }

  int _commentReactionCount(Comment comment, String emoji) {
    return comment.reactions[emoji]?.length ?? 0;
  }

  void _setCommentReactions(
    String commentId,
    Map<String, List<String>> reactions,
  ) {
    setState(() {
      final index = _comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        _comments[index] = _comments[index].copyWith(reactions: reactions);
      }

      if (_timelineItems != null) {
        _timelineItems = _timelineItems!.map((item) {
          if (item.type == TimelineItemType.comment) {
            final itemComment = item.data as Comment;
            if (itemComment.id == commentId) {
              return TimelineItem(
                type: item.type,
                date: item.date,
                data: itemComment.copyWith(reactions: reactions),
              );
            }
          }
          return item;
        }).toList();
      }
    });
  }

  Future<void> _toggleCommentReaction(Comment comment, String emoji) async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;

    final original = <String, List<String>>{};
    comment.reactions.forEach((key, value) {
      original[key] = List<String>.from(value);
    });

    final optimistic = <String, List<String>>{};
    original.forEach((key, value) {
      optimistic[key] = List<String>.from(value);
    });
    final users = optimistic.putIfAbsent(emoji, () => []);
    if (users.contains(userId)) {
      users.remove(userId);
    } else {
      users.add(userId);
    }
    if (users.isEmpty) {
      optimistic.remove(emoji);
    }
    _setCommentReactions(comment.id, optimistic);

    try {
      final updated = await _commentService.toggleReaction(comment.id, emoji);
      if (!mounted) return;
      _setCommentReactions(comment.id, updated);
    } catch (e) {
      if (!mounted) return;
      _setCommentReactions(comment.id, original);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('댓글 리액션 업데이트 중 오류가 발생했습니다: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// ?蹂? ????
  Future<void> _deleteComment(String commentId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    final comment = _comments.firstWhere((c) => c.id == commentId);

    // 癰귣챷???蹂?筌?????揶쎛??
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

      // 댓글 ID는 백엔드에서 이미 동기화되므로 로컬 상태만 갱신
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      taskProvider.removeCommentId(widget.task.id, commentId);

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
    // context.read???????뤿연 ?븍뜇釉?酉釉??귐됲돱??獄쎻뫗?
    final taskProvider = context.read<TaskProvider>();
    final projectProvider = context.read<ProjectProvider>();
    final currentProject = projectProvider.currentProject;

    // 筌ㅼ뮇????뽯뮞???類ｋ궖 揶쎛?紐꾩궎疫?
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );

    // ?醫딅뼣??????ID揶쎛 癰궰野껋럥由??덈뮉筌왖 ?類ㅼ뵥??랁???녿┛??
    final currentAssignedIds = currentTask.assignedMemberIds;
    if (_lastAssignedMemberIds == null ||
        !listEquals(_lastAssignedMemberIds!, currentAssignedIds)) {
      _lastAssignedMemberIds = List.from(currentAssignedIds);
      // ??쇱벉 ?袁⑥쟿?袁⑸퓠???醫딅뼣??????筌뤴뫖以???쇰뻻 嚥≪뮆諭?
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAssignedMembers();
        }
      });
    }

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: GestureDetector(
          onTap: () {}, // ??? ??????源?紐? 筌띾맩釉??獄쏅떽臾??怨몃열 ???껓쭕?揶쏅Ŋ???롫즲嚥?
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
            child: GlassContainer(
              padding: const EdgeInsets.all(24.0),
              borderRadius: 20.0,
              blur: 25.0,
              gradientColors: [
                Colors.white.withValues(alpha: 0.9),
                Colors.white.withValues(alpha: 0.85),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ??삳쐭
                  Row(
                    children: [
                      Expanded(
                        child: _isTitleEditing
                            ? TextField(
                                controller: _titleController,
                                focusNode: _titleFocusNode,
                                autofocus: true,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) => _saveTitle(),
                                onEditingComplete: _saveTitle,
                              )
                            : MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _isTitleHovering = true),
                                onExit: (_) =>
                                    setState(() => _isTitleHovering = false),
                                child: GestureDetector(
                                  onTap: () {
                                    _titleController.text = currentTask.title;
                                    setState(() => _isTitleEditing = true);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                          (_) => _titleFocusNode.requestFocus(),
                                        );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isTitleHovering
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.08,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            currentTask.title,
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.55),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      // 餓λ쵐???獄쏄퀣?
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        borderRadius: 20.0,
                        blur: 20.0,
                        gradientColors: [
                          currentTask.priority.color.withValues(alpha: 0.3),
                          currentTask.priority.color.withValues(alpha: 0.2),
                        ],
                        borderColor: currentTask.priority.color.withValues(
                          alpha: 0.5,
                        ),
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
                      // ?怨밴묶 獄쏄퀣?
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        borderRadius: 20.0,
                        blur: 20.0,
                        gradientColors: [
                          currentTask.status.color.withValues(alpha: 0.3),
                          currentTask.status.color.withValues(alpha: 0.2),
                        ],
                        borderColor: currentTask.status.color.withValues(
                          alpha: 0.5,
                        ),
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
                      SizedBox(
                        width: 120,
                        child: InkWell(
                          onTap: () => setState(
                            () => _showHistoryLogs = !_showHistoryLogs,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _showHistoryLogs
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 15,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showHistoryLogs ? '활동로그 숨기기' : '활동로그 보기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // ??る┛ 甕곌쑵??
                      IconButton(
                        icon: Icon(Icons.close, color: colorScheme.onSurface),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 筌롫뗄???뚢뫂?쀯㎘?
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ??긱걹: ???袁⑥뵬??
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            controller: _timelineScrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ?怨멸쉭 ??곸뒠 (??湲?筌???
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
                                // ???袁⑥뵬???袁⑹뵠??뺣굶 (??볦퍢???類ｌ졊)
                                if (_timelineItems == null)
                                  const SizedBox.shrink()
                                else
                                  Column(
                                    children: _timelineItems!.map((item) {
                                      if (item.type ==
                                          TimelineItemType.history) {
                                        if (!_showHistoryLogs) {
                                          return const SizedBox.shrink();
                                        }
                                        final event = item.data as HistoryEvent;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
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
                                      } else if (item.type ==
                                          TimelineItemType.comment) {
                                        final comment = item.data as Comment;
                                        return TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOut,
                                          builder: (context, opacity, child) {
                                            return Opacity(
                                              opacity: opacity,
                                              child: Transform.translate(
                                                offset: Offset(
                                                  0,
                                                  20 * (1 - opacity),
                                                ),
                                                child:
                                                    _buildCommentTimelineItem(
                                                      context,
                                                      comment,
                                                      colorScheme,
                                                    ),
                                              ),
                                            );
                                          },
                                        );
                                      }
                                       else if (item.type ==
                                          TimelineItemType.checklist) {
                                        final checklist = item.data as Checklist;
                                        return Padding(
                                          key: ValueKey('timeline-checklist-${checklist.id}'),
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: ChecklistWidget(
                                            checklist: checklist,
                                            members: _projectMembers,
                                            onItemToggled: (itemId, checked) => _toggleChecklistItem(itemId, checked),
                                            onItemDeleted: (itemId) => _deleteChecklistItem(itemId),
                                            onItemAdded: (cId, text) => _addChecklistItem(cId, text),
                                            onChecklistDeleted: (cId) => _deleteChecklist(cId),
                                            onItemUpdated: (itemId, {assigneeId, dueDate}) => _updateChecklistItem(itemId, assigneeId: assigneeId, dueDate: dueDate),
                                            onTitleUpdated: (cId, newTitle) => _updateChecklistTitle(cId, newTitle),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    }).toList(),
                                  ),
                                // ?蹂? ??낆젾
                                const SizedBox(height: 16),
                                _buildCommentInput(context, colorScheme),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // ??삘뀲筌? ?????뺤뺍
                        SizedBox(
                          width: 280,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ?袁⑥쨮??븍뱜
                                if (currentProject != null)
                                  GlassContainer(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 16,
                                    ),
                                    borderRadius: 15.0,
                                    blur: 20.0,
                                    gradientColors: [
                                      Colors.white.withValues(alpha: 0.8),
                                      Colors.white.withValues(alpha: 0.7),
                                    ],
                                    shadowBlurRadius: 6,
                                    shadowOffset: const Offset(0, 2),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '프로젝트',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
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
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.8),
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: GlassContainer(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        borderRadius: 15.0,
                                        blur: 20.0,
                                        gradientColors: [
                                          Colors.white.withValues(alpha: 0.8),
                                          Colors.white.withValues(alpha: 0.7),
                                        ],
                                        shadowBlurRadius: 6,
                                        shadowOffset: const Offset(0, 2),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '상태',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            DropdownButton<TaskStatus>(
                                              value: _selectedStatus,
                                              isExpanded: true,
                                              items: TaskStatus.values.map((
                                                status,
                                              ) {
                                                return DropdownMenuItem(
                                                  value: status,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  status.color,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        status.displayName,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) async {
                                                if (value != null) {
                                                  setState(() {
                                                    _selectedStatus = value;
                                                  });
                                                  final authProvider = context
                                                      .read<AuthProvider>();
                                                  final currentUser =
                                                      authProvider.currentUser;
                                                  await taskProvider
                                                      .changeTaskStatus(
                                                        currentTask.id,
                                                        value,
                                                        userId: currentUser?.id,
                                                        username: currentUser
                                                            ?.username,
                                                      );
                                                  // ?怨밴묶 癰궰野??????袁⑥뵬????낅쑓??꾨뱜
                                                  await _loadTimelineItems();
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GlassContainer(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        borderRadius: 15.0,
                                        blur: 20.0,
                                        gradientColors: [
                                          Colors.white.withValues(alpha: 0.8),
                                          Colors.white.withValues(alpha: 0.7),
                                        ],
                                        shadowBlurRadius: 6,
                                        shadowOffset: const Offset(0, 2),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '우선순위',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            DropdownButton<TaskPriority>(
                                              value: _selectedPriority,
                                              isExpanded: true,
                                              items: TaskPriority.values.map((
                                                priority,
                                              ) {
                                                return DropdownMenuItem(
                                                  value: priority,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: priority
                                                                  .color,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                        child: Text(
                                                          priority.displayName,
                                                          style: TextStyle(
                                                            color:
                                                                priority.color,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
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
                                                  final authProvider = context
                                                      .read<AuthProvider>();
                                                  final currentUser =
                                                      authProvider.currentUser;
                                                  await taskProvider.updateTask(
                                                    currentTask.copyWith(
                                                      priority: value,
                                                      updatedAt: DateTime.now(),
                                                    ),
                                                    userId: currentUser?.id,
                                                    username:
                                                        currentUser?.username,
                                                  );
                                                  // 餓λ쵐???癰궰野??????袁⑥뵬????낅쑓??꾨뱜
                                                  await _loadTimelineItems();
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // 문서 링크
                                GlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  borderRadius: 15.0,
                                  blur: 20.0,
                                  gradientColors: [
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.7),
                                  ],
                                  shadowBlurRadius: 6,
                                  shadowOffset: const Offset(0, 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '문서 링크',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: Icon(
                                              Icons.add_link,
                                              size: 16,
                                              color: colorScheme.primary,
                                            ),
                                            onPressed: () =>
                                                _showAddDocumentLinkDialog(
                                                  context,
                                                  currentTask,
                                                  taskProvider,
                                                ),
                                            tooltip: '링크 추가',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (_documentLinks.isEmpty)
                                        Text(
                                          '링크가 없습니다',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        )
                                      else
                                        ...(_documentLinks.asMap().entries.map((
                                          entry,
                                        ) {
                                          final idx = entry.key;
                                          final link = entry.value;
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () async {
                                                    final url =
                                                        link['url'] ?? '';
                                                    if (url.isNotEmpty) {
                                                      await launchUrl(
                                                        Uri.parse(url),
                                                        mode: LaunchMode
                                                            .externalApplication,
                                                      );
                                                    }
                                                  },
                                                  child: Text(
                                                    (link['title']?.isNotEmpty ==
                                                                true
                                                            ? link['title']!
                                                            : link['url']) ??
                                                        '',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          colorScheme.primary,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.close,
                                                  size: 14,
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.4),
                                                ),
                                                onPressed: () async {
                                                  setState(() {
                                                    _documentLinks.removeAt(
                                                      idx,
                                                    );
                                                  });
                                                  final authProvider = context
                                                      .read<AuthProvider>();
                                                  await taskProvider.updateTask(
                                                    currentTask.copyWith(
                                                      documentLinks:
                                                          _documentLinks,
                                                      updatedAt: DateTime.now(),
                                                    ),
                                                    userId: authProvider
                                                        .currentUser
                                                        ?.id,
                                                    username: authProvider
                                                        .currentUser
                                                        ?.username,
                                                  );
                                                },
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 24,
                                                      minHeight: 24,
                                                    ),
                                              ),
                                            ],
                                          );
                                        })),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 疫꿸퀗而?(??뽰삂??~ ?ル굝利??
                                GlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 16,
                                  ),
                                  borderRadius: 15.0,
                                  blur: 20.0,
                                  gradientColors: [
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.7),
                                  ],
                                  shadowBlurRadius: 6,
                                  shadowOffset: const Offset(0, 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '옵션',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.settings,
                                            size: 16,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          // ??뽰삂??
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => _openDateRangePicker(
                                                context,
                                                currentTask,
                                                taskProvider,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: colorScheme.onSurface
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '시작일',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _startDate != null
                                                          ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                                                          : '날짜 미설정',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color:
                                                            _startDate != null
                                                            ? colorScheme
                                                                  .onSurface
                                                            : colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                        fontWeight:
                                                            FontWeight.w500,
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
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(width: 12),
                                          // ?ル굝利??
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => _openDateRangePicker(
                                                context,
                                                currentTask,
                                                taskProvider,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: colorScheme.onSurface
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '종료일',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _endDate != null
                                                          ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                                          : '날짜 미설정',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: _endDate != null
                                                            ? colorScheme
                                                                  .onSurface
                                                            : colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                        fontWeight:
                                                            FontWeight.w500,
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
                                // ?醫딅뼣??????
                                GlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 16,
                                  ),
                                  borderRadius: 15.0,
                                  blur: 20.0,
                                  gradientColors: [
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.7),
                                  ],
                                  shadowBlurRadius: 6,
                                  shadowOffset: const Offset(0, 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '담당자',
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
                                            onPressed: () =>
                                                _showAssignMemberDialog(
                                                  context,
                                                  currentTask,
                                                  taskProvider,
                                                  currentProject,
                                                ),
                                            tooltip: '담당자 추가',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (currentTask.assignedMemberIds.isEmpty)
                                        Text(
                                          '담당자가 지정되지 않았습니다',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        )
                                      else if (_assignedMembers == null)
                                        const SizedBox.shrink()
                                      else
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _assignedMembers!.map((
                                            member,
                                          ) {
                                            return RepaintBoundary(
                                              child: GlassContainer(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                borderRadius: 8.0,
                                                blur: 15.0,
                                                gradientColors: [
                                                  colorScheme.primary
                                                      .withValues(alpha: 0.2),
                                                  colorScheme.primary
                                                      .withValues(alpha: 0.1),
                                                ],
                                                borderColor: colorScheme.primary
                                                    .withValues(alpha: 0.3),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 8,
                                                      backgroundColor:
                                                          AvatarColor.getColorForUser(
                                                            member.id,
                                                          ),
                                                      child: Text(
                                                        AvatarColor.getInitial(
                                                          member.username,
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      member.username,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: colorScheme
                                                            .onSurface,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _removeAssignedMember(
                                                            context,
                                                            currentTask,
                                                            member.id,
                                                            taskProvider,
                                                          ),
                                                      child: Icon(
                                                        Icons.close,
                                                        size: 14,
                                                        color: colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
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
                                // ??밴쉐??
                                GlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 16,
                                  ),
                                  borderRadius: 15.0,
                                  blur: 20.0,
                                  gradientColors: [
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.7),
                                  ],
                                  shadowBlurRadius: 6,
                                  shadowOffset: const Offset(0, 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.7),
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
      ),
    );
  }

  Future<void> _saveTitle() async {
    final newTitle = _titleController.text.trim();
    if (!mounted) return;
    final taskProvider = context.read<TaskProvider>();
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    setState(() => _isTitleEditing = false);
    if (newTitle.isEmpty || newTitle == currentTask.title) return;
    await taskProvider.updateTask(
      currentTask.copyWith(title: newTitle, updatedAt: DateTime.now()),
    );
  }

  void _saveTask(BuildContext context, TaskProvider taskProvider) async {
    final currentTask = taskProvider.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );

    try {
      // ???筌왖 ??낆쨮??
      List<String> imageUrls = List<String>.from(currentTask.detailImageUrls);
      if (_selectedDetailImages.isNotEmpty) {
        final uploadedUrls = await _uploadService.uploadImagesFromXFiles(
          _selectedDetailImages,
        );
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

  /// ?醫딅뼣??????筌뤴뫖以?嚥≪뮆諭?
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
      final members = allUsers
          .where((user) => currentTask.assignedMemberIds.contains(user.id))
          .toList();
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

  /// ?????醫딅뼣 ??쇱뵠??곗쨮域?
  Future<void> _showAddDocumentLinkDialog(
    BuildContext context,
    Task currentTask,
    TaskProvider taskProvider,
  ) async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문서 링크 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '문서 제목',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.of(ctx).pop();
                setState(() {
                  _documentLinks.add({
                    'title': title.isNotEmpty ? title : url,
                    'url': url,
                  });
                });
                final authProvider = context.read<AuthProvider>();
                await taskProvider.updateTask(
                  currentTask.copyWith(
                    documentLinks: _documentLinks,
                    updatedAt: DateTime.now(),
                  ),
                  userId: authProvider.currentUser?.id,
                  username: authProvider.currentUser?.username,
                );
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    titleController.dispose();
    urlController.dispose();
  }

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
    final colorScheme = Theme.of(context).colorScheme;
    final authService = AuthService();

    // all-projects 모드에서 currentProject가 null이면 task의 projectId로 찾기
    Project? resolvedProject = currentProject;
    if (resolvedProject == null) {
      try {
        resolvedProject = context.read<ProjectProvider>().projects.firstWhere(
          (p) => p.id == task.projectId,
        );
      } catch (_) {}
    }

    try {
      final allUsers = await authService.getAllUsers();
      final projectMembers = allUsers.where((user) {
        if (resolvedProject != null) {
          return resolvedProject.teamMemberIds.contains(user.id);
        }
        return true; // 프로젝트를 찾을 수 없으면 모든 유저 표시
      }).toList();

      if (projectMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('담당자로 추가할 수 있는 팀원이 없습니다'),
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
                colorScheme.surface.withValues(alpha: 0.6),
                colorScheme.surface.withValues(alpha: 0.5),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '담당자 선택',
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
                          final isAssigned = task.assignedMemberIds.contains(
                            user.id,
                          );
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AvatarColor.getColorForUser(
                                user.id,
                              ),
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
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            trailing: isAssigned
                                ? Icon(
                                    Icons.check_circle,
                                    color: colorScheme.primary,
                                  )
                                : Icon(
                                    Icons.radio_button_unchecked,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                            onTap: () async {
                              // ??筌뤿굝彛??醫뤾문 揶쎛?館釉?袁⑥쨯 疫꿸퀣???醫딅뼣????筌?
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
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
                              }
                              Navigator.of(context).pop();
                              // ?醫딅뼣??????筌뤴뫖以???쇰뻻 嚥≪뮆諭?
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
                            '확인',
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
          content: Text('업데이트 오류: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  /// ?醫딅뼣????????볤탢
  Future<void> _removeAssignedMember(
    BuildContext context,
    Task task,
    String userId,
    TaskProvider taskProvider,
  ) async {
    final updatedMemberIds = task.assignedMemberIds
        .where((id) => id != userId)
        .toList();
    await taskProvider.updateTask(
      task.copyWith(
        assignedMemberIds: updatedMemberIds,
        updatedAt: DateTime.now(),
      ),
    );
    // ?醫딅뼣??????筌뤴뫖以???쇰뻻 嚥≪뮆諭?
    await _loadAssignedMembers();
  }

  /// ??밴쉐????已?揶쎛?紐꾩궎疫?
  String _getCreatorUsername(Task task) {
    // ??쇱젫嚥≪뮆????뽯뮞??肉?creatorId揶쎛 ??됰선?????筌? ?袁⑹삺????곸몵沃샕嚥?疫꿸퀡??첎?獄쏆꼹??
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.currentUser?.username ?? 'Unknown';
  }

  /// ???蹂??????袁⑥뵬?紐꾨퓠 ?봔??뺤쓦野??곕떽?
  Future<void> _addCommentToTimeline(Comment comment) async {
    // ?袁⑹삺 ???袁⑥뵬???袁⑹뵠??揶쎛?紐꾩궎疫?
    final currentItems = _timelineItems ?? [];

    // ???蹂? ?袁⑹뵠????밴쉐
    final newCommentItem = TimelineItem(
      type: TimelineItemType.comment,
      date: comment.createdAt,
      data: comment,
    );

    // 疫꿸퀣???袁⑹뵠??뽯퓠 ???蹂? ?곕떽?
    final updatedItems = List<TimelineItem>.from(currentItems);
    updatedItems.add(newCommentItem);

    // ??볦퍢??뽰몵嚥??類ｌ졊
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

      // ?봔??뺤쓦野?筌??袁⑥삋嚥???쎄쾿嚥?- ????甕???뺣즲??뤿연 ?類ㅻ뼄??띿쓺
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomSmooth();
      });

      // ?곕떽? ??뺣즲: ?醫딅빍筌롫뗄????袁⑥┷ ????쇰뻻 ??쎄쾿嚥?
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _scrollToBottomSmooth();
        }
      });
    }
  }

  /// ???袁⑥뵬???袁⑹뵠??뺣굶 ??슢諭?(??볦퍢???類ｌ졊)
  List<TimelineItem> _buildTimelineItems(Task task) {
    final List<TimelineItem> items = [];
    final colorScheme = Theme.of(context).colorScheme;

    // ??곷뭼 ??밴쉐 疫꿸퀡以?
    items.add(
      TimelineItem(
        type: TimelineItemType.history,
        date: task.createdAt,
        data: HistoryEvent(
          username: _getCreatorUsername(task),
          action: 'opened this',
          icon: Icons.circle_outlined,
        ),
      ),
    );

    // ?醫딅뼣 ??됰뮞?醫듼봺 (??쇱젫 ?醫딅뼣 疫꿸퀡以?????
    for (final history in task.assignmentHistory) {
      items.add(
        TimelineItem(
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
        ),
      );
    }

    // ?꾨뗀李???곕떽?
    for (final comment in _comments) {
      items.add(
        TimelineItem(
          type: TimelineItemType.comment,
          date: comment.createdAt,
          data: comment,
        ),
      );
    }

    // ?怨밴묶 癰궰野???됰뮞?醫듼봺 (??쇱젫 ?怨밴묶 癰궰野?疫꿸퀡以?????
    for (final history in task.statusHistory) {
      items.add(
        TimelineItem(
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
        ),
      );
    }

    // 餓λ쵐???癰궰野???됰뮞?醫듼봺
    for (final history in task.priorityHistory) {
      items.add(
        TimelineItem(
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
        ),
      );
    }

    // ??볦퍢??뽰몵嚥??類ｌ졊 (??살삋??野껉퍓???- 筌ㅼ뮇????????袁⑥삋????뽯뻻??
    // 筌뤴뫀諭??醫롮???UTC嚥?癰궰??묐릭?????袁⒲?筌△뫁???얜챷????욧퍙
    // 체크리스트 항목 추가
    for (final checklist in _checklists) {
      items.add(
        TimelineItem(
          type: TimelineItemType.checklist,
          date: checklist.createdAt,
          data: checklist,
        ),
      );
    }

    items.sort((a, b) {
      // Local ???袁⒲??UTC嚥?癰궰??
      final aUtc = a.date.isUtc ? a.date : a.date.toUtc();
      final bUtc = b.date.isUtc ? b.date : b.date.toUtc();

      // UTC嚥?癰궰??묐립 ??millisecondsSinceEpoch ??쑨??
      final aMs = aUtc.millisecondsSinceEpoch;
      final bMs = bUtc.millisecondsSinceEpoch;
      return aMs.compareTo(bMs);
    });

    return items;
  }

  /// ??됰뮞?醫듼봺 ?袁⑹뵠????슢諭?(GitHub ?????- ?臾? ?袁⑹뵠?꾩꼵????용뮞??
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
          // ?臾? ?袁⑹뵠??(?袁⑥뺍?? ????
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          // ??곸뒠
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
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                if (target != null) target,
                Text(
                  ' ${_formatRelativeDate(date)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ???袁⑥뵬???袁⑹뵠????슢諭?(?꾨뗀李?紐꾩뒠 - ?袁⑥뺍?? ??釉?
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
        // ?袁⑥뺍??
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
        // ??곸뒠
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
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatRelativeDate(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              if (content != null) ...[const SizedBox(height: 8), content],
            ],
          ),
        ),
      ],
    );
  }

  /// ?怨????醫롮? ?????(?? "5 days ago", "yesterday")
  /// ?怨? ?醫롮? ?????(??볥럢 ??볦퍢 疫꿸퀣?)
  String _formatRelativeDate(DateTime date) {
    // UTC ?醫롮???嚥≪뮇類???볦퍢(??볥럢 ??볦퍢)??곗쨮 癰궰??
    final localDate = date.isUtc ? date.toLocal() : date;
    final now = DateTime.now(); // ??? 嚥≪뮇類???볦퍢
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

  /// 단일 줄바꿈을 이중 줄바꿈으로 변환해 Markdown 개행 보존
  /// 단, 리스트 항목(-/*/+/숫자.) 앞 개행은 건드리지 않아 tight list 구조 유지
  /// (loose list가 되면 flutter_markdown이 - [ ] 를 체크박스로 인식 못 함)
  String _normalizeMarkdownNewlines(String text) {
    return text.replaceAllMapped(
      RegExp(r'\n(?!\n)(?![ \t]*(?:[-*+]|\d+\.)[ \t])'),
      (m) => '\n\n',
    );
  }

  /// 체크된 항목에 취소선 마크다운 추가
  String _addCheckboxStrikethrough(String markdown) {
    return markdown.replaceAllMapped(
      RegExp(r'^([ \t]*- \[x\] )(.+)$', multiLine: true, caseSensitive: false),
      (m) {
        final text = m.group(2)!;
        if (text.startsWith('~~') && text.endsWith('~~')) return m.group(0)!;
        return '${m.group(1)}~~$text~~';
      },
    );
  }

  /// 마크다운 텍스트에서 n번째 체크박스 토글
  String _toggleNthCheckbox(String markdown, int index, bool newValue) {
    final regex = RegExp(r'([ \t]*)- \[([ xX])\]', multiLine: true);
    int count = -1;
    return markdown.replaceAllMapped(regex, (match) {
      count++;
      if (count == index) {
        return '${match.group(1)!}- [${newValue ? 'x' : ' '}]';
      }
      return match.group(0)!;
    });
  }

  /// 체크박스 클릭 시 토글 후 저장
  Future<void> _onDetailCheckboxTap(
    Task task,
    int index,
    bool currentValue,
  ) async {
    final newDetail = _toggleNthCheckbox(task.detail, index, !currentValue);
    _detailController.text = newDetail;
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.updateTask(
      task.copyWith(detail: newDetail, updatedAt: DateTime.now()),
    );
    if (mounted) setState(() {});
  }

  /// ??살구 ???袁⑥뵬???袁⑹뵠??
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
        const SizedBox(width: 44), // ?袁⑥뺍?? ??덊돩 + 揶쏄쑨爰?
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 12.0,
            blur: 20.0,
            gradientColors: [
              Colors.white.withValues(alpha: 0.8),
              Colors.white.withValues(alpha: 0.7),
            ],
            child: Actions(
              actions: {
                CopySelectionTextIntent:
                    CallbackAction<CopySelectionTextIntent>(
                      onInvoke: (_) {
                        Clipboard.setData(ClipboardData(text: description));
                        return null;
                      },
                    ),
              },
              child: SelectionArea(
                child: MarkdownBody(
                  data: _normalizeMarkdownNewlines(description),
                  selectable: false,
                  softLineBreak: true,
                  styleSheet: _buildMarkdownStyleSheet(colorScheme),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ?怨멸쉭 ??곸뒠 ???袁⑥뵬???袁⑹뵠??
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
        const SizedBox(width: 44), // ?袁⑥뺍?? ??덊돩 + 揶쏄쑨爰?
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 12.0,
            blur: 20.0,
            gradientColors: [
              Colors.white.withValues(alpha: 0.8),
              Colors.white.withValues(alpha: 0.7),
            ],
            child: Stack(
              children: [
                // 筌롫뗄???뚢뫂?쀯㎘?(筌ㅼ뮇湲??獄쏄퀣??
                Padding(
                  padding: const EdgeInsets.only(
                    right: 36,
                  ), // ?怨좊툡 ?袁⑹뵠???⑤벀而??類ｋ궖
                  child: isEditing
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _detailController,
                              maxLines: null,
                              minLines: 8,
                              decoration: InputDecoration(
                                hintText: '상세 설명을 입력하세요..',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.5),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                            // ?醫뤾문?????筌왖 沃섎챶?곮퉪?용┛
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: _XFileImage(
                                              xfile:
                                                  _selectedDetailImages[index],
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
                                                  _selectedDetailImages
                                                      .removeAt(index);
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
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
                              tooltip: '???筌왖 ?곕떽?',
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.detail.isNotEmpty)
                              Builder(
                                builder: (context) {
                                  int cbIdx = 0;
                                  return Actions(
                                    actions: {
                                      CopySelectionTextIntent:
                                          CallbackAction<
                                            CopySelectionTextIntent
                                          >(
                                            onInvoke: (_) {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: task.detail,
                                                ),
                                              );
                                              return null;
                                            },
                                          ),
                                    },
                                    child: SelectionArea(
                                      child: MarkdownBody(
                                        data: _addCheckboxStrikethrough(
                                          _normalizeMarkdownNewlines(
                                            task.detail,
                                          ),
                                        ),
                                        selectable: false,
                                        softLineBreak: true,
                                        checkboxBuilder: (bool value) {
                                          final idx = cbIdx++;
                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _onDetailCheckboxTap(
                                              task,
                                              idx,
                                              value,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                                top: 2,
                                              ),
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: Checkbox(
                                                  value: value,
                                                  onChanged: null,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  side: BorderSide(
                                                    color: colorScheme.primary,
                                                  ),
                                                  activeColor:
                                                      colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        styleSheet: _buildMarkdownStyleSheet(
                                          colorScheme,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            else
                              Text(
                                '상세 설명이 없습니다. 수정 버튼을 클릭하여 추가하세요.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  height: 1.5,
                                ),
                              ),
                            // ???筌왖 ??뽯뻻
                            if (task.detailImageUrls.isNotEmpty) ...[
                              if (task.detail.isNotEmpty)
                                const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: () {
                                  final allImageUrls = task.detailImageUrls
                                      .map(_resolveImageUrl)
                                      .toList();
                                  return allImageUrls.map((imageUrl) {
                                    return GestureDetector(
                                      onTap: () => _showImageDialog(
                                        context,
                                        imageUrl,
                                        allImageUrls,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrl,
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  width: 200,
                                                  height: 200,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: colorScheme.onSurface
                                                        .withValues(alpha: 0.5),
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
                // ?怨좊툡 ?袁⑹뵠??(??삘뀲筌??怨룸뼊 ?⑥쥙??
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
                    tooltip: isEditing ? '수정 완료' : '편집',
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

  /// ?蹂? ???袁⑥뵬???袁⑹뵠??(?꾨뗀李???????- ?袁⑥뺍???? 獄쏅벡??
  Widget _buildCommentTimelineItem(
    BuildContext context,
    Comment comment,
    ColorScheme colorScheme,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final isMyComment = comment.userId == (currentUserId ?? '');

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
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    if (isMyComment) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.2),
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
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
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
                                Text('수정'),
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
                    Colors.white.withValues(alpha: 0.8),
                    Colors.white.withValues(alpha: 0.7),
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
                                hintText: '댓글을 수정하세요..',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.5),
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
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
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
                              _buildMentionRichText(
                                comment,
                                comment.content,
                                colorScheme,
                              ),
                            // ???筌왖 ??뽯뻻
                            if (comment.imageUrls.isNotEmpty) ...[
                              if (comment.content.isNotEmpty)
                                const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: () {
                                  final allImageUrls = comment.imageUrls
                                      .map(_resolveImageUrl)
                                      .toList();
                                  return allImageUrls.map((imageUrl) {
                                    return GestureDetector(
                                      onTap: () => _showImageDialog(
                                        context,
                                        imageUrl,
                                        allImageUrls,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrl,
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  width: 200,
                                                  height: 200,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: colorScheme.onSurface
                                                        .withValues(alpha: 0.5),
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
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _commentReactionPresets.map((emoji) {
                                  final count = _commentReactionCount(
                                    comment,
                                    emoji,
                                  );
                                  final isMine = _hasCommentReacted(
                                    comment,
                                    emoji,
                                    currentUserId,
                                  );
                                  return InkWell(
                                    onTap: () =>
                                        _toggleCommentReaction(comment, emoji),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMine
                                            ? colorScheme.primary.withValues(
                                                alpha: 0.18,
                                              )
                                            : colorScheme.surface.withValues(
                                                alpha: 0.6,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: isMine
                                              ? colorScheme.primary.withValues(
                                                  alpha: 0.5,
                                                )
                                              : colorScheme.outline.withValues(
                                                  alpha: 0.2,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        count > 0 ? '$emoji $count' : emoji,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
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
    );
  }

  /// ?蹂? ??낆젾 ?袁⑹졐
  Widget _buildCommentInput(BuildContext context, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AvatarColor.getColorForUser(
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id ??
                Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).currentUser?.username ??
                'U',
          ),
          child: Text(
            (Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).currentUser?.username ??
                    'U')[0]
                .toUpperCase(),
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
              // @mention 자동완성 드롭다운 (입력창 바로 위)
              if (_showMentionSuggestions && _filteredMentionUsers.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: colorScheme.brightness == Brightness.dark
                        ? colorScheme.surfaceContainerHighest
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filteredMentionUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredMentionUsers[index];
                      final isSelected = index == _selectedMentionIndex;
                      return InkWell(
                        onTap: () => _insertMention(user),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AvatarColor.getColorForUser(
                                  user.id,
                                ),
                                child: Text(
                                  AvatarColor.getInitial(user.username),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '@${user.username}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
                      .where(
                        (file) =>
                            file.path.isNotEmpty &&
                            _isSupportedImageFile(file.path),
                      )
                      .map((file) => XFile(file.path))
                      .toList();
                  if (dropped.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '지원하지 않는 이미지 형식입니다. (png, jpg, jpeg, gif, webp)',
                        ),
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
                    LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.keyV,
                    ): const _PasteIntent(),
                    LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.enter,
                    ): const _SubmitCommentIntent(),
                  },
                  child: Actions(
                    actions: {
                      _PasteIntent: CallbackAction<_PasteIntent>(
                        onInvoke: (intent) => _handlePaste(),
                      ),
                      _SubmitCommentIntent:
                          CallbackAction<_SubmitCommentIntent>(
                            onInvoke: (intent) {
                              if (_commentController.text.trim().isNotEmpty ||
                                  _selectedCommentImages.isNotEmpty) {
                                _addComment();
                              }
                              return null;
                            },
                          ),
                    },
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is! KeyDownEvent) return;
                        // 멘션 목록이 열려있을 때: 방향키/Enter로 선택
                        if (_showMentionSuggestions &&
                            _filteredMentionUsers.isNotEmpty) {
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            setState(() {
                              _selectedMentionIndex =
                                  (_selectedMentionIndex + 1) %
                                  _filteredMentionUsers.length;
                            });
                            return;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            setState(() {
                              _selectedMentionIndex =
                                  (_selectedMentionIndex -
                                      1 +
                                      _filteredMentionUsers.length) %
                                  _filteredMentionUsers.length;
                            });
                            return;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.enter) {
                            if (_selectedMentionIndex >= 0 &&
                                _selectedMentionIndex <
                                    _filteredMentionUsers.length) {
                              _insertMention(
                                _filteredMentionUsers[_selectedMentionIndex],
                              );
                            }
                            return;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.escape) {
                            setState(() {
                              _showMentionSuggestions = false;
                              _filteredMentionUsers = [];
                              _mentionStartIndex = -1;
                              _selectedMentionIndex = -1;
                            });
                            return;
                          }
                        }
                        // Shift+Enter 제외 Enter로 댓글 제출
                        if (event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed &&
                            _commentFocusNode.hasFocus) {
                          if (_commentController.text.trim().isNotEmpty ||
                              _selectedCommentImages.isNotEmpty) {
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
                                ? colorScheme.primary.withValues(alpha: 0.8)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: GlassContainer(
                          padding: const EdgeInsets.all(12),
                          borderRadius: 12.0,
                          blur: 20.0,
                          gradientColors: [
                            Colors.white.withValues(alpha: 0.8),
                            Colors.white.withValues(alpha: 0.7),
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
                                onChanged: _handleCommentChanged,
                                decoration: InputDecoration(
                                  hintText:
                                      '댓글을 입력하세요... (Enter로 제출, Shift+Enter로 줄바꿈, 이미지는 드래그 또는 Ctrl+V로 붙여넣기)',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface,
                                  height: 1.5,
                                ),
                                // onSubmitted ??볤탢 - KeyboardListener揶쎛 Enter ??? 筌ｌ꼶???
                              ),
                              // ?醫뤾문?????筌왖 沃섎챶?곮퉪?용┛
                              if (_selectedCommentImages.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedCommentImages.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: _XFileImage(
                                                xfile:
                                                    _selectedCommentImages[index],
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
                                                    _selectedCommentImages
                                                        .removeAt(index);
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.image,
                                          color: colorScheme.primary,
                                        ),
                                        onPressed: _pickCommentImages,
                                        tooltip: '이미지 추가',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.checklist,
                                          color: colorScheme.primary,
                                        ),
                                        onPressed: _createChecklist,
                                        tooltip: '체크리스트 추가',
                                      ),
                                    ],
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

  /// ?븐늿肉?節딅┛ 筌ｌ꼶??
  Future<void> _handlePaste() async {
    if (!_commentFocusNode.hasFocus) return;

    try {
      // ?믪눘? ??용뮞?????계퉪?諭??類ㅼ뵥
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null &&
          clipboardData.text != null &&
          clipboardData.text!.isNotEmpty) {
        // ??용뮞?硫? ??됱몵筌?TextField???븐늿肉?節딅┛
        final text = clipboardData.text!;
        final currentText = _commentController.text;
        final selection = _commentController.selection;

        if (selection.isValid) {
          // ?醫뤾문????용뮞?硫? ??됱몵筌??대Ŋ猿? ??곸몵筌??뚣끉苑??袁⑺뒄????뚯뿯
          final newText = currentText.replaceRange(
            selection.start,
            selection.end,
            text,
          );
          _commentController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
              offset: selection.start + text.length,
            ),
          );
        } else {
          // ?뚣끉苑뚦첎? ??곸몵筌???밸퓠 ?곕떽?
          _commentController.text = currentText + text;
          _commentController.selection = TextSelection.collapsed(
            offset: _commentController.text.length,
          );
        }
        return;
      }

      // ??용뮞?硫? ??곸몵筌????筌왖 ?類ㅼ뵥 (Windows?癒?퐣筌?
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
                    name:
                        'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
                  );
                  setState(() {
                    _selectedCommentImages.add(xfile);
                  });
                  return;
                }
              } else if (type == 'paths') {
                final List<dynamic>? rawPaths =
                    result['data'] as List<dynamic>?;
                if (rawPaths != null && rawPaths.isNotEmpty) {
                  final dropped = rawPaths
                      .whereType<String>()
                      .where((path) => _isSupportedImageFile(path))
                      .map((path) => XFile(path))
                      .toList();

                  if (dropped.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '지원하지 않는 이미지 형식은 붙여넣을 수 없습니다. (png, jpg, jpeg, gif, webp)',
                        ),
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
                name:
                    'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
              );
              setState(() {
                _selectedCommentImages.add(xfile);
              });
              return;
            }
          }
        } catch (e) {
          // ???삸??筌?쑬瑗????얘탢????쎈솭??野껋럩???얜똻??
        }
      }

      // ??용뮞?紐껊즲 ???筌왖????곸몵筌??袁ⓓ℡칰猿딅즲 ??? ??놁벉 (?癒?쑎 筌롫뗄?놅쭪? ??볤탢)
    } catch (e) {
      // ?癒?쑎 獄쏆뮇源????얜똻??
    }
  }

  /// ?醫롮? ?????
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
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }

  /// ???筌왖 ?類? ??쇱뵠??곗쨮域???뽯뻻
  void _showImageDialog(
    BuildContext context,
    String imageUrl,
    List<String> allImageUrls,
  ) {
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
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 60,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Stack(
              children: [
                // ???筌왖 ?됯퀣堉?
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.8),
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
                              color: Colors.white.withValues(alpha: 0.7),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 64,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '이미지를 불러올 수 없습니다',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
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
                // ??る┛ 甕곌쑵??
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
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ),
                // ???????筌왖揶쎛 ??됱뱽 野껋럩????삵돩野껊슣???甕곌쑵??
                if (resolvedAllImageUrls.length > 1) ...[
                  // ??곸읈 ???筌왖
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
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.6,
                            ),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                    ),
                  // ??쇱벉 ???筌왖
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
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.6,
                            ),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                    ),
                  // ???筌왖 ?紐껊쑔????뽯뻻
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
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

/// XFile 沃섎챶?곮퉪?용┛ (???怨쀫뮞?????⑤벏?? Image.file ??筌?
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
            child: Icon(
              Icons.broken_image,
              size: width * 0.5,
              color: Colors.grey,
            ),
          );
        }
        return SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
