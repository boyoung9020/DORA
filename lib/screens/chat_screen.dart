import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../utils/api_client.dart';
import '../utils/file_download.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/upload_service.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';

/// 채팅 화면 - Mattermost 스타일
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _editMessageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<User> _allUsers = [];
  bool _isLoadingUsers = true;
  User? _selectedUser;
  bool _isConnecting = false;
  List<_PendingAttachment> _pendingAttachments = [];
  bool _isUploading = false;
  String? _workspaceScopeId;

  // @mention 자동완성 상태
  List<User> _filteredMentionUsers = [];
  bool _showMentionSuggestions = false;
  int _mentionStartIndex = -1;
  int _selectedMentionIndex = -1;
  bool _workspaceScopeInitialized = false;
  String? _editingMessageId;
  bool _isUpdatingMessage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final workspaceId = context.read<WorkspaceProvider>().currentWorkspaceId;
      context.read<ChatProvider>().loadRooms(workspaceId: workspaceId);
    });
    _messageScrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspaceId = Provider.of<WorkspaceProvider>(
      context,
    ).currentWorkspaceId;
    if (!_workspaceScopeInitialized || _workspaceScopeId != workspaceId) {
      _workspaceScopeInitialized = true;
      _workspaceScopeId = workspaceId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ChatProvider>().loadRooms(workspaceId: workspaceId);
          _loadAllUsers(workspaceIdOverride: workspaceId);
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _editMessageController.dispose();
    _messageScrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers({String? workspaceIdOverride}) async {
    if (mounted) {
      setState(() => _isLoadingUsers = true);
    }

    try {
      final authService = AuthService();
      final wsProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final currentUserId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser?.id;
      String? workspaceId =
          workspaceIdOverride ?? wsProvider.currentWorkspaceId;

      // 워크스페이스가 아직 로드되지 않았다면 먼저 로드 시도
      if (workspaceId == null &&
          wsProvider.workspaces.isEmpty &&
          !wsProvider.isLoading) {
        await wsProvider.loadWorkspaces();
        workspaceId = wsProvider.currentWorkspaceId;
      }

      // 현재 워크스페이스가 없으면 새 대화 대상도 없음
      if (workspaceId == null) {
        if (mounted) {
          setState(() {
            _allUsers = [];
            _isLoadingUsers = false;
          });
        }
        return;
      }

      final users = await authService.getUsersByWorkspace(workspaceId);
      if (mounted) {
        setState(() {
          _allUsers = users.where((u) => u.id != currentUserId).toList();
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allUsers = [];
          _isLoadingUsers = false;
        });
      }
    }
  }

  Future<void> _selectUser(User user) async {
    setState(() {
      _selectedUser = user;
      _isConnecting = true;
      _editingMessageId = null;
      _editMessageController.clear();
    });

    final chatProvider = context.read<ChatProvider>();
    final workspaceId = context.read<WorkspaceProvider>().currentWorkspaceId;
    final room = await chatProvider.getOrCreateDMRoom(
      user.id,
      workspaceId: workspaceId,
    );
    if (room != null) {
      chatProvider.selectRoom(room.id);
      _scrollToBottom();
    }

    setState(() => _isConnecting = false);
  }

  void _onScroll() {
    if (_messageScrollController.position.pixels <=
        _messageScrollController.position.minScrollExtent + 50) {
      final chatProvider = context.read<ChatProvider>();
      final roomId = chatProvider.currentRoomId;
      if (roomId != null &&
          chatProvider.hasMoreMessages(roomId) &&
          !chatProvider.isLoadingMessages) {
        chatProvider.loadMessages(roomId, loadMore: true);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageScrollController.hasClients) {
        _messageScrollController.animateTo(
          _messageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    setState(() {
      _pendingAttachments.add(
        _PendingAttachment(
          bytes: bytes,
          fileName: pickedFile.name,
          isImage: true,
        ),
      );
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final ext = file.extension?.toLowerCase() ?? '';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

    setState(() {
      _pendingAttachments.add(
        _PendingAttachment(
          bytes: file.bytes!,
          fileName: file.name,
          isImage: isImage,
        ),
      );
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  void _handleMentionChanged(String text) {
    final cursor = _messageController.selection.baseOffset;
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
    final filtered = _allUsers
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
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    if (cursor < _mentionStartIndex || cursor > text.length) return;
    final mention = '@${user.username} ';
    final updated = text.replaceRange(_mentionStartIndex, cursor, mention);
    final offset = _mentionStartIndex + mention.length;
    _messageController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: offset),
    );
    setState(() {
      _showMentionSuggestions = false;
      _filteredMentionUsers = [];
      _mentionStartIndex = -1;
      _selectedMentionIndex = -1;
    });
    _messageFocusNode.requestFocus();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    _messageController.clear();

    List<String> imageUrls = [];
    List<String> fileUrls = [];

    if (_pendingAttachments.isNotEmpty) {
      setState(() => _isUploading = true);
      try {
        final uploadService = UploadService();
        for (final att in _pendingAttachments) {
          if (att.isImage) {
            final url = await uploadService.uploadImageBytes(
              att.bytes,
              att.fileName,
            );
            imageUrls.add(url);
          } else {
            final data = await uploadService.uploadFileBytes(
              att.bytes,
              att.fileName,
            );
            final url = data['url'] as String;
            final originalName =
                data['original_name'] as String? ?? att.fileName;
            final size = data['size'] as int? ?? 0;
            fileUrls.add('$originalName|$url|$size');
          }
        }
      } catch (e) {
        setState(() => _isUploading = false);
        return;
      }
      setState(() {
        _pendingAttachments = [];
        _isUploading = false;
      });
    }

    final success = await context.read<ChatProvider>().sendMessage(
      text.isEmpty ? ' ' : text,
      imageUrls: imageUrls.isEmpty ? null : imageUrls,
      fileUrls: fileUrls.isEmpty ? null : fileUrls,
    );
    if (success) {
      _scrollToBottom();
    }
    _messageFocusNode.requestFocus();
  }

  bool _canEditMessage(ChatMessage message, String? currentUserId) {
    final hasTextContent =
        message.content.trim().isNotEmpty && message.content.trim() != ' ';
    return message.senderId == currentUserId &&
        hasTextContent &&
        message.imageUrls.isEmpty &&
        message.fileUrls.isEmpty;
  }

  bool _isMessageEdited(ChatMessage message) {
    if (message.updatedAt == null) return false;
    return message.updatedAt!.difference(message.createdAt).inSeconds.abs() >=
        1;
  }

  void _startEditMessage(ChatMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _editMessageController.text = message.content;
    });
  }

  void _cancelEditMessage() {
    setState(() {
      _editingMessageId = null;
      _editMessageController.clear();
      _isUpdatingMessage = false;
    });
  }

  Future<void> _saveEditedMessage(ChatMessage message) async {
    final content = _editMessageController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isUpdatingMessage = true;
    });

    final success = await context.read<ChatProvider>().updateMessage(
      message.roomId,
      message.id,
      content,
    );

    if (!mounted) return;
    if (success) {
      setState(() {
        _editingMessageId = null;
        _editMessageController.clear();
        _isUpdatingMessage = false;
      });
      return;
    }

    setState(() {
      _isUpdatingMessage = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('메시지 수정에 실패했습니다.')));
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 2) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${date.month}/${date.day}';
  }

  String _formatMessageTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$period $h12:$minute';
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  ChatRoom? _getRoomForUser(String userId) {
    final chatProvider = context.read<ChatProvider>();
    for (final room in chatProvider.rooms) {
      if (room.type == ChatRoomType.dm && room.memberIds.contains(userId)) {
        return room;
      }
    }
    return null;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  _FileInfo _parseFileUrl(String fileUrl) {
    final parts = fileUrl.split('|');
    if (parts.length >= 3) {
      return _FileInfo(
        originalName: parts[0],
        url: parts[1],
        size: int.tryParse(parts[2]) ?? 0,
      );
    }
    final name = fileUrl.split('/').last;
    return _FileInfo(originalName: name, url: fileUrl, size: 0);
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'py':
      case 'js':
      case 'ts':
      case 'dart':
      case 'html':
      case 'css':
      case 'json':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('다운로드 실패: HTTP ${response.statusCode}')),
          );
        }
        return;
      }

      final saved = await saveFileFromBytes(response.bodyBytes, fileName);
      if (!mounted) return;
      if (saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$fileName 저장 완료')));
      }
      // 사용자가 저장을 취소한 경우 메시지를 노출하지 않음
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('다운로드 실패: $e')));
      }
    }
  }

  void _showImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black87,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        final fileName = imageUrl.split('/').last;
                        _downloadFile(imageUrl, fileName);
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: _buildUserListPanel(context, colorScheme, isDarkMode),
          ),
          Container(
            width: 1,
            color: isDarkMode
                ? colorScheme.onSurface.withValues(alpha: 0.1)
                : const Color(0xFFE7D3BF),
          ),
          Expanded(child: _buildMessagePanel(context, colorScheme, isDarkMode)),
        ],
      ),
    );
  }

  /// 새 대화 시작 다이얼로그 표시
  void _showNewDMDialog(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    // 이미 대화 중인 사용자 ID 수집
    final usersWithMessages = <String>{};
    for (final user in _allUsers) {
      final room = _getRoomForUser(user.id);
      if (room?.lastMessageAt != null) {
        usersWithMessages.add(user.id);
      }
    }
    // 대화 기록이 없는 사용자만 필터링
    final availableUsers = _allUsers
        .where((u) => !usersWithMessages.contains(u.id))
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
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
                    '새 대화 시작',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: availableUsers.isEmpty
                        ? Center(
                            child: Text(
                              '대화를 시작할 유저가 없습니다',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: availableUsers.length,
                            itemBuilder: (context, index) {
                              final user = availableUsers[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(dialogContext).pop();
                                      _selectUser(user);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          _buildUserAvatar(user, radius: 16),
                                          const SizedBox(width: 10),
                                          Text(
                                            user.username,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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

  Widget _buildUserListPanel(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    context.watch<ChatProvider>();
    final hasWorkspace =
        context.watch<WorkspaceProvider>().currentWorkspaceId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4),
          child: Row(
            children: [
              Text(
                '개인 메시지',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasWorkspace
                      ? () => _showNewDMDialog(context, colorScheme, isDarkMode)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasWorkspace
                      ? () => _showGroupChatDialog(context)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.group_add_outlined,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : Builder(
                  builder: (context) {
                    // 메시지를 주고받은 사용자만 표시 (대화 기록이 있는 사용자)
                    final usersWithMessages = _allUsers.where((user) {
                      final room = _getRoomForUser(user.id);
                      return room?.lastMessageAt != null;
                    }).toList();
                    // 현재 선택된 사용자가 목록에 없으면 추가 (새 대화 시작 직후)
                    if (_selectedUser != null &&
                        !usersWithMessages.any(
                          (u) => u.id == _selectedUser!.id,
                        )) {
                      usersWithMessages.insert(0, _selectedUser!);
                    }
                    // 최근 채팅한 사용자 순으로 정렬
                    usersWithMessages.sort((a, b) {
                      final roomA = _getRoomForUser(a.id);
                      final roomB = _getRoomForUser(b.id);
                      final timeA = roomA?.lastMessageAt;
                      final timeB = roomB?.lastMessageAt;
                      if (timeA == null && timeB == null) return 0;
                      if (timeA == null) return 1;
                      if (timeB == null) return -1;
                      return timeB.compareTo(timeA); // 최신순
                    });
                    if (usersWithMessages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '대화 기록이 없습니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _showNewDMDialog(
                                context,
                                colorScheme,
                                isDarkMode,
                              ),
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              label: Text(
                                '새 대화 시작',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: usersWithMessages.length,
                      itemBuilder: (context, index) {
                        final user = usersWithMessages[index];
                        final isSelected = _selectedUser?.id == user.id;
                        final room = _getRoomForUser(user.id);
                        final unreadCount = room?.unreadCount ?? 0;
                        return _buildUserTile(
                          user,
                          isSelected,
                          room,
                          unreadCount,
                          colorScheme,
                          isDarkMode,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserTile(
    User user,
    bool isSelected,
    ChatRoom? room,
    int unreadCount,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectUser(user),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDarkMode
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : const Color(0xFFFFF3E6))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildUserAvatar(user, radius: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (room?.lastMessageContent != null &&
                          room!.lastMessageContent!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          room.lastMessageContent!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (room?.lastMessageAt != null)
                      Text(
                        _formatRelativeTime(room!.lastMessageAt!),
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagePanel(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    final chatProvider = context.watch<ChatProvider>();

    if (_selectedUser == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              '대화할 사용자를 선택하세요',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    if (_isConnecting) return const Center(child: CircularProgressIndicator());

    final messages = chatProvider.currentMessages;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return Column(
      children: [
        _buildChatHeader(_selectedUser!, colorScheme, isDarkMode),
        const SizedBox(height: 8),
        Expanded(
          child: messages.isEmpty
              ? _buildEmptyProfile(_selectedUser!, colorScheme, isDarkMode)
              : _buildMessageList(
                  messages,
                  currentUserId,
                  colorScheme,
                  isDarkMode,
                ),
        ),
        const SizedBox(height: 8),
        _buildInputBar(_selectedUser!, colorScheme, isDarkMode),
      ],
    );
  }

  Widget _buildChatHeader(User user, ColorScheme colorScheme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? colorScheme.surface.withValues(alpha: 0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? colorScheme.onSurface.withValues(alpha: 0.1)
              : const Color(0xFFE7D3BF),
        ),
      ),
      child: Row(
        children: [
          _buildUserAvatar(user, radius: 16),
          const SizedBox(width: 10),
          Text(
            user.username,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProfile(
    User user,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserAvatar(user, radius: 48),
          const SizedBox(height: 20),
          Text(
            user.username,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${user.username}님과의 개인 메시지가 시작되었습니다.\n여기의 메시지와 파일은 다른 사용자에게 보이지 않습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 메시지 리스트 - Mattermost 스타일
  Widget _buildMessageList(
    List<ChatMessage> messages,
    String? currentUserId,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    return ListView.builder(
      controller: _messageScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        Widget? dateDivider;
        if (index == 0 ||
            _getDateLabel(messages[index].createdAt) !=
                _getDateLabel(messages[index - 1].createdAt)) {
          dateDivider = Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: isDarkMode
                        ? colorScheme.onSurface.withValues(alpha: 0.1)
                        : const Color(0xFFE7D3BF),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _getDateLabel(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: isDarkMode
                        ? colorScheme.onSurface.withValues(alpha: 0.1)
                        : const Color(0xFFE7D3BF),
                  ),
                ),
              ],
            ),
          );
        }

        final showHeader =
            index == 0 ||
            messages[index - 1].senderId != message.senderId ||
            message.createdAt
                    .difference(messages[index - 1].createdAt)
                    .inMinutes >
                5;

        return Column(
          children: [
            if (dateDivider != null) dateDivider,
            _buildMessageItem(
              message,
              showHeader,
              currentUserId,
              colorScheme,
              isDarkMode,
            ),
          ],
        );
      },
    );
  }

  /// 메시지 아이템 - Mattermost 스타일 (좌측 정렬, 배경 없음)
  Widget _buildMessageItem(
    ChatMessage message,
    bool showHeader,
    String? currentUserId,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    final hasContent =
        message.content.trim().isNotEmpty && message.content.trim() != ' ';
    final canEdit = _canEditMessage(message, currentUserId);
    final isEditing = _editingMessageId == message.id;
    final isEdited = _isMessageEdited(message);

    return GestureDetector(
      onLongPress: canEdit && !isEditing
          ? () => _startEditMessage(message)
          : null,
      child: Padding(
        padding: EdgeInsets.only(top: showHeader ? 12 : 1, bottom: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _buildSenderAvatar(
                  message.senderId,
                  message.senderUsername,
                  radius: 18,
                ),
              )
            else
              const SizedBox(width: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Text(
                            message.senderUsername,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatMessageTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          if (isEdited) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(수정됨)',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (canEdit)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 16,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              tooltip: '메시지 옵션',
                              onSelected: (value) {
                                if (value == 'edit') _startEditMessage(message);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 16),
                                      SizedBox(width: 8),
                                      Text('수정'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (isEditing)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE7D3BF),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _editMessageController,
                            autofocus: true,
                            maxLines: null,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
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
                                onPressed: _isUpdatingMessage
                                    ? null
                                    : _cancelEditMessage,
                                child: const Text('취소'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _isUpdatingMessage
                                    ? null
                                    : () => _saveEditedMessage(message),
                                child: _isUpdatingMessage
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('저장'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (hasContent)
                      MarkdownBody(
                        data: message.content.replaceAllMapped(
                          RegExp(r'@([^\s@]+)'),
                          (m) {
                            final name = m.group(1)!;
                            final known = _allUsers.any(
                              (u) =>
                                  u.username.toLowerCase() ==
                                  name.toLowerCase(),
                            );
                            return known ? '[${m.group(0)}](#)' : m.group(0)!;
                          },
                        ),
                        selectable: true,
                        onTapLink: (text, href, title) {},
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                            height: 1.5,
                          ),
                          a: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          code: TextStyle(
                            fontSize: 13,
                            color: colorScheme.primary,
                            backgroundColor: isDarkMode
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFFFF5EA),
                            fontFamily: 'monospace',
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFFFF5EA),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE7D3BF),
                            ),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                                width: 3,
                              ),
                            ),
                          ),
                          h1: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          h2: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          h3: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          strong: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          em: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurface,
                          ),
                          listBullet: TextStyle(color: colorScheme.onSurface),
                        ),
                      ),
                    if (message.imageUrls.isNotEmpty) ...[
                      if (hasContent) const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: message.imageUrls.map((url) {
                          final imageUrl = url.startsWith('/')
                              ? '${ApiClient.baseUrl}$url'
                              : url;
                          return GestureDetector(
                            onTap: () => _showImageViewer(context, imageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                  maxHeight: 250,
                                ),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 100,
                                    height: 100,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.05,
                                    ),
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (message.fileUrls.isNotEmpty) ...[
                      if (hasContent || message.imageUrls.isNotEmpty)
                        const SizedBox(height: 6),
                      ...message.fileUrls.map((fileUrl) {
                        final info = _parseFileUrl(fileUrl);
                        final downloadUrl = info.url.startsWith('/')
                            ? '${ApiClient.baseUrl}${info.url}'
                            : info.url;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: InkWell(
                            onTap: () {
                              _downloadFile(downloadUrl, info.originalName);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : const Color(0xFFE7D3BF),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getFileIcon(info.originalName),
                                    size: 28,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          info.originalName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (info.size > 0)
                                          Text(
                                            _formatFileSize(info.size),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.download,
                                    size: 18,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(
    String senderId,
    String senderUsername, {
    double radius = 18,
  }) {
    User? user;
    if (_selectedUser?.id == senderId) {
      user = _selectedUser;
    } else {
      try {
        user = _allUsers.firstWhere((u) => u.id == senderId);
      } catch (_) {}
    }
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser?.id == senderId) user = currentUser;
    if (user != null) return _buildUserAvatar(user, radius: radius);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AvatarColor.getColorForUser(senderId),
      child: Text(
        AvatarColor.getInitial(senderUsername),
        style: TextStyle(
          fontSize: radius * 0.7,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserAvatar(User user, {double radius = 16}) {
    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      final url = user.profileImageUrl!.startsWith('/')
          ? '${ApiClient.baseUrl}${user.profileImageUrl!}'
          : user.profileImageUrl!;
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AvatarColor.getColorForUser(user.id),
      child: Text(
        AvatarColor.getInitial(user.username),
        style: TextStyle(
          fontSize: radius * 0.7,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInputBar(User user, ColorScheme colorScheme, bool isDarkMode) {
    return Column(
      children: [
        if (_pendingAttachments.isNotEmpty)
          Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingAttachments.length,
              itemBuilder: (context, index) {
                final att = _pendingAttachments[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      if (att.isImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            att.bytes,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 120,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE7D3BF),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getFileIcon(att.fileName),
                                size: 24,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  att.fileName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeAttachment(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
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
        if (_isUploading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  '파일 업로드 중...',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        // @mention 자동완성 드롭다운 (입력창 바로 위)
        if (_showMentionSuggestions && _filteredMentionUsers.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: isDarkMode
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
                final u = _filteredMentionUsers[index];
                final isSelected = index == _selectedMentionIndex;
                return InkWell(
                  onTap: () => _insertMention(u),
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
                          backgroundColor: AvatarColor.getColorForUser(u.id),
                          child: Text(
                            AvatarColor.getInitial(u.username),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '@${u.username}',
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? colorScheme.surface.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode
                  ? colorScheme.onSurface.withValues(alpha: 0.1)
                  : const Color(0xFFE7D3BF),
            ),
          ),
          child: Row(
            children: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'image') _pickImage();
                  if (value == 'file') _pickFile();
                },
                offset: const Offset(0, -100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'image',
                    child: Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('이미지'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'file',
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('파일'),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 22,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    // mention 활성 시 키보드 네비게이션
                    if (_showMentionSuggestions &&
                        _filteredMentionUsers.isNotEmpty) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        setState(() {
                          _selectedMentionIndex =
                              (_selectedMentionIndex + 1) %
                              _filteredMentionUsers.length;
                        });
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        setState(() {
                          _selectedMentionIndex =
                              (_selectedMentionIndex -
                                  1 +
                                  _filteredMentionUsers.length) %
                              _filteredMentionUsers.length;
                        });
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.enter) {
                        if (_selectedMentionIndex >= 0 &&
                            _selectedMentionIndex <
                                _filteredMentionUsers.length) {
                          _insertMention(
                            _filteredMentionUsers[_selectedMentionIndex],
                          );
                        }
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.escape) {
                        setState(() {
                          _showMentionSuggestions = false;
                          _filteredMentionUsers = [];
                          _mentionStartIndex = -1;
                          _selectedMentionIndex = -1;
                        });
                        return KeyEventResult.handled;
                      }
                    }
                    // 기본 Enter: 메시지 전송
                    if (event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      _sendMessage();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    onChanged: _handleMentionChanged,
                    decoration: InputDecoration(
                      hintText: '${user.username}님에게 메시지 보내기',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.send,
                      size: 18,
                      color: Colors.white,
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

  void _showGroupChatDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
            child: GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 20.0,
              blur: 25.0,
              gradientColors: [
                colorScheme.surface.withValues(alpha: 0.6),
                colorScheme.surface.withValues(alpha: 0.5),
              ],
              child: _GroupChatDialogContent(
                users: _allUsers,
                onGroupCreated: (name, memberIds) async {
                  Navigator.of(dialogContext).pop();
                  final chatProvider = context.read<ChatProvider>();
                  final workspaceId = context
                      .read<WorkspaceProvider>()
                      .currentWorkspaceId;
                  final room = await chatProvider.createGroupRoom(
                    name: name,
                    memberIds: memberIds,
                    workspaceId: workspaceId,
                  );
                  if (room != null) chatProvider.selectRoom(room.id);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupChatDialogContent extends StatefulWidget {
  final List<User> users;
  final Future<void> Function(String name, List<String> memberIds)
  onGroupCreated;
  const _GroupChatDialogContent({
    required this.users,
    required this.onGroupCreated,
  });
  @override
  State<_GroupChatDialogContent> createState() =>
      _GroupChatDialogContentState();
}

class _GroupChatDialogContentState extends State<_GroupChatDialogContent> {
  final TextEditingController _groupNameController = TextEditingController();
  final Set<String> _selectedMemberIds = {};

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '그룹 채팅 만들기',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GlassTextField(
          controller: _groupNameController,
          labelText: '그룹 이름',
          prefixIcon: const Icon(Icons.group),
        ),
        const SizedBox(height: 12),
        Text(
          '멤버 선택',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: widget.users.length,
            itemBuilder: (context, index) {
              final user = widget.users[index];
              final isSelected = _selectedMemberIds.contains(user.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(
                      () => isSelected
                          ? _selectedMemberIds.remove(user.id)
                          : _selectedMemberIds.add(user.id),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkMode
                                  ? colorScheme.primary.withValues(alpha: 0.15)
                                  : const Color(0xFFFFF3E6))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AvatarColor.getColorForUser(
                              user.id,
                            ),
                            child: Text(
                              AvatarColor.getInitial(user.username),
                              style: const TextStyle(
                                fontSize: 12,
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
                                Text(
                                  user.username,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            text: '그룹 채팅 만들기 (${_selectedMemberIds.length}명)',
            onPressed:
                _selectedMemberIds.isEmpty ||
                    _groupNameController.text.trim().isEmpty
                ? null
                : () => widget.onGroupCreated(
                    _groupNameController.text.trim(),
                    _selectedMemberIds.toList(),
                  ),
            gradientColors: [
              colorScheme.primary.withValues(alpha: 0.5),
              colorScheme.primary.withValues(alpha: 0.4),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingAttachment {
  final Uint8List bytes;
  final String fileName;
  final bool isImage;
  const _PendingAttachment({
    required this.bytes,
    required this.fileName,
    required this.isImage,
  });
}

class _FileInfo {
  final String originalName;
  final String url;
  final int size;
  const _FileInfo({
    required this.originalName,
    required this.url,
    required this.size,
  });
}
