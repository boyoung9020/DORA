import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/auth_provider.dart';
import '../models/workspace.dart';
import '../utils/avatar_color.dart';

/// 워크스페이스 설정 다이얼로그
class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  /// 다이얼로그 카드 형태로 표시
  static Future<void> showAsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: const SizedBox(width: 480, child: WorkspaceSettingsScreen()),
      ),
    );
  }

  @override
  State<WorkspaceSettingsScreen> createState() => _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceProvider>().loadWorkspaces();
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('클립보드에 복사되었습니다'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _regenerateToken(WorkspaceProvider wsProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대 코드 재발급'),
        content: const Text('기존 초대 링크는 더 이상 사용할 수 없게 됩니다. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('재발급')),
        ],
      ),
    );
    if (confirm != true) return;
    await wsProvider.regenerateInviteToken();
  }

  Future<void> _deleteWorkspace(WorkspaceProvider wsProvider, String wsName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('워크스페이스 삭제'),
        content: Text(
          '"$wsName" 워크스페이스를 삭제하면 모든 멤버가 즉시 퇴장되며 복구할 수 없습니다. 정말 삭제하시겠습니까?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final success = await wsProvider.deleteWorkspace();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '워크스페이스가 삭제되었습니다' : wsProvider.errorMessage ?? '삭제에 실패했습니다')),
      );
    }
  }

  Future<void> _removeMember(WorkspaceProvider wsProvider, WorkspaceMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 강퇴'),
        content: Text('${member.username}님을 워크스페이스에서 강퇴하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('강퇴'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await wsProvider.removeMember(member.userId);
  }

  @override
  Widget build(BuildContext context) {
    final wsProvider = context.watch<WorkspaceProvider>();
    final authProvider = context.watch<AuthProvider>();
    final ws = wsProvider.currentWorkspace;
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = authProvider.currentUser?.id ?? '';
    final isOwner = ws?.ownerId == currentUserId || authProvider.isAdmin;

    if (ws == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('워크스페이스를 선택하세요')),
      );
    }

    final inviteLink = wsProvider.buildInviteLink(ws.inviteToken);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          color: colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8), // 워크스페이스 = 네모
                ),
                child: Center(
                  child: Text(
                    ws.name.isNotEmpty ? ws.name[0].toUpperCase() : 'W',
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ws.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                    if (ws.description != null)
                      Text(ws.description!,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteWorkspace(wsProvider, ws.name),
                  tooltip: '워크스페이스 삭제',
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '닫기',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 스크롤 가능 본문
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 초대 링크 섹션
                _sectionLabel(context, colorScheme, '초대 링크'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          inviteLink,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: '링크 복사',
                        onPressed: () => _copyToClipboard(inviteLink),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(ws.inviteToken),
                      icon: const Icon(Icons.key, size: 16),
                      label: const Text('코드만 복사'),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _regenerateToken(wsProvider),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('코드 재발급'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // 멤버 섹션
                _sectionLabel(context, colorScheme, '멤버 (${wsProvider.currentMembers.length}명)'),
                const SizedBox(height: 4),
                if (wsProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ...wsProvider.currentMembers.map((member) {

                    final avatarColor = AvatarColor.getColorForUser(member.username);
                    final isMe = member.userId == currentUserId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: avatarColor,
                        child: Text(
                          member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(member.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('나', style: TextStyle(fontSize: 10, color: colorScheme.primary)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        member.isOwner ? '오너' : '멤버',
                        style: TextStyle(
                            color: member.isOwner ? colorScheme.primary : colorScheme.onSurfaceVariant),
                      ),
                      trailing: isOwner && !isMe && !member.isOwner
                          ? IconButton(
                              icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20),
                              tooltip: '강퇴',
                              onPressed: () => _removeMember(wsProvider, member),
                            )
                          : null,
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, ColorScheme colorScheme, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}
