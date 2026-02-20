import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_container.dart';

/// 워크스페이스 선택/생성 화면
/// 로그인 직후 표시 (전체화면), 또는 레일 "+" 버튼에서 다이얼로그로 표시
class WorkspaceSelectScreen extends StatefulWidget {
  const WorkspaceSelectScreen({super.key});

  /// 레일 "+" 버튼에서 다이얼로그 카드 형태로 표시
  static Future<void> showAsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: const SizedBox(width: 460, child: _WorkspaceSelectDialogContent()),
      ),
    );
  }

  @override
  State<WorkspaceSelectScreen> createState() => _WorkspaceSelectScreenState();
}

class _WorkspaceSelectScreenState extends State<WorkspaceSelectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceProvider>().loadWorkspaces();
    });
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 워크스페이스 만들기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '이름 *', hintText: '예) 우리 팀'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: '설명 (선택)', hintText: '워크스페이스 설명'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await context.read<WorkspaceProvider>().createWorkspace(
                    name, descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
              if (ok && mounted) _enterApp();
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    final tokenCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대 코드로 참여하기'),
        content: TextField(
          controller: tokenCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '초대 코드 또는 링크',
            hintText: '초대 코드 붙여넣기',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              var token = tokenCtrl.text.trim();
              // 링크에서 토큰 추출 (/join/<token> 형태)
              final joinMatch = RegExp(r'/join/([^/?#]+)').firstMatch(token);
              if (joinMatch != null) token = joinMatch.group(1)!;
              if (token.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await context.read<WorkspaceProvider>().joinByToken(token);
              if (ok && mounted) {
                _enterApp();
              } else if (mounted) {
                final err = context.read<WorkspaceProvider>().errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err ?? '참여에 실패했습니다'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('참여'),
          ),
        ],
      ),
    );
  }

  void _enterApp() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    // AuthWrapper의 Consumer가 wsProvider.currentWorkspace를 감지해 자동으로 MainLayout 표시
  }

  @override
  Widget build(BuildContext context) {
    final wsProvider = context.watch<WorkspaceProvider>();
    final authProvider = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 헤더
                  Text(
                    '안녕하세요, ${authProvider.currentUser?.username ?? ''}님!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '참여할 워크스페이스를 선택하거나 새로 만드세요',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // 내 워크스페이스 목록
                  if (wsProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (wsProvider.workspaces.isNotEmpty) ...[
                    Text(
                      '내 워크스페이스',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...wsProvider.workspaces.map((ws) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassContainer(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  ws.name.isNotEmpty ? ws.name[0].toUpperCase() : 'W',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(ws.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('멤버 ${ws.memberCount}명'),
                              trailing: FilledButton(
                                onPressed: () {
                                  wsProvider.selectWorkspace(ws);
                                  _enterApp();
                                },
                                child: const Text('입장'),
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],

                  // 액션 버튼들
                  FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('새 워크스페이스 만들기'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showJoinDialog,
                    icon: const Icon(Icons.link),
                    label: const Text('초대 코드로 참여하기'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 로그아웃
                  TextButton(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    child: Text(
                      '다른 계정으로 로그인',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
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
}

// ─────────────────────────────────────────────────────────────────
// 다이얼로그 전용 콘텐츠 (레일 "+" 버튼에서 호출)
// ─────────────────────────────────────────────────────────────────
class _WorkspaceSelectDialogContent extends StatefulWidget {
  const _WorkspaceSelectDialogContent();

  @override
  State<_WorkspaceSelectDialogContent> createState() => _WorkspaceSelectDialogContentState();
}

class _WorkspaceSelectDialogContentState extends State<_WorkspaceSelectDialogContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceProvider>().loadWorkspaces();
    });
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 워크스페이스 만들기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '이름 *', hintText: '예) 우리 팀'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: '설명 (선택)', hintText: '워크스페이스 설명'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await context.read<WorkspaceProvider>().createWorkspace(
                    name, descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
              if (ok && mounted) Navigator.of(context).pop(); // 다이얼로그 닫기
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    final tokenCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대 코드로 참여하기'),
        content: TextField(
          controller: tokenCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '초대 코드 또는 링크',
            hintText: '초대 코드 붙여넣기',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              var token = tokenCtrl.text.trim();
              final joinMatch = RegExp(r'/join/([^/?#]+)').firstMatch(token);
              if (joinMatch != null) token = joinMatch.group(1)!;
              if (token.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await context.read<WorkspaceProvider>().joinByToken(token);
              if (ok && mounted) {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              } else if (mounted) {
                final err = context.read<WorkspaceProvider>().errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err ?? '참여에 실패했습니다'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('참여'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wsProvider = context.watch<WorkspaceProvider>();
    final colorScheme = Theme.of(context).colorScheme;

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
              const Icon(Icons.workspaces_outlined, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('워크스페이스', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 워크스페이스 목록 + 버튼
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wsProvider.isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ))
                else if (wsProvider.workspaces.isNotEmpty) ...[
                  Text('내 워크스페이스',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  ...wsProvider.workspaces.map((ws) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: colorScheme.outline),
                          ),
                          tileColor: colorScheme.surface,
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              ws.name.isNotEmpty ? ws.name[0].toUpperCase() : 'W',
                              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text(ws.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('멤버 ${ws.memberCount}명'),
                          trailing: FilledButton(
                            onPressed: () {
                              wsProvider.selectWorkspace(ws);
                              Navigator.of(context).pop();
                            },
                            child: const Text('전환'),
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('새 워크스페이스 만들기'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _showJoinDialog,
                  icon: const Icon(Icons.link),
                  label: const Text('초대 코드로 참여하기'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
