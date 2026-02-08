import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../utils/file_download.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
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
  final ScrollController _messageScrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<User> _allUsers = [];
  bool _isLoadingUsers = true;
  User? _selectedUser;
  bool _isConnecting = false;
  List<_PendingAttachment> _pendingAttachments = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllUsers();
      context.read<ChatProvider>().loadRooms();
    });
    _messageScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageScrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers() async {
    try {
      final authService = AuthService();
      final users = await authService.getAllUsers();
      final currentUserId =
          Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
      setState(() {
        _allUsers = users.where((u) => u.id != currentUserId).toList();
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _selectUser(User user) async {
    setState(() {
      _selectedUser = user;
      _isConnecting = true;
    });

    final chatProvider = context.read<ChatProvider>();
    final room = await chatProvider.getOrCreateDMRoom(user.id);
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
      _pendingAttachments.add(_PendingAttachment(
        bytes: bytes,
        fileName: pickedFile.name,
        isImage: true,
      ));
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
      _pendingAttachments.add(_PendingAttachment(
        bytes: file.bytes!,
        fileName: file.name,
        isImage: isImage,
      ));
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
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
            final url = await uploadService.uploadImageBytes(att.bytes, att.fileName);
            imageUrls.add(url);
          } else {
            final data = await uploadService.uploadFileBytes(att.bytes, att.fileName);
            final url = data['url'] as String;
            final originalName = data['original_name'] as String? ?? att.fileName;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName 저장 완료')),
        );
      }
      // 사용자 취소 시에는 메시지 없음
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 실패: $e')),
        );
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
                        child: const Icon(Icons.download, color: Colors.white, size: 20),
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
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
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
                : const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: _buildMessagePanel(context, colorScheme, isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListPanel(BuildContext context, ColorScheme colorScheme, bool isDarkMode) {
    context.watch<ChatProvider>();

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
                  onTap: () => _showGroupChatDialog(context),
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
              : Builder(builder: (context) {
                  // 최근 채팅한 사람이 위로 오도록 정렬
                  final sorted = List<User>.from(_allUsers);
                  sorted.sort((a, b) {
                    final roomA = _getRoomForUser(a.id);
                    final roomB = _getRoomForUser(b.id);
                    final timeA = roomA?.lastMessageAt;
                    final timeB = roomB?.lastMessageAt;
                    if (timeA == null && timeB == null) return 0;
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    return timeB.compareTo(timeA); // 최신이 위로
                  });
                  return ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final user = sorted[index];
                      final isSelected = _selectedUser?.id == user.id;
                      final room = _getRoomForUser(user.id);
                      final unreadCount = room?.unreadCount ?? 0;
                      return _buildUserTile(user, isSelected, room, unreadCount, colorScheme, isDarkMode);
                    },
                  );
                }),
        ),
      ],
    );
  }

  Widget _buildUserTile(User user, bool isSelected, ChatRoom? room, int unreadCount, ColorScheme colorScheme, bool isDarkMode) {
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
                  ? (isDarkMode ? colorScheme.primary.withValues(alpha: 0.15) : const Color(0xFFEEF2FF))
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
                          fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (room?.lastMessageContent != null && room!.lastMessageContent!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          room.lastMessageContent!,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
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
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                      ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(10)),
                        child: Text('$unreadCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildMessagePanel(BuildContext context, ColorScheme colorScheme, bool isDarkMode) {
    final chatProvider = context.watch<ChatProvider>();

    if (_selectedUser == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_outlined, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text('대화할 사용자를 선택하세요', style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withValues(alpha: 0.4))),
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
              : _buildMessageList(messages, currentUserId, colorScheme, isDarkMode),
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
        color: isDarkMode ? colorScheme.surface.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? colorScheme.onSurface.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildUserAvatar(user, radius: 16),
          const SizedBox(width: 10),
          Text(user.username, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildEmptyProfile(User user, ColorScheme colorScheme, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserAvatar(user, radius: 48),
          const SizedBox(height: 20),
          Text(user.username, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
            '${user.username}님과의 개인 메시지가 시작되었습니다.\n여기에 게시된 메시지나 파일들은 외부에서 볼 수 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.5), height: 1.6),
          ),
        ],
      ),
    );
  }

  /// 메시지 리스트 - Mattermost 스타일
  Widget _buildMessageList(List<ChatMessage> messages, String? currentUserId, ColorScheme colorScheme, bool isDarkMode) {
    return ListView.builder(
      controller: _messageScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        Widget? dateDivider;
        if (index == 0 || _getDateLabel(messages[index].createdAt) != _getDateLabel(messages[index - 1].createdAt)) {
          dateDivider = Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: isDarkMode ? colorScheme.onSurface.withValues(alpha: 0.1) : const Color(0xFFE2E8F0))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(_getDateLabel(message.createdAt), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                ),
                Expanded(child: Divider(color: isDarkMode ? colorScheme.onSurface.withValues(alpha: 0.1) : const Color(0xFFE2E8F0))),
              ],
            ),
          );
        }

        final showHeader = index == 0 ||
            messages[index - 1].senderId != message.senderId ||
            message.createdAt.difference(messages[index - 1].createdAt).inMinutes > 5;

        return Column(
          children: [
            if (dateDivider != null) dateDivider,
            _buildMessageItem(message, showHeader, colorScheme, isDarkMode),
          ],
        );
      },
    );
  }

  /// 메시지 아이템 - Mattermost 스타일 (왼쪽 정렬, 배경 없음)
  Widget _buildMessageItem(ChatMessage message, bool showHeader, ColorScheme colorScheme, bool isDarkMode) {
    final hasContent = message.content.trim().isNotEmpty && message.content.trim() != ' ';

    return Padding(
      padding: EdgeInsets.only(top: showHeader ? 12 : 1, bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _buildSenderAvatar(message.senderId, message.senderUsername, radius: 18),
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
                        Text(message.senderUsername, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                        const SizedBox(width: 8),
                        Text(_formatMessageTime(message.createdAt), style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.35))),
                      ],
                    ),
                  ),
                // 마크다운 텍스트
                if (hasContent)
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(fontSize: 14, color: colorScheme.onSurface, height: 1.5),
                      code: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                        backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(left: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5), width: 3)),
                      ),
                      h1: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                      h2: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                      h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                      strong: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                      em: TextStyle(fontStyle: FontStyle.italic, color: colorScheme.onSurface),
                      listBullet: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                // 이미지
                if (message.imageUrls.isNotEmpty) ...[
                  if (hasContent) const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.imageUrls.map((url) {
                      final imageUrl = url.startsWith('/') ? 'http://localhost:8000$url' : url;
                      return GestureDetector(
                        onTap: () => _showImageViewer(context, imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 250),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 100,
                                height: 100,
                                color: colorScheme.onSurface.withValues(alpha: 0.05),
                                child: const Icon(Icons.broken_image, size: 32),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // 파일
                if (message.fileUrls.isNotEmpty) ...[
                  if (hasContent || message.imageUrls.isNotEmpty) const SizedBox(height: 6),
                  ...message.fileUrls.map((fileUrl) {
                    final info = _parseFileUrl(fileUrl);
                    final downloadUrl = info.url.startsWith('/') ? 'http://localhost:8000${info.url}' : info.url;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: () {
                          _downloadFile(downloadUrl, info.originalName);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getFileIcon(info.originalName), size: 28, color: colorScheme.primary),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(info.originalName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    if (info.size > 0) Text(_formatFileSize(info.size), style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.download, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderAvatar(String senderId, String senderUsername, {double radius = 18}) {
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
      child: Text(AvatarColor.getInitial(senderUsername), style: TextStyle(fontSize: radius * 0.7, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildUserAvatar(User user, {double radius = 16}) {
    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      final url = user.profileImageUrl!.startsWith('/') ? 'http://localhost:8000${user.profileImageUrl!}' : user.profileImageUrl!;
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url), onBackgroundImageError: (_, __) {});
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AvatarColor.getColorForUser(user.id),
      child: Text(AvatarColor.getInitial(user.username), style: TextStyle(fontSize: radius * 0.7, color: Colors.white, fontWeight: FontWeight.bold)),
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
                        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(att.bytes, width: 80, height: 80, fit: BoxFit.cover))
                      else
                        Container(
                          width: 120,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getFileIcon(att.fileName), size: 24, color: colorScheme.primary),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(att.fileName, style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.6)), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => _removeAttachment(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
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
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('파일 업로드 중...', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode ? colorScheme.surface.withValues(alpha: 0.6) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDarkMode ? colorScheme.onSurface.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'image') _pickImage();
                  if (value == 'file') _pickFile();
                },
                offset: const Offset(0, -100),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.image_outlined, size: 18, color: colorScheme.primary), const SizedBox(width: 8), const Text('이미지')])),
                  PopupMenuItem(value: 'file', child: Row(children: [Icon(Icons.attach_file, size: 18, color: colorScheme.primary), const SizedBox(width: 8), const Text('파일')])),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.add_circle_outline, size: 22, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                      _sendMessage();
                    }
                  },
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    decoration: InputDecoration(
                      hintText: '${user.username}님에게 글쓰기',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
                    ),
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
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
                    decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.send, size: 18, color: Colors.white),
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                  final room = await chatProvider.createGroupRoom(name: name, memberIds: memberIds);
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
  final Future<void> Function(String name, List<String> memberIds) onGroupCreated;
  const _GroupChatDialogContent({required this.users, required this.onGroupCreated});
  @override
  State<_GroupChatDialogContent> createState() => _GroupChatDialogContentState();
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
        Text('그룹 채팅 만들기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
        const SizedBox(height: 16),
        GlassTextField(controller: _groupNameController, labelText: '그룹 이름', prefixIcon: const Icon(Icons.group)),
        const SizedBox(height: 12),
        Text('멤버 선택', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withValues(alpha: 0.7))),
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
                    onTap: () => setState(() => isSelected ? _selectedMemberIds.remove(user.id) : _selectedMemberIds.add(user.id)),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? (isDarkMode ? colorScheme.primary.withValues(alpha: 0.15) : const Color(0xFFEEF2FF)) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 16, backgroundColor: AvatarColor.getColorForUser(user.id), child: Text(AvatarColor.getInitial(user.username), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.username, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                                Text(user.email, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                              ],
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_circle, size: 20, color: colorScheme.primary),
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
            onPressed: _selectedMemberIds.isEmpty || _groupNameController.text.trim().isEmpty
                ? null
                : () => widget.onGroupCreated(_groupNameController.text.trim(), _selectedMemberIds.toList()),
            gradientColors: [colorScheme.primary.withValues(alpha: 0.5), colorScheme.primary.withValues(alpha: 0.4)],
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
  const _PendingAttachment({required this.bytes, required this.fileName, required this.isImage});
}

class _FileInfo {
  final String originalName;
  final String url;
  final int size;
  const _FileInfo({required this.originalName, required this.url, required this.size});
}
