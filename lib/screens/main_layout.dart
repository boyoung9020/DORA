import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_token_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../services/upload_service.dart';
import '../providers/notification_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/accent_palette.dart';
import '../utils/api_client.dart';
import '../providers/workspace_provider.dart';
import '../providers/sprint_provider.dart';
import '../providers/github_provider.dart';
import '../services/mattermost_service.dart';
import '../models/notification.dart' as models;
import '../models/project.dart';
import '../models/user.dart';
import '../models/workspace.dart';
import '../widgets/app_title_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/clean_dialog.dart';
import '../utils/avatar_color.dart';
import 'login_screen.dart';
import 'workspace_select_screen.dart';
import 'workspace_settings_screen.dart';
import 'dashboard_screen.dart';
import 'kanban_screen.dart';
import 'calendar_screen.dart';
import 'gantt_chart_screen.dart';
import 'quick_task_screen.dart';
import 'sprint_screen.dart';
import 'admin_approval_screen.dart';
import 'notification_screen.dart';
import 'chat_screen.dart';
import 'search_screen.dart';
import 'project_info_screen.dart';
import 'site_screen.dart';
import 'meeting_minutes_screen.dart';
import 'workspace_member_stats_screen.dart';
import '../services/workspace_service.dart';
import '../widgets/dashboard/yesterday_review_dialog.dart';
import '../main.dart' show PendingTaskOpen;
import '../services/task_service.dart';
import 'task_detail_screen.dart';

/// 메인 레이아웃 - Slack 스타일 (왼쪽 사이드바 + 오른쪽 컨텐츠)
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  static const _projectColorPalette = [
    Color(0xFFEC407A), // Pink
    Color(0xFF26C6DA), // Cyan
    Color(0xFF26A69A), // Teal
    Color(0xFFFF7043), // Deep Orange
    Color(0xFF8D6E63), // Brown
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFEF5350), // Red
  ];

  int _selectedIndex = 0; // 선택된 메뉴 인덱스
  bool _isMenuStateReady = false; // 메뉴 순서/선택 탭 복원 완료 여부
  /// 좌측 내비(아이콘) 열 표시 — 접으면 워크스페이스 레일만 남김
  bool _mainMenuVisible = true;
  WebSocketService? _webSocketService; // WebSocket 서비스

  // 토스트 디바운스: 동일 taskId에 대해 연속 이벤트 무시
  String? _lastToastTaskId;
  Timer? _toastDebounceTimer;

  // 프로젝트 드롭다운 오버레이
  final _projectBtnKey = GlobalKey();
  OverlayEntry? _projectDropdownEntry;
  OverlayEntry? _projectContextMenuEntry;

  // 메뉴 항목 정의 (상태로 관리하여 드래그로 순서 변경 가능)
  List<MenuItem> _menuItems = [
    MenuItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '홈',
      index: 0,
    ),
    MenuItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
      label: '프로젝트',
      index: 1,
    ),
    MenuItem(
      icon: Icons.view_kanban_outlined,
      selectedIcon: Icons.view_kanban,
      label: '칸반 보드',
      index: 2,
    ),
    MenuItem(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: '달력',
      index: 3,
    ),
    MenuItem(
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline,
      label: '간트 차트',
      index: 4,
    ),
    MenuItem(
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      label: '채팅',
      index: 5,
    ),
    MenuItem(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: '알림',
      index: 6,
    ),
    MenuItem(
      icon: Icons.dns_outlined,
      selectedIcon: Icons.dns,
      label: '사이트',
      index: 7,
    ),
    MenuItem(
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note,
      label: '회의록',
      index: 8,
    ),
    MenuItem(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: '멤버',
      index: 9,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 생명주기 관찰자 등록
    _loadMenuItems();
    _loadMainMenuVisibility();
    // 로그인 시 사용자 정보를 ProjectProvider에 전달
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateProjectProviderUserInfo();
      _initializeNotificationService(); // 알림 서비스 초기화
      _connectWebSocket(); // WebSocket 연결
      _checkYesterdayIncomplete(); // 어제 미완료 작업 리뷰
      _handlePendingTaskOpen(); // URL 딥링크로 작업 열기
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 생명주기 관찰자 제거
    _webSocketService?.disconnect(); // WebSocket 연결 해제
    _toastDebounceTimer?.cancel();
    _closeProjectContextMenu();
    _closeProjectDropdown();
    super.dispose();
  }

  void _closeProjectContextMenu() {
    _projectContextMenuEntry?.remove();
    _projectContextMenuEntry = null;
  }

  // ── 프로젝트 드롭다운 오버레이 ─────────────────────────────────────────

  void _closeProjectDropdown() {
    final pp = _projectDropdownEntry != null
        ? context.read<ProjectProvider>()
        : null;
    pp?.removeListener(_rebuildProjectDropdown);
    _projectDropdownEntry?.remove();
    _projectDropdownEntry = null;
  }

  void _rebuildProjectDropdown() {
    _projectDropdownEntry?.markNeedsBuild();
  }

  void _openProjectDropdown() {
    if (_projectDropdownEntry != null) {
      _closeProjectDropdown();
      return;
    }

    final pp = context.read<ProjectProvider>();
    final auth = context.read<AuthProvider>();
    final taskProv = context.read<TaskProvider>();
    final sprintProv = context.read<SprintProvider>();

    // 버튼 위치 계산
    final box = _projectBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset(0, box.size.height + 4));

    pp.addListener(_rebuildProjectDropdown);

    _projectDropdownEntry = OverlayEntry(
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final allSorted = pp.sortedProjects;
        final globalProjects = allSorted.where((p) => p.isGlobal).toList();
        final sorted = allSorted.where((p) => !p.isGlobal).toList();
        final hasFavs = sorted.any((p) => pp.isFavorite(p.id));
        final hasNonFavs = sorted.any((p) => !pp.isFavorite(p.id));

        return Stack(
          children: [
            // 바깥 탭 → 닫기
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeProjectDropdown,
              ),
            ),
            // 드롭다운 패널
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                color: cs.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 전체 항목 ──
                      _dropdownItem(
                        cs: cs,
                        leading: Icon(Icons.layers, size: 18,
                            color: pp.isAllProjectsMode ? cs.primary : cs.onSurface),
                        label: '전체',
                        isSelected: pp.isAllProjectsMode,
                        onTap: () async {
                          _closeProjectDropdown();
                          pp.selectAllProjects();
                          final wsProjectIds = pp.visibleProjects.map((p) => p.id).toList();
                          await taskProv.loadTasks();
                          taskProv.filterByProjectIds(wsProjectIds);
                          await sprintProv.loadSprints();
                        },
                      ),
                      Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),

                      // ── 글로벌(공용) 프로젝트 ──
                      if (globalProjects.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                          child: Text(
                            '공용',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.45),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        for (final project in globalProjects)
                          _dropdownItem(
                            cs: cs,
                            leading: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: project.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.public, size: 12,
                                  color: cs.onSurface.withValues(alpha: 0.45)),
                            ]),
                            label: project.name,
                            isSelected: pp.currentProject?.id == project.id,
                            isDark: isDark,
                            onTap: () async {
                              _closeProjectDropdown();
                              await pp.setCurrentProject(project.id);
                              if (!mounted) return;
                              await taskProv.loadTasks(projectId: project.id);
                              await sprintProv.loadSprints(projectId: project.id);
                            },
                          ),
                        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ],

                      // ── 프로젝트 목록 ──
                      ...() {
                        final widgets = <Widget>[];
                        bool dividerDone = false;
                        for (final project in sorted) {
                          final isFav = pp.isFavorite(project.id);
                          final isSelected = pp.currentProject?.id == project.id;

                          if (!isFav && hasFavs && hasNonFavs && !dividerDone) {
                            widgets.add(Divider(
                                height: 1,
                                color: cs.outlineVariant.withValues(alpha: 0.4)));
                            dividerDone = true;
                          }

                          widgets.add(
                            GestureDetector(
                              onSecondaryTapDown: (d) {
                                _showProjectContextMenu(
                                    context, project, pp, auth, d.globalPosition);
                              },
                              child: _dropdownItem(
                                cs: cs,
                                leading: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: project.color, shape: BoxShape.circle),
                                ),
                                label: project.name,
                                isSelected: isSelected,
                                isDark: isDark,
                                trailing: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => pp.toggleFavorite(project.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(
                                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                                      size: 18,
                                      color: isFav
                                          ? Colors.amber.shade600
                                          : cs.onSurface.withValues(alpha: 0.28),
                                    ),
                                  ),
                                ),
                                onTap: () async {
                                  _closeProjectDropdown();
                                  await pp.setCurrentProject(project.id);
                                  if (!mounted) return;
                                  await taskProv.loadTasks(projectId: project.id);
                                  await sprintProv.loadSprints(projectId: project.id);
                                },
                              ),
                            ),
                          );
                        }
                        return widgets;
                      }(),

                      // ── 보관함 (보기 토글이 켜져 있고 보관 항목이 1개 이상일 때) ──
                      if (pp.isShowingArchived && pp.archivedProjects.isNotEmpty) ...[
                        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                          child: Text(
                            '보관',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.45),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        for (final project in pp.archivedProjects)
                          GestureDetector(
                            onSecondaryTapDown: (d) {
                              _showProjectContextMenu(
                                  context, project, pp, auth, d.globalPosition);
                            },
                            child: Opacity(
                              opacity: 0.5,
                              child: _dropdownItem(
                                cs: cs,
                                leading: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: project.color, shape: BoxShape.circle),
                                ),
                                label: project.name,
                                isSelected: false,
                                isDark: isDark,
                                trailing: Icon(
                                  Icons.archive_outlined,
                                  size: 16,
                                  color: cs.onSurface.withValues(alpha: 0.4),
                                ),
                                onTap: () {
                                  // 보관 항목은 좌클릭 비활성화 (우클릭 컨텍스트 메뉴로만 조작)
                                },
                              ),
                            ),
                          ),
                      ],

                      // ── 새 프로젝트 ──
                      Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                      _dropdownItem(
                        cs: cs,
                        leading: Icon(Icons.add_circle_outline, size: 20, color: cs.primary),
                        label: '새 프로젝트',
                        labelColor: cs.primary,
                        bold: true,
                        onTap: () {
                          _closeProjectDropdown();
                          _showCreateProjectDialog(context);
                        },
                      ),

                      // ── 보관함 보기 토글 (보관 프로젝트가 1개 이상일 때만 노출) ──
                      if (pp.archivedProjects.isNotEmpty)
                        _dropdownItem(
                          cs: cs,
                          leading: Icon(
                            pp.isShowingArchived
                                ? Icons.visibility_off_outlined
                                : Icons.archive_outlined,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                          label: pp.isShowingArchived
                              ? '보관함 숨기기'
                              : '보관된 프로젝트 보기 (${pp.archivedProjects.length})',
                          labelColor: cs.onSurface.withValues(alpha: 0.7),
                          onTap: () {
                            pp.setShowArchived(!pp.isShowingArchived);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_projectDropdownEntry!);
  }

  /// 드롭다운 공용 항목 빌더
  Widget _dropdownItem({
    required ColorScheme cs,
    required Widget leading,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isDark = false,
    bool bold = false,
    Color? labelColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: isSelected
            ? cs.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      (isSelected || bold) ? FontWeight.w600 : FontWeight.normal,
                  color: labelColor ??
                      (isSelected ? cs.primary : cs.onSurface),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 16, color: cs.primary),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 포그라운드로 돌아올 때 WebSocket 재연결만 (이벤트 기반으로 자동 업데이트됨)
    if (state == AppLifecycleState.resumed) {
      _connectWebSocket();
    }
  }

  /// WebSocket 연결
  Future<void> _connectWebSocket() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      return;
    }

    // 기존 서비스가 있으면 명시적으로 해제 (고아 reconnect 타이머 방지)
    if (_webSocketService != null) {
      await _webSocketService!.disconnect();
      _webSocketService = null;
    }

    _webSocketService = WebSocketService();

    // 이벤트 핸들러 설정
    _webSocketService!.onEvent = (eventType, data) {
      print('[WebSocket] 이벤트 수신: $eventType');
      _handleWebSocketEvent(eventType, data);
    };

    await _webSocketService!.connect();
  }

  /// 어제 미완료 작업 리뷰 체크 (서버 상태 기반)
  ///
  /// 흐름:
  ///   1) GET /yesterday-incomplete — tasks 와 already_reviewed_today 동시 수신
  ///   2) already_reviewed_today == true → 즉시 종료
  ///   3) tasks 비어있음 → POST /acknowledge (이후 GET 이 already_reviewed_today=true 반환)
  ///   4) tasks 있음 → POST /acknowledge **먼저**, 이후 showDialog
  ///      (사용자가 중간에 이탈해도 당일 재노출 없음)
  Future<void> _checkYesterdayIncomplete() async {
    try {
      final wsProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final wsId = wsProvider.currentWorkspace?.id;
      if (wsId == null) return;

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final service = WorkspaceService();
      final result = await service.getYesterdayIncompleteTasks(
        wsId,
        targetDate: yesterdayStr,
      );

      if (result.alreadyReviewedToday) return;

      if (result.tasks.isEmpty) {
        // 서버에 '봤다' 를 기록해 이후 GET 도 동일하게 short-circuit 되게 함
        await service.acknowledgeYesterdayReview(wsId);
        return;
      }

      if (!mounted) return;

      // 다이얼로그를 띄우기 '직전' 에 ack — 이탈/새로고침 시에도 당일 재노출 없음
      await service.acknowledgeYesterdayReview(wsId);
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (_) => YesterdayReviewDialog(
          tasks: result.tasks,
          targetDate: yesterdayStr,
        ),
      );
    } catch (_) {
      // API 실패 시 조용히 skip — 다음 진입 때 자연 재시도
    }
  }

  /// URL 딥링크로 작업 열기 (/task/{id})
  Future<void> _handlePendingTaskOpen() async {
    final taskId = PendingTaskOpen.taskId;
    if (taskId == null) return;
    PendingTaskOpen.taskId = null; // 중복 실행 방지

    try {
      final task = await TaskService().getTaskById(taskId);
      if (task == null || !mounted) return;

      showGeneralDialog(
        context: context,
        transitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            TaskDetailScreen(task: task),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      );
    } catch (_) {
      // 작업을 찾을 수 없는 경우 무시
    }
  }

  /// 알림 서비스 초기화 및 알림 로드
  Future<void> _initializeNotificationService() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final wsProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      await notificationProvider.loadNotifications(
        userId: authProvider.currentUser!.id,
        currentUsername: authProvider.currentUser!.username,
      );
      await chatProvider.loadRooms(workspaceId: wsProvider.currentWorkspaceId);
    }
  }

  /// WebSocket 이벤트 처리
  Future<void> _handleWebSocketEvent(
    String eventType,
    Map<String, dynamic> data,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final sprintProvider = Provider.of<SprintProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );
    final wsProvider = Provider.of<WorkspaceProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
      return;
    }

    final user = authProvider.currentUser!;

    switch (eventType) {
      case 'project_created':
      case 'project_updated':
      case 'team_member_added':
        // 프로젝트 목록 새로고침 (워크스페이스 범위)
        await projectProvider.loadProjects(
          userId: user.id,
          isAdmin: authProvider.isAdmin,
          isPM: authProvider.isPM,
          workspaceId: wsProvider.currentWorkspaceId,
        );

        // 팀원 추가 시 인앱 토스트 표시
        if (eventType == 'team_member_added' && data['user_id'] == user.id) {
          final projectId = data['project_id'] as String?;
          try {
            final project = projectProvider.projects.firstWhere(
              (p) => p.id == projectId,
            );
            _showInAppToast(
              title: '팀원으로 추가되었습니다',
              message: '${project.name} 프로젝트에 팀원으로 추가되었습니다',
              type: models.NotificationType.projectMemberAdded,
            );
          } catch (e) {
            print('[Notification] 프로젝트를 찾을 수 없음: $projectId');
          }
        }
        break;

      case 'task_created':
      case 'task_updated':
        // 태스크 목록 새로고침
        await taskProvider.loadTasks(
          projectId: projectProvider.currentProject?.id,
        );

        // 태스크 관련 알림 처리
        final taskId = data['task_id'] as String?;
        if (taskId != null) {
          try {
            final task = taskProvider.tasks.firstWhere((t) => t.id == taskId);
            final isAssigned = task.assignedMemberIds.contains(user.id);

            if (eventType == 'task_created' && isAssigned) {
              _showInAppToast(
                title: '새 작업이 할당되었습니다',
                message: '${task.title}',
                type: models.NotificationType.taskAssigned,
                taskId: taskId,
              );
            } else if (eventType == 'task_updated' && isAssigned) {
              _showInAppToast(
                title: '작업이 변경되었습니다',
                message: '${task.title}',
                type: models.NotificationType.taskOptionChanged,
                taskId: taskId,
              );
            }
          } catch (e) {
            print('[Notification] 태스크를 찾을 수 없음: $taskId');
          }
        }
        break;

      case 'comment_created':
        final taskId = data['task_id'] as String?;
        if (taskId != null) {
          // 열린 태스크 다이얼로그에 실시간 댓글 갱신 알림
          taskProvider.notifyCommentCreated(taskId);

          try {
            final task = taskProvider.tasks.firstWhere((t) => t.id == taskId);
            if (task.assignedMemberIds.contains(user.id)) {
              _showInAppToast(
                title: '새 댓글이 추가되었습니다',
                message: '${task.title}',
                type: models.NotificationType.taskCommentAdded,
                taskId: taskId,
              );
            }
          } catch (e) {
            print('[Notification] 태스크를 찾을 수 없음: $taskId');
          }
        }
        break;

      case 'chat_message_sent':
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.handleIncomingMessage(data);
        break;

      case 'chat_message_updated':
        final chatProvider3 = Provider.of<ChatProvider>(context, listen: false);
        chatProvider3.handleMessageUpdated(data);
        break;

      case 'chat_message_deleted':
        final chatProvider4 = Provider.of<ChatProvider>(context, listen: false);
        chatProvider4.handleMessageDeleted(data);
        break;

      case 'chat_reaction_updated':
        final chatProvider5 = Provider.of<ChatProvider>(context, listen: false);
        chatProvider5.handleReactionUpdated(data);
        break;

      case 'chat_room_created':
        final chatProvider2 = Provider.of<ChatProvider>(context, listen: false);
        chatProvider2.handleRoomCreated(data);
        break;

      case 'sprint_created':
      case 'sprint_updated':
        await sprintProvider.loadSprints(
          projectId: projectProvider.currentProject?.id,
        );
        break;

      case 'notification_created':
        notificationProvider.addNotification(
          models.Notification.fromJson(data),
        );
        break;
    }
  }

  /// 인앱 토스트 알림 표시 (Slack/Notion 스타일)
  void _showInAppToast({
    required String title,
    required String message,
    required models.NotificationType type,
    String? taskId,
    bool showViewAction = true,
  }) {
    if (!mounted) return;

    // 같은 taskId에 대해 짧은 시간 내 반복 토스트 방지
    final toastKey = taskId ?? title;
    if (_lastToastTaskId == toastKey && _toastDebounceTimer?.isActive == true) {
      return;
    }
    _lastToastTaskId = toastKey;
    _toastDebounceTimer?.cancel();
    _toastDebounceTimer = Timer(const Duration(seconds: 6), () {
      _lastToastTaskId = null;
    });

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 알림 타입별 색상
    Color accentColor;
    IconData icon;
    switch (type) {
      case models.NotificationType.projectMemberAdded:
        accentColor = const Color(0xFF4F46E5);
        icon = Icons.group_add;
        break;
      case models.NotificationType.taskAssigned:
        accentColor = const Color(0xFFF59E0B);
        icon = Icons.assignment_ind;
        break;
      case models.NotificationType.taskCreated:
        accentColor = const Color(0xFF059669);
        icon = Icons.add_task;
        break;
      case models.NotificationType.taskOptionChanged:
        accentColor = const Color(0xFF8B5CF6);
        icon = Icons.settings;
        break;
      case models.NotificationType.taskCommentAdded:
        accentColor = const Color(0xFF10B981);
        icon = Icons.comment;
        break;
      case models.NotificationType.taskMentioned:
        accentColor = const Color(0xFF2563EB);
        icon = Icons.alternate_email;
        break;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDarkMode ? Colors.white : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isDarkMode
            ? const Color(0xFF2E2822)
            : const Color(0xFF38312B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(seconds: 5),
        showCloseIcon: true,
        closeIconColor: Colors.white.withValues(alpha: 0.7),
        dismissDirection: DismissDirection.horizontal,
        action: showViewAction
            ? SnackBarAction(
                label: '보기',
                textColor: accentColor,
                onPressed: () {
                  // 알림 화면으로 이동
                  final notifIndex = _menuItems.indexWhere(
                    (m) => m.label == '알림',
                  );
                  if (notifIndex != -1) {
                    setState(() {
                      _selectedIndex = notifIndex;
                    });
                    unawaited(_saveSelectedMenuIndex());
                  }
                },
              )
            : null,
      ),
    );
  }

  /// ProjectProvider에 사용자 정보 업데이트
  void _updateProjectProviderUserInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final sprintProvider = Provider.of<SprintProvider>(context, listen: false);

    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      final user = authProvider.currentUser!;

      // 이전 사용자 데이터 초기화
      projectProvider.setUserInfo(
        user.id,
        authProvider.isAdmin,
        authProvider.isPM,
      );

      // 프로젝트 목록 다시 로드 (현재 워크스페이스 기준 필터링)
      final wsProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      await projectProvider.loadProjects(
        userId: user.id,
        isAdmin: authProvider.isAdmin,
        isPM: authProvider.isPM,
        workspaceId: wsProvider.currentWorkspaceId,
      );
      await _migrateProjectColors();

      // 태스크 목록도 다시 로드
      await taskProvider.loadTasks(
        projectId: projectProvider.currentProject?.id,
      );
      await sprintProvider.loadSprints(
        projectId: projectProvider.currentProject?.id,
      );
    }
  }

  Future<void> _migrateProjectColors() async {
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    const defaultColor = Color(0xFF2196F3);

    final toMigrate = projectProvider.projects
        .where((project) => project.color.value == defaultColor.value)
        .toList();
    if (toMigrate.isEmpty) return;

    final usedColors = projectProvider.projects
        .where((project) => project.color.value != defaultColor.value)
        .map((project) => project.color.value)
        .toSet();

    final rng = Random();
    for (final project in toMigrate) {
      final available = _projectColorPalette
          .where((color) => !usedColors.contains(color.value))
          .toList();
      final palette = available.isNotEmpty ? available : _projectColorPalette;
      final newColor = palette[rng.nextInt(palette.length)];
      usedColors.add(newColor.value);

      await projectProvider.updateProject(project.copyWith(color: newColor));
    }
  }

  /// 워크스페이스 변경 시 데이터 새로고침
  Future<void> _onWorkspaceChanged(
    WorkspaceProvider wsProvider,
    Workspace ws,
  ) async {
    if (ws.id == wsProvider.currentWorkspaceId) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final sprintProvider = Provider.of<SprintProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    await wsProvider.selectWorkspace(ws);

    if (!authProvider.isAuthenticated || authProvider.currentUser == null)
      return;
    final user = authProvider.currentUser!;

    // 새 워크스페이스의 프로젝트 로드
    await projectProvider.loadProjects(
      userId: user.id,
      isAdmin: authProvider.isAdmin,
      isPM: authProvider.isPM,
      workspaceId: ws.id,
    );

    // 태스크 & 스프린트 새로고침
    await taskProvider.loadTasks(projectId: projectProvider.currentProject?.id);
    await sprintProvider.loadSprints(
      projectId: projectProvider.currentProject?.id,
    );

    // 채팅 새로고침
    chatProvider.loadRooms(workspaceId: ws.id);
  }

  /// 메뉴 아이템 로드 (저장된 순서가 있으면 사용, 없으면 기본 순서)
  Future<void> _loadMenuItems() async {
    final defaultItems = [
      MenuItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: '홈',
        index: 0,
      ),
      MenuItem(
        icon: Icons.space_dashboard_outlined,
        selectedIcon: Icons.space_dashboard,
        label: '프로젝트',
        index: 1,
      ),
      MenuItem(
        icon: Icons.view_kanban_outlined,
        selectedIcon: Icons.view_kanban,
        label: '칸반 보드',
        index: 2,
      ),
      MenuItem(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: '달력',
        index: 3,
      ),
      MenuItem(
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline,
        label: '간트 차트',
        index: 4,
      ),
      MenuItem(
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
        label: '채팅',
        index: 5,
      ),
      MenuItem(
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: '알림',
        index: 6,
      ),
      MenuItem(
        icon: Icons.dns_outlined,
        selectedIcon: Icons.dns,
        label: '사이트',
        index: 7,
      ),
      MenuItem(
        icon: Icons.edit_note_outlined,
        selectedIcon: Icons.edit_note,
        label: '회의록',
        index: 8,
      ),
      MenuItem(
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: '멤버',
        index: 9,
      ),
    ];

    var menuItemsToApply = defaultItems;
    int selectedIndexToApply = 0;

    // SharedPreferences에서 저장된 순서 로드
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('menu_item_order');
      selectedIndexToApply = prefs.getInt('selected_menu_index') ?? 0;
      if (savedOrder != null && savedOrder.length == defaultItems.length) {
        // 저장된 label이 모두 현재 defaultItems에 존재하는지 확인
        final defaultLabels = defaultItems.map((item) => item.label).toSet();
        final allMatch = savedOrder.every((label) => defaultLabels.contains(label));

        if (allMatch) {
          // 저장된 순서대로 재정렬
          final orderedItems = <MenuItem>[];
          for (final label in savedOrder) {
            final item = defaultItems.firstWhere((item) => item.label == label);
            orderedItems.add(item);
          }
          // index 업데이트
          for (int i = 0; i < orderedItems.length; i++) {
            orderedItems[i] = MenuItem(
              icon: orderedItems[i].icon,
              selectedIcon: orderedItems[i].selectedIcon,
              label: orderedItems[i].label,
              index: i,
            );
          }
          menuItemsToApply = orderedItems;
        }
        // label 불일치 시 기본 순서 사용 (메뉴 이름 변경 대응)
      }
    } catch (e) {
      // 에러 발생 시 기본 순서 사용
    }

    if (mounted) {
      setState(() {
        _menuItems = menuItemsToApply;
        _selectedIndex = selectedIndexToApply.clamp(0, _menuItems.length - 1);
        _isMenuStateReady = true;
      });
    }
  }

  /// 메뉴 아이템 순서 저장
  Future<void> _saveMenuItemsOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = _menuItems.map((item) => item.label).toList();
      await prefs.setStringList('menu_item_order', order);
      await prefs.setInt('selected_menu_index', _selectedIndex);
    } catch (e) {
      // 에러 무시
    }
  }

  Future<void> _saveSelectedMenuIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_menu_index', _selectedIndex);
    } catch (e) {
      // 에러 무시
    }
  }

  Future<void> _loadMainMenuVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _mainMenuVisible = prefs.getBool('main_menu_visible') ?? true;
      });
    } catch (_) {}
  }

  Future<void> _setMainMenuVisible(bool visible) async {
    setState(() => _mainMenuVisible = visible);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('main_menu_visible', visible);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);

    // 메뉴 아이템 (관리자 메뉴는 사이드바에서 제거, 대시보드 버튼으로 대체)
    final menuItems = List<MenuItem>.from(_menuItems);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = context.watch<ThemeProvider>().accentColor;
    final palette = AccentPalette(
      accent: accent,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
    );
    final shellColor = palette.shellBackground;

    return Scaffold(
      backgroundColor: shellColor,
      body: Column(
        children: [
          // 커스텀 타이틀바
          AppTitleBar(
            backgroundColor: palette.titleBarBackground,
            leadingWidth: 52 + (_mainMenuVisible ? 75 : 0),
            extraHeight: 0,
          ),
          // 메인 컨텐츠
          Expanded(
            child: Container(
              color: shellColor,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 워크스페이스 레일 (Slack 스타일, 가장 왼쪽)
                  _buildWorkspaceRail(context, palette),
                  if (_mainMenuVisible)
                    _buildSidebar(
                      context,
                      menuItems,
                      colorScheme,
                      authProvider,
                      isDarkMode,
                      shellColor,
                      palette,
                    ),
                  // 오른쪽 영역 (팀원 + 메인 - 같은 영역)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 프로젝트 선택 버튼 영역 (카드 외부, 상단 쉘 배경)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                          child: _buildProjectInfoBar(context),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                            child: Container(
                              decoration: BoxDecoration(
                                // 콘텐츠 카드 — accent 파생 contentSurfaceLowest 사용
                                // (사용자 포인트 색상 변경에 즉시 반응)
                                color: palette.contentSurfaceLowest,
                                gradient: null,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(28),
                                ),
                                boxShadow: isDarkMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 30,
                                          offset: const Offset(0, 18),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 28,
                                          offset: const Offset(0, 12),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.03,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(28),
                                ),
                                child: _buildContent(context),
                              ),
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
        ],
      ),
    );
  }

  /// Slack 스타일 워크스페이스 레일 (가장 왼쪽 좁은 열)
  Widget _buildWorkspaceRail(BuildContext context, AccentPalette palette) {
    final railColor = palette.workspaceRail;
    final railForeground = palette.workspaceRailForeground;

    return Consumer<WorkspaceProvider>(
      builder: (context, wsProvider, _) {
        return Container(
          width: 52,
          color: railColor,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Tooltip(
                message: _mainMenuVisible ? '메뉴 접기' : '메뉴 펼치기',
                preferBelow: false,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _setMainMenuVisible(!_mainMenuVisible),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Icon(
                        _mainMenuVisible
                            ? Icons.menu_open
                            : Icons.menu,
                        size: 22,
                        color: railForeground.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // ① 새 워크스페이스 추가 버튼 (최상단)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Tooltip(
                  message: '워크스페이스 추가 / 참여',
                  preferBelow: false,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => WorkspaceSelectScreen.showAsDialog(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: railForeground.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          color: railForeground.withValues(alpha: 0.85),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 구분선
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: railForeground.withValues(alpha: 0.15),
                ),
              ),
              // ② 워크스페이스 아이콘 목록
              ...wsProvider.workspaces.map((ws) {
                final isSelected = ws.id == wsProvider.currentWorkspaceId;
                return _buildWorkspaceIcon(
                    context, ws, isSelected, wsProvider, palette);
              }),
              const Spacer(),
              // ③ 워크스페이스 설정 버튼 (하단)
              if (wsProvider.currentWorkspace != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Tooltip(
                    message: '워크스페이스 메뉴',
                    preferBelow: false,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            WorkspaceSettingsScreen.showAsDialog(context),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.more_horiz,
                            color: railForeground.withValues(alpha: 0.72),
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
    );
  }

  /// 워크스페이스 아이콘 (레일 내 각 워크스페이스)
  Widget _buildWorkspaceIcon(
    BuildContext context,
    Workspace ws,
    bool isSelected,
    WorkspaceProvider wsProvider,
    AccentPalette palette,
  ) {
    final railAccent = palette.workspaceRailAccent;

    const avatarColors = [
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
      Color(0xFFEC407A),
      Color(0xFF66BB6A),
      Color(0xFFAB47BC),
      Color(0xFF26C6DA),
      Color(0xFF8D6E63),
    ];
    final color = avatarColors[ws.name.hashCode.abs() % avatarColors.length];
    final initial = ws.name.isNotEmpty ? ws.name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Slack 스타일 선택 표시자 (왼쪽 흰색 막대)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 3,
            height: isSelected ? 28 : 0,
            decoration: BoxDecoration(
              color: railAccent,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Tooltip(
            message: ws.name,
            preferBelow: false,
            child: GestureDetector(
              onTap: () => _onWorkspaceChanged(wsProvider, ws),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10), // 워크스페이스는 항상 네모
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 사이드바 위젯
  Widget _buildSidebar(
    BuildContext context,
    List<MenuItem> menuItems,
    ColorScheme colorScheme,
    AuthProvider authProvider,
    bool isDarkMode,
    Color shellColor,
    AccentPalette palette,
  ) {
    final sidebarColor = palette.sidebarBackground;
    final sidebarTextColor = isDarkMode
        ? palette.sidebarText
        : palette.sidebarText.withValues(alpha: 0.9);

    return Container(
      width: 75,
      decoration: BoxDecoration(
        color: sidebarColor,
        border: Border.all(color: Colors.transparent),
        boxShadow: const [],
      ),
      child: Column(
        children: [
          // 유저 프로필 (상단)
          Padding(
            padding: const EdgeInsets.only(
              top: 16.0,
              bottom: 8.0,
              left: 8.0,
              right: 8.0,
            ),
            child: _buildUserProfile(context, colorScheme, authProvider),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              buildDefaultDragHandles: false, // 기본 드래그 핸들 비활성화
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _menuItems.removeAt(oldIndex);
                  _menuItems.insert(newIndex, item);
                  // index 업데이트
                  for (int i = 0; i < _menuItems.length; i++) {
                    _menuItems[i] = MenuItem(
                      icon: _menuItems[i].icon,
                      selectedIcon: _menuItems[i].selectedIcon,
                      label: _menuItems[i].label,
                      index: i,
                    );
                  }
                  // 선택된 인덱스가 변경된 경우 업데이트
                  if (_selectedIndex == oldIndex) {
                    _selectedIndex = newIndex;
                  } else if (_selectedIndex == newIndex &&
                      oldIndex < newIndex) {
                    _selectedIndex = newIndex - 1;
                  } else if (_selectedIndex == newIndex &&
                      oldIndex > newIndex) {
                    _selectedIndex = newIndex + 1;
                  } else if (_selectedIndex > oldIndex &&
                      _selectedIndex <= newIndex) {
                    _selectedIndex -= 1;
                  } else if (_selectedIndex < oldIndex &&
                      _selectedIndex >= newIndex) {
                    _selectedIndex += 1;
                  }
                });
                _saveMenuItemsOrder();
              },
              children: _menuItems.map((item) {
                return _buildMenuItem(
                  context,
                  item,
                  colorScheme,
                  palette,
                  key: ValueKey(item.label),
                );
              }).toList(),
            ),
          ),
          // 설정 버튼 및 로그아웃
          Column(
            children: [
              const SizedBox(height: 8),
              // 설정 버튼 - 메뉴 아이템과 동일한 구조
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showSettingsDialog(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 56, // 고정 높이로 정렬 일관성 확보
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings,
                            color: sidebarTextColor,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '설정',
                            style: TextStyle(
                              fontSize: 11,
                              color: sidebarTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }

  /// 유저 프로필 버튼 (네비게이션 상단)
  Widget _buildUserProfile(
    BuildContext context,
    ColorScheme colorScheme,
    AuthProvider authProvider,
  ) {
    final user = authProvider.currentUser;

    if (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) {
      final url = user.profileImageUrl!.startsWith('/')
          ? '${ApiClient.baseUrl}${user.profileImageUrl!}'
          : user.profileImageUrl!;
      return Center(
        child: CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(url),
          onBackgroundImageError: (_, __) {},
        ),
      );
    }
    return Center(
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AvatarColor.getColorForUser(
          user?.id ?? user?.username ?? 'U',
        ),
        child: Text(
          AvatarColor.getInitial(user?.username ?? 'U'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  /// 멤버 아바타 (프로필 이미지 지원)
  Widget _buildMemberAvatar(User member, {double radius = 18}) {
    if (member.profileImageUrl != null && member.profileImageUrl!.isNotEmpty) {
      final url = member.profileImageUrl!.startsWith('/')
          ? '${ApiClient.baseUrl}${member.profileImageUrl!}'
          : member.profileImageUrl!;
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AvatarColor.getColorForUser(member.id),
      child: Text(
        AvatarColor.getInitial(member.username),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.78,
        ),
      ),
    );
  }

  /// 프로젝트 정보 바 (모든 화면 최상단)
  Widget _buildProjectInfoBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = context.watch<ThemeProvider>().accentColor;
    final palette = AccentPalette(
      accent: accent,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
    );
    final projectProvider = Provider.of<ProjectProvider>(context);
    final currentProject = projectProvider.currentProject;
    // 프로젝트 정보 바 — shell 톤 사용 (콘텐츠 카드 위에 살짝 떠 있는 느낌)
    final infoBarColor = palette.shellBackground;
    // 텍스트/아이콘 — 다크: onSurface, 라이트: 사이드바 텍스트와 같은 톤 (accent 파생 갈색)
    final infoBarText =
        isDarkMode ? colorScheme.onSurface : palette.sidebarText;
    final infoBarTextMuted = infoBarText.withValues(alpha: 0.75);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: BoxDecoration(
        color: infoBarColor,
      ),
      child: Row(
        children: [
          // 프로젝트 드롭다운 버튼 (사이트·채팅·알림 화면에서는 숨김)
          if (!_isProjectBarHidden) InkWell(
            key: _projectBtnKey,
            borderRadius: BorderRadius.circular(8),
            onTap: _openProjectDropdown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (projectProvider.isAllProjectsMode) ...[
                    Icon(Icons.layers, size: 18, color: infoBarText),
                    const SizedBox(width: 12),
                    Text('전체',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: infoBarText,
                        )),
                  ] else if (currentProject != null) ...[
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: currentProject.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Text(currentProject.name,
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: infoBarText,
                        )),
                  ] else ...[
                    Icon(Icons.folder_outlined, size: 20,
                        color: infoBarTextMuted),
                    const SizedBox(width: 12),
                    Text('프로젝트를 선택하세요',
                        style: TextStyle(
                          fontSize: 16, color: infoBarTextMuted,
                        )),
                  ],
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_drop_down, size: 24,
                      color: infoBarTextMuted),
                ],
              ),
            ),
          ),
          // 인물 필터 드롭다운 (사이트·채팅·알림 화면에서는 숨김)
          if (!_isProjectBarHidden) const SizedBox(width: 8),
          if (!_isProjectBarHidden) Consumer<TaskProvider>(
            builder: (context, taskProv, _) {
              final filter = taskProv.taskOwnerFilter;
              final isFiltered = filter != null;

              // 현재 선택된 라벨/아이콘 결정
              String filterLabel;
              IconData filterIcon;
              if (filter == null) {
                filterLabel = '모든 작업';
                filterIcon = Icons.people;
              } else if (filter == 'mine') {
                filterLabel = '내 작업';
                filterIcon = Icons.person;
              } else {
                // 특정 멤버 ID
                filterLabel = _getMemberName(filter);
                filterIcon = Icons.person_outline;
              }

              final defaultColor = infoBarText.withValues(alpha: 0.6);

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showTaskOwnerFilterMenu(context, taskProv),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFiltered
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFiltered
                          ? colorScheme.primary.withValues(alpha: 0.4)
                          : colorScheme.onSurface.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filterIcon,
                        size: 16,
                        color: isFiltered ? colorScheme.primary : defaultColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        filterLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isFiltered ? FontWeight.w600 : FontWeight.normal,
                          color: isFiltered ? colorScheme.primary : defaultColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: isFiltered ? colorScheme.primary : defaultColor,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          IconButton(
            tooltip: '전체 검색',
            onPressed: () => _showSearchDialog(context),
            icon: Icon(
              Icons.search,
              color: infoBarText,
            ),
          ),
        ],
      ),
    );
  }

  // 캐시된 유저 목록 (작업 필터 드롭다운용)
  List<User>? _cachedUsers;

  String _getMemberName(String userId) {
    final user = _cachedUsers?.where((u) => u.id == userId).firstOrNull;
    return user?.username ?? '멤버';
  }

  void _showTaskOwnerFilterMenu(BuildContext context, TaskProvider taskProv) async {
    // 유저 목록 로드 (캐시)
    _cachedUsers ??= await AuthService().getAllUsers();

    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final currentFilter = taskProv.taskOwnerFilter;

    // 드롭다운 버튼 위치 계산 — 버튼 바로 아래에 표시
    final RenderBox button = context.findRenderObject() as RenderBox;
    final buttonPos = button.localToGlobal(Offset.zero);
    final buttonSize = button.size;

    final allUsers = _cachedUsers ?? [];

    // 현재 프로젝트 멤버만 필터링 (전체모드면 모든 유저)
    final projectProvider = context.read<ProjectProvider>();
    final currentProject = projectProvider.currentProject;
    final isAllMode = projectProvider.isAllProjectsMode;

    List<User> users;
    if (!isAllMode && currentProject != null) {
      final memberIds = currentProject.teamMemberIds;
      users = allUsers.where((u) => memberIds.contains(u.id)).toList();
    } else {
      // 전체 모드: 내가 속한 프로젝트들의 팀원만 표시 (보관 제외)
      final myProjects = projectProvider.visibleProjects;
      final memberIds = <String>{};
      for (final p in myProjects) {
        memberIds.addAll(p.teamMemberIds);
      }
      users = allUsers.where((u) => memberIds.contains(u.id)).toList();
    }

    showMenu<String?>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPos.dx,
        buttonPos.dy + buttonSize.height,
        buttonPos.dx + buttonSize.width,
        0,
      ),
      items: [
        // 모든 작업
        PopupMenuItem<String?>(
          value: '__all__',
          child: Row(
            children: [
              Icon(Icons.people, size: 18,
                color: currentFilter == null ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Text('모든 작업', style: TextStyle(
                fontWeight: currentFilter == null ? FontWeight.bold : FontWeight.normal,
                color: currentFilter == null ? colorScheme.primary : colorScheme.onSurface,
              )),
            ],
          ),
        ),
        // 내 작업
        PopupMenuItem<String?>(
          value: 'mine',
          child: Row(
            children: [
              Icon(Icons.person, size: 18,
                color: currentFilter == 'mine' ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Text('내 작업', style: TextStyle(
                fontWeight: currentFilter == 'mine' ? FontWeight.bold : FontWeight.normal,
                color: currentFilter == 'mine' ? colorScheme.primary : colorScheme.onSurface,
              )),
            ],
          ),
        ),
        // 구분선
        const PopupMenuDivider(),
        // 팀원 목록 (프로젝트 멤버만)
        ...users.where((u) => u.id != currentUserId).map(
          (user) => PopupMenuItem<String?>(
            value: user.id,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AvatarColor.getColorForUser(user.id),
                  child: Text(
                    AvatarColor.getInitial(user.username),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Text(user.username, style: TextStyle(
                  fontWeight: currentFilter == user.id ? FontWeight.bold : FontWeight.normal,
                  color: currentFilter == user.id ? colorScheme.primary : colorScheme.onSurface,
                )),
              ],
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == '__all__') {
        taskProv.setTaskOwnerFilter(null);
      } else if (value != null) {
        taskProv.setTaskOwnerFilter(value);
      }
    });
  }

  /// 프로젝트 컨텍스트 메뉴 표시 (오른쪽 클릭)
  void _showProjectContextMenu(
    BuildContext context,
    Project project,
    ProjectProvider projectProvider,
    AuthProvider authProvider,
    Offset position,
  ) {
    // 프로젝트 PM(creator) 또는 Admin만 삭제 가능
    final isProjectPM =
        project.creatorId == authProvider.currentUser?.id ||
        authProvider.isAdmin;
    if (!isProjectPM) {
      return;
    }

    // 이미 떠있는 메뉴가 있으면 먼저 제거 (우클릭 누적 방지)
    _closeProjectContextMenu();

    final cs = Theme.of(context).colorScheme;
    final mediaSize = MediaQuery.of(context).size;
    const menuWidth = 180.0;
    const menuHeight = 96.0; // 항목 2개 기준 대략 높이
    // 화면 밖으로 안 나가도록 클램프
    final left = position.dx.clamp(0.0, mediaSize.width - menuWidth);
    final top = position.dy.clamp(0.0, mediaSize.height - menuHeight);

    Widget menuItem({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    _projectContextMenuEntry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            // 바깥 탭/우클릭 → 닫기 (드롭다운은 그대로 유지)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeProjectContextMenu,
                onSecondaryTap: _closeProjectContextMenu,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: cs.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: menuWidth, maxWidth: 220),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      menuItem(
                        icon: project.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        label: project.isArchived ? '보관 해제' : '프로젝트 보관',
                        color: cs.onSurface,
                        onTap: () {
                          _closeProjectContextMenu();
                          // 다이얼로그(Navigator route) 가 드롭다운(OverlayEntry) 보다 아래라
                          // 드롭다운의 outer tap detector 가 첫 클릭을 흡수함 → 함께 닫음
                          _closeProjectDropdown();
                          if (project.isArchived) {
                            _runUnarchiveProject(this.context, project, projectProvider);
                          } else {
                            _showArchiveProjectDialog(
                              this.context,
                              project,
                              projectProvider,
                            );
                          }
                        },
                      ),
                      menuItem(
                        icon: Icons.delete_outline,
                        label: '프로젝트 삭제',
                        color: Colors.red,
                        onTap: () {
                          _closeProjectContextMenu();
                          _closeProjectDropdown();
                          _showDeleteProjectDialog(
                            this.context,
                            project,
                            projectProvider,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_projectContextMenuEntry!);
  }

  /// 프로젝트 보관 확인 다이얼로그
  Future<void> _showArchiveProjectDialog(
    BuildContext context,
    Project project,
    ProjectProvider projectProvider,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showCleanConfirmDialog(
      context: context,
      title: '프로젝트 보관',
      message:
          '"${project.name}" 프로젝트를 보관하시겠습니까?\n'
          '모든 멤버의 드롭다운/대시보드에서 숨겨지지만 데이터는 유지되며 언제든 복원할 수 있습니다.',
      confirmLabel: '보관',
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final success = await projectProvider.archiveProject(project.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '${project.name} 프로젝트가 보관되었습니다'
            : (projectProvider.errorMessage ?? '프로젝트 보관에 실패했습니다')),
        backgroundColor:
            success ? colorScheme.primary : colorScheme.error,
      ),
    );
  }

  /// 프로젝트 보관 해제 (즉시 실행)
  Future<void> _runUnarchiveProject(
    BuildContext context,
    Project project,
    ProjectProvider projectProvider,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final success = await projectProvider.unarchiveProject(project.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${project.name} 프로젝트의 보관이 해제되었습니다'
              : (projectProvider.errorMessage ?? '보관 해제에 실패했습니다')),
          backgroundColor:
              success ? colorScheme.primary : colorScheme.error,
        ),
      );
    }
  }

  /// 프로젝트 삭제 확인 다이얼로그
  Future<void> _showDeleteProjectDialog(
    BuildContext context,
    Project project,
    ProjectProvider projectProvider,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showCleanConfirmDialog(
      context: context,
      title: '프로젝트 삭제',
      message:
          '"${project.name}" 프로젝트를 삭제하시겠습니까?\n'
          '이 작업은 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
      isDestructive: true,
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final success = await projectProvider.deleteProject(project.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '${project.name} 프로젝트가 삭제되었습니다'
            : (projectProvider.errorMessage ?? '프로젝트 삭제에 실패했습니다')),
        backgroundColor:
            success ? colorScheme.primary : colorScheme.error,
      ),
    );
  }

  /// 프로젝트 생성 다이얼로그
  Future<void> _showCreateProjectDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final wsProvider = Provider.of<WorkspaceProvider>(context, listen: false);

    final name = await showCleanInputDialog(
      context: context,
      title: '새 프로젝트',
      hint: '프로젝트 이름',
      confirmLabel: '생성',
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;

    final usedColors = projectProvider.projects
        .map((project) => project.color.value)
        .toSet();
    final available = _projectColorPalette
        .where((color) => !usedColors.contains(color.value))
        .toList();
    final palette = available.isNotEmpty ? available : _projectColorPalette;
    final randomColor = palette[Random().nextInt(palette.length)];

    final success = await projectProvider.createProject(
      name: name,
      workspaceId: wsProvider.currentWorkspaceId,
      color: randomColor,
    );
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(projectProvider.errorMessage ?? '프로젝트 생성에 실패했습니다.'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  /// 메뉴 항목 위젯
  Widget _buildMenuItem(
    BuildContext context,
    MenuItem item,
    ColorScheme colorScheme,
    AccentPalette palette, {
    Key? key,
  }) {
    final isSelected = _selectedIndex == item.index;
    final notificationProvider = context.watch<NotificationProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final isNotificationItem = item.label == '알림';
    final isChatItem = item.label == '채팅';
    final unreadCount = isNotificationItem
        ? notificationProvider.unreadCount
        : isChatItem
        ? chatProvider.totalUnreadCount
        : 0;
    final isDarkMode = palette.brightness == Brightness.dark;
    final sidebarColor = palette.sidebarBackground;
    final menuTextColor = palette.sidebarText;
    // 선택된 메뉴 항목의 배경 — 다크모드는 흰색 틴트, 라이트는 accent 파생색
    final selectedHighlight = isDarkMode
        ? Colors.white.withValues(alpha: 0.16)
        : palette.workspaceRail.withValues(alpha: 0.45);

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = item.index;
            });
            unawaited(_saveSelectedMenuIndex());
            // 화면 전환 시에는 WebSocket 이벤트만 사용 (자동 새로고침 제거)
          },
          borderRadius: BorderRadius.circular(12),
          child: ReorderableDragStartListener(
            index: item.index,
            child: Container(
              width: double.infinity,
              height: 56, // 고정 높이로 정렬 일관성 확보
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? selectedHighlight : Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected
                            ? menuTextColor
                            : menuTextColor.withValues(alpha: 0.82),
                        size: 24,
                      ),
                      // 알림/채팅 뱃지 (읽지 않은 항목이 있을 때만)
                      if ((isNotificationItem || isChatItem) && unreadCount > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sidebarColor,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? menuTextColor
                          : menuTextColor.withValues(alpha: 0.82),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 팀원 관리 사이드바
  Widget _buildTeamMemberSidebar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final currentProject = projectProvider.currentProject;

    if (currentProject == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 240,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(Icons.people, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '팀원',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Consumer2<AuthProvider, ProjectProvider>(
                  builder: (context, authProvider, projProvider, _) {
                    final proj = projProvider.currentProject;
                    final isProjectPM =
                        proj?.creatorId == authProvider.currentUser?.id ||
                        authProvider.isAdmin;
                    if (isProjectPM) {
                      return IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        onPressed: () => _showAddTeamMemberDialog(
                          context,
                          currentProject,
                          projectProvider,
                        ),
                        tooltip: '팀원 추가',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // 팀원 목록 (ProjectProvider 변경 감지)
            Expanded(
              child: Consumer<ProjectProvider>(
                builder: (context, provider, _) {
                  // currentProject를 provider에서 가져와서 최신 데이터 사용
                  final latestProject =
                      provider.currentProject ?? currentProject;
                  return _buildTeamMemberList(
                    context,
                    latestProject,
                    colorScheme,
                    projectProvider,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 팀원 목록 위젯
  Widget _buildTeamMemberList(
    BuildContext context,
    currentProject,
    ColorScheme colorScheme,
    ProjectProvider projectProvider,
  ) {
    // currentProject.teamMemberIds를 키로 사용하여 변경 감지
    return FutureBuilder<List<dynamic>>(
      key: ValueKey(
        'team_members_${currentProject?.id}_${(currentProject?.teamMemberIds ?? []).join(',')}',
      ),
      future: _loadTeamMembers(currentProject),
      builder: (context, snapshot) {
        final teamMembers = snapshot.data ?? [];

        if (teamMembers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  '팀원이 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Consumer2<AuthProvider, ProjectProvider>(
                  builder: (context, authProvider, projProvider, _) {
                    final proj = projProvider.currentProject;
                    final isProjectPM =
                        proj?.creatorId == authProvider.currentUser?.id ||
                        authProvider.isAdmin;
                    if (isProjectPM) {
                      return Column(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            '+ 버튼을 눌러\n팀원을 추가하세요',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: teamMembers.length,
          itemBuilder: (context, index) {
            final member = teamMembers[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: colorScheme.surface.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      children: [
                        _buildMemberAvatar(member, radius: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    member.username,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (member.id == currentProject.creatorId) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.5,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'PM',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                member.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Consumer2<AuthProvider, ProjectProvider>(
                          builder: (context, authProvider, projProvider, _) {
                            final proj = projProvider.currentProject;
                            final isProjectPM =
                                proj?.creatorId ==
                                    authProvider.currentUser?.id ||
                                authProvider.isAdmin;
                            if (isProjectPM) {
                              return IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.red.withValues(alpha: 0.7),
                                ),
                                onPressed: () => _removeTeamMember(
                                  context,
                                  currentProject,
                                  member.id,
                                  projectProvider,
                                ),
                                tooltip: '제거',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              );
                            }
                            return const SizedBox.shrink();
                          },
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

  /// 팀원 목록 로드 (PM이 먼저 오도록 정렬)
  Future<List<dynamic>> _loadTeamMembers(currentProject) async {
    try {
      final authService = AuthService();
      final workspaceId = (currentProject as Project).workspaceId;
      // 워크스페이스 프로젝트는 워크스페이스 멤버 기준으로 조회
      // (승인 상태와 무관하게 실제 프로젝트 팀원 ID와 매칭되도록)
      final candidates = workspaceId != null
          ? await authService.getUsersByWorkspace(workspaceId)
          : await authService.getApprovedUsers();

      // 프로젝트 팀원에 포함된 사용자만 필터링
      final teamMembers = candidates
          .where((u) => currentProject.teamMemberIds.contains(u.id))
          .toList();

      // 프로젝트 PM(creatorId)을 먼저, 나머지는 teamMemberIds 추가 순서대로 정렬
      teamMembers.sort((a, b) {
        final aIsProjectPM = a.id == currentProject.creatorId;
        final bIsProjectPM = b.id == currentProject.creatorId;
        if (aIsProjectPM && !bIsProjectPM) return -1;
        if (!aIsProjectPM && bIsProjectPM) return 1;
        final aIndex = currentProject.teamMemberIds.indexOf(a.id);
        final bIndex = currentProject.teamMemberIds.indexOf(b.id);
        return aIndex.compareTo(bIndex);
      });

      return teamMembers;
    } catch (e) {
      print('[MainLayout] 팀원 목록 로드 실패: $e');
      return [];
    }
  }

  /// 팀원 추가 다이얼로그
  void _showAddTeamMemberDialog(
    BuildContext context,
    currentProject,
    ProjectProvider projectProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: _loadAvailableUsers(currentProject),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
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
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
              );
            }

            final availableUsers = snapshot.data!;

            if (availableUsers.isEmpty) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('추가할 수 있는 사용자가 없습니다'),
                  backgroundColor: colorScheme.error,
                ),
              );
              return const SizedBox.shrink();
            }

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
                    maxWidth: 500,
                    maxHeight: 600,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '팀원 추가',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = availableUsers[index];
                            return ListTile(
                              leading: _buildMemberAvatar(user),
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
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.add_circle,
                                  color: colorScheme.primary,
                                ),
                                onPressed: () async {
                                  try {
                                    // 팀원 추가 API 사용 (내부에서 이미 loadProjects 호출함)
                                    final added = await projectProvider
                                        .addTeamMember(
                                          currentProject.id,
                                          user.id,
                                        );
                                    if (!added) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              '팀원 추가에 실패했습니다. 워크스페이스 멤버인지 확인해 주세요.',
                                            ),
                                            backgroundColor: colorScheme.error,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    Navigator.of(context).pop();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${user.username}님이 팀에 추가되었습니다',
                                          ),
                                          backgroundColor: colorScheme.primary,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('팀원 추가 실패: $e'),
                                          backgroundColor: colorScheme.error,
                                        ),
                                      );
                                    }
                                  }
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
      },
    );
  }

  /// 사용 가능한 사용자 목록 로드
  Future<List<dynamic>> _loadAvailableUsers(currentProject) async {
    try {
      final authService = AuthService();
      // 워크스페이스 기반: 같은 워크스페이스 멤버만 초대 가능
      final workspaceId = (currentProject as Project).workspaceId;
      final List<dynamic> candidates;
      if (workspaceId != null) {
        candidates = await authService.getUsersByWorkspace(workspaceId);
      } else {
        candidates = await authService.getApprovedUsers();
      }
      // 이미 팀원에 포함된 사용자는 제외
      return candidates
          .where((u) => !currentProject.teamMemberIds.contains(u.id))
          .toList();
    } catch (e) {
      print('[MainLayout] 사용 가능한 사용자 로드 실패: $e');
      return [];
    }
  }

  /// 팀원 제거
  void _removeTeamMember(
    BuildContext context,
    currentProject,
    String userId,
    ProjectProvider projectProvider,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;

    final user = await _getUserById(userId);
    if (user == null) return;

    final confirmed = await showDialog<bool>(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '팀원 제거',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${user.username}님을 팀에서 제거하시겠습니까?',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        '취소',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: colorScheme.error.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      child: Text(
                        '제거',
                        style: TextStyle(color: colorScheme.error),
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

    if (confirmed == true) {
      final updatedMemberIds = currentProject.teamMemberIds
          .where((id) => id != userId)
          .toList();
      await projectProvider.updateProject(
        currentProject.copyWith(
          teamMemberIds: updatedMemberIds,
          updatedAt: DateTime.now(),
        ),
      );
      // 프로젝트 목록 다시 로드 (필터링 적용)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        await projectProvider.loadProjects(
          userId: authProvider.currentUser!.id,
          isAdmin: authProvider.isAdmin,
          isPM: authProvider.isPM,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.username}님이 팀에서 제거되었습니다'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  /// 사용자 ID로 사용자 가져오기
  Future<dynamic> _getUserById(String userId) async {
    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      return allUsers.firstWhere((u) => u.id == userId);
    } catch (e) {
      return null;
    }
  }

  /// 컨텐츠 영역
  Widget _buildContent(BuildContext context) {
    if (!_isMenuStateReady) {
      // 새로고침 직후 복원 완료 전 화면 플래시 방지
      return const SizedBox.expand();
    }
    // 현재 선택된 메뉴 아이템의 label을 기반으로 화면 반환
    if (_selectedIndex >= 0 && _selectedIndex < _menuItems.length) {
      final selectedItem = _menuItems[_selectedIndex];
      return _getScreenByLabel(selectedItem.label);
    }
    return const DashboardScreen();
  }

  /// 프로젝트 바를 숨겨야 하는 화면 여부 (사이트·채팅·알림)
  bool get _isProjectBarHidden {
    if (!_isMenuStateReady) return false;
    if (_selectedIndex >= 0 && _selectedIndex < _menuItems.length) {
      const hideLabels = {'사이트', '채팅', '알림', '회의록', '멤버'};
      return hideLabels.contains(_menuItems[_selectedIndex].label);
    }
    return false;
  }

  /// 현재 선택된 화면이 대시보드인지 확인
  bool _isDashboardSelected() {
    if (!_isMenuStateReady) return false;
    if (_selectedIndex >= 0 && _selectedIndex < _menuItems.length) {
      final selectedItem = _menuItems[_selectedIndex];
      return selectedItem.label == '홈';
    }
    return true; // 기본값은 대시보드
  }

  /// label에 따라 화면 반환
  Widget _getScreenByLabel(String label) {
    switch (label) {
      case '홈':
        return const DashboardScreen();
      case '칸반 보드':
        return const KanbanScreen();
      case '달력':
        return const CalendarScreen();
      case '간트 차트':
        return const GanttChartScreen();
      case '빠른 추가':
        return const QuickTaskScreen();
      case '스프린트':
        return const SprintScreen();
      case '알림':
        return const NotificationScreen();
      case '채팅':
        return const ChatScreen();
      case '관리자 승인':
        return const AdminApprovalScreen();
      case '프로젝트':
        return const ProjectInfoScreen();
      case '사이트':
        return const SiteScreen();
      case '회의록':
        return const MeetingMinutesScreen();
      case '멤버':
        return const WorkspaceMemberStatsScreen();
      default:
        return const DashboardScreen();
    }
  }

  /// 프로필 이미지 선택 및 업로드
  Future<void> _pickAndUploadProfileImage(AuthProvider authProvider) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    try {
      // XFile에서 직접 바이트 읽기 (Windows namespace 경로 문제 회피)
      final bytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name;
      print('[ProfileImage] 파일 선택됨: $fileName (${bytes.length} bytes)');

      final uploadService = UploadService();
      final imageUrl = await uploadService.uploadImageBytes(bytes, fileName);
      print('[ProfileImage] 업로드 성공: $imageUrl');
      await authProvider.updateProfileImage(imageUrl);
      print('[ProfileImage] 프로필 업데이트 완료');
    } catch (e) {
      print('[ProfileImage] 에러: $e');
    }
  }

  void _showSearchDialog(BuildContext context) {
    final workspaceId = context.read<WorkspaceProvider>().currentWorkspaceId;
    final projectId = context.read<ProjectProvider>().currentProject?.id;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) =>
          SearchScreen(workspaceId: workspaceId, projectId: projectId),
    );
  }

  /// 설정 다이얼로그
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => _SettingsDialogContent(
        onPickProfileImage: _pickAndUploadProfileImage,
      ),
    );
  }
}

/// 프로필 이미지 + 카메라 버튼 (눌림 스케일 효과)
class _ProfileImageButton extends StatefulWidget {
  const _ProfileImageButton({
    required this.colorScheme,
    required this.currentUser,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final User currentUser;
  final VoidCallback onTap;

  @override
  State<_ProfileImageButton> createState() => _ProfileImageButtonState();
}

class _ProfileImageButtonState extends State<_ProfileImageButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.currentUser.profileImageUrl != null
                  ? CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(
                        widget.currentUser.profileImageUrl!.startsWith('/')
                            ? '${ApiClient.baseUrl}${widget.currentUser.profileImageUrl!}'
                            : widget.currentUser.profileImageUrl!,
                      ),
                    )
                  : CircleAvatar(
                      radius: 30,
                      backgroundColor: AvatarColor.getColorForUser(
                        widget.currentUser.id,
                      ),
                      child: Text(
                        AvatarColor.getInitial(widget.currentUser.username),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
              Positioned(
                bottom: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _hovered
                          ? Colors.white
                          : widget.colorScheme.surface,
                      width: _hovered ? 2.5 : 2,
                    ),
                    boxShadow: _pressed
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : _hovered
                        ? [
                            BoxShadow(
                              color: widget.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : null,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 메뉴 항목 모델
class MenuItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;

  MenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
  });
}

/// 설정 다이얼로그 (좌측 네비게이션 + 우측 컨텐츠 패널)
class _SettingsDialogContent extends StatefulWidget {
  const _SettingsDialogContent({required this.onPickProfileImage});

  final Future<void> Function(AuthProvider) onPickProfileImage;

  @override
  State<_SettingsDialogContent> createState() => _SettingsDialogContentState();
}

class _SettingsDialogContentState extends State<_SettingsDialogContent> {
  int _selectedSection = 0; // 0=프로필, 1=워크스페이스, 2=테마

  static const _sectionLabels = ['프로필', '워크스페이스', '테마', 'API 토큰'];
  static const _sectionIcons = [
    Icons.person_outline,
    Icons.group_outlined,
    Icons.palette_outlined,
    Icons.vpn_key_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, authProvider, themeProvider, _) {
        final user = authProvider.currentUser;
        final isAdmin = authProvider.isAdmin;

        // 섹션 목록 (관리자는 승인 관리 추가)
        final sections = List<String>.from(_sectionLabels);
        final icons = List<IconData>.from(_sectionIcons);
        if (isAdmin) {
          sections.add('승인 관리');
          icons.add(Icons.admin_panel_settings_outlined);
        }

        final safeSection = _selectedSection.clamp(0, sections.length - 1);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 520),
            child: GlassContainer(
              padding: const EdgeInsets.all(0),
              borderRadius: 20.0,
              blur: 25.0,
              gradientColors: [
                colorScheme.surface.withValues(alpha: isDarkMode ? 0.88 : 0.95),
                colorScheme.surface.withValues(alpha: isDarkMode ? 0.82 : 0.90),
              ],
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 좌측 네비게이션 패널 ──
                  Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 유저 요약 (아바타 + 이름)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                          child: Row(
                            children: [
                              user?.profileImageUrl != null &&
                                      user!.profileImageUrl!.isNotEmpty
                                  ? CircleAvatar(
                                      radius: 18,
                                      backgroundImage: NetworkImage(
                                        user.profileImageUrl!.startsWith('/')
                                            ? '${ApiClient.baseUrl}${user.profileImageUrl!}'
                                            : user.profileImageUrl!,
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          AvatarColor.getColorForUser(
                                            user?.id ?? '',
                                          ),
                                      child: Text(
                                        AvatarColor.getInitial(
                                          user?.username ?? 'U',
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.username ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      user?.email ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 8),
                        // 네비게이션 아이템
                        for (int i = 0; i < sections.length; i++)
                          _buildNavItem(
                            context,
                            colorScheme,
                            sections[i],
                            icons[i],
                            i == safeSection,
                            onTap: () {
                              if (sections[i] == '승인 관리') {
                                // 다이얼로그 닫고 AdminApprovalScreen으로 이동
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminApprovalScreen(),
                                  ),
                                );
                              } else {
                                setState(() => _selectedSection = i);
                              }
                            },
                          ),
                        const Spacer(),
                        Divider(
                          height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.15),
                        ),
                        // 로그아웃 버튼
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: TextButton.icon(
                            onPressed: () =>
                                _handleLogout(context, authProvider),
                            icon: Icon(
                              Icons.logout,
                              color: colorScheme.error,
                              size: 18,
                            ),
                            label: Text(
                              '로그아웃',
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 14,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 구분선
                  VerticalDivider(
                    width: 1,
                    color: colorScheme.outline.withValues(alpha: 0.15),
                  ),
                  // ── 우측 컨텐츠 패널 ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 헤더: 섹션 제목 + 닫기
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 8, 12),
                          child: Row(
                            children: [
                              Text(
                                sections[safeSection],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.15),
                        ),
                        // 섹션 컨텐츠
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: _buildSectionContent(
                              context,
                              colorScheme,
                              isDarkMode,
                              authProvider,
                              themeProvider,
                              safeSection,
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
        );
      },
    );
  }

  /// 좌측 네비게이션 아이템
  Widget _buildNavItem(
    BuildContext context,
    ColorScheme colorScheme,
    String label,
    IconData icon,
    bool isSelected, {
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 섹션 컨텐츠 라우팅
  Widget _buildSectionContent(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDarkMode,
    AuthProvider authProvider,
    ThemeProvider themeProvider,
    int section,
  ) {
    switch (section) {
      case 0:
        return _buildProfileSection(context, colorScheme, authProvider);
      case 1:
        return _buildWorkspaceSection(context, colorScheme);
      case 2:
        return _buildThemeSection(colorScheme, themeProvider);
      case 3:
        return const _ApiTokenSection();
      default:
        return _buildProfileSection(context, colorScheme, authProvider);
    }
  }

  // ── 섹션: 프로필 ──────────────────────────────
  Widget _buildProfileSection(
    BuildContext context,
    ColorScheme colorScheme,
    AuthProvider authProvider,
  ) {
    final user = authProvider.currentUser;
    if (user == null) return const SizedBox.shrink();

    final ghProvider = context.watch<GitHubProvider>();
    if (!ghProvider.userTokenStatusLoaded && !ghProvider.isLoading) {
      // 프로필 섹션 진입 시 1회 로드
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ghProvider.loadMyTokenStatus();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프로필 이미지 변경
        Center(
          child: _ProfileImageButton(
            colorScheme: colorScheme,
            currentUser: user,
            onTap: () => widget.onPickProfileImage(authProvider),
          ),
        ),
        const SizedBox(height: 24),
        _infoField(colorScheme, '사용자명', user.username),
        const SizedBox(height: 12),
        _infoField(colorScheme, '이메일', user.email),
        const SizedBox(height: 20),
        // 역할 뱃지
        if (user.isAdmin || user.isPM)
          Wrap(
            spacing: 8,
            children: [
              if (user.isAdmin)
                _roleBadge(colorScheme, '관리자', colorScheme.primary),
              if (user.isPM)
                _roleBadge(colorScheme, 'PM', colorScheme.secondary),
            ],
          ),
        const SizedBox(height: 20),
        _githubTokenCard(context, colorScheme, ghProvider),
        const SizedBox(height: 16),
        _MattermostSettingCard(colorScheme: colorScheme),
      ],
    );
  }

  Widget _githubTokenCard(
    BuildContext context,
    ColorScheme colorScheme,
    GitHubProvider ghProvider,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              Text(
                'GitHub 토큰',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (ghProvider.hasUserToken)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    '연결됨',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '미연결',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Private 레포 접근/태그 연동을 위해 필요합니다. 프로젝트 화면에서는 레포(owner/name)만 연결합니다.',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 10),
          if (ghProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                ghProvider.errorMessage!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ),
          _GitHubTokenEditor(colorScheme: colorScheme, ghProvider: ghProvider),
        ],
      ),
    );
  }

  Widget _infoField(ColorScheme colorScheme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _roleBadge(ColorScheme colorScheme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ── 섹션: 워크스페이스 ──────────────────────────
  Widget _buildWorkspaceSection(BuildContext context, ColorScheme colorScheme) {
    return Consumer<WorkspaceProvider>(
      builder: (context, wsProvider, _) {
        final ws = wsProvider.currentWorkspace;
        if (ws == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 48,
                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '선택된 워크스페이스가 없습니다',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final authProvider = context.read<AuthProvider>();
        final isOwner =
            ws.ownerId == (authProvider.currentUser?.id ?? '') ||
            authProvider.isAdmin;
        final inviteLink = wsProvider.buildInviteLink(ws.inviteToken);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 워크스페이스 정보
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10), // 워크스페이스 = 네모
                  ),
                  child: Center(
                    child: Text(
                      ws.name.isNotEmpty ? ws.name[0].toUpperCase() : 'W',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ws.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (ws.description != null && ws.description!.isNotEmpty)
                        Text(
                          ws.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 초대 링크
            Text(
              '초대 링크',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      inviteLink,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: '링크 복사',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('초대 링크가 복사되었습니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: ws.inviteToken));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('초대 코드가 복사되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.key, size: 16),
                  label: const Text('코드만 복사'),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _handleRegenerateToken(context, wsProvider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('코드 재발급'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // 멤버 목록
            Text(
              '멤버 (${wsProvider.currentMembers.length}명)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            if (wsProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...wsProvider.currentMembers.map((member) {
                final isMe =
                    member.userId == (authProvider.currentUser?.id ?? '');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AvatarColor.getColorForUser(
                      member.username,
                    ),
                    child: Text(
                      member.username.isNotEmpty
                          ? member.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        member.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '나',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    member.isOwner ? '오너' : '멤버',
                    style: TextStyle(
                      fontSize: 12,
                      color: member.isOwner
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  trailing: isOwner && !isMe && !member.isOwner
                      ? IconButton(
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: Colors.red,
                            size: 18,
                          ),
                          tooltip: '강퇴',
                          onPressed: () =>
                              _handleRemoveMember(context, wsProvider, member),
                        )
                      : null,
                );
              }),

            // 탈퇴 버튼 (오너가 아닌 멤버만)
            if (!isOwner) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLeaveWorkspace(context, wsProvider),
                  icon: const Icon(
                    Icons.exit_to_app,
                    color: Colors.red,
                    size: 18,
                  ),
                  label: const Text(
                    '워크스페이스 탈퇴',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ── 섹션: 테마 ──────────────────────────────
  Widget _buildThemeSection(
    ColorScheme colorScheme,
    ThemeProvider themeProvider,
  ) {
    const accentPresets = <Color>[
      Color(0xFFD86B27),
      Color(0xFF2C9271),
      Color(0xFF5C6BC0),
      Color(0xFFEC407A),
      Color(0xFF7E57C2),
      Color(0xFF00897B),
      Color(0xFF546E7A),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '앱 테마를 선택하세요',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => themeProvider.setLightMode(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: !themeProvider.isDarkMode
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !themeProvider.isDarkMode
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.3),
                      width: !themeProvider.isDarkMode ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.light_mode,
                        size: 36,
                        color: !themeProvider.isDarkMode
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '라이트',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: !themeProvider.isDarkMode
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: !themeProvider.isDarkMode
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => themeProvider.setDarkMode(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: themeProvider.isDarkMode
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.3),
                      width: themeProvider.isDarkMode ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.dark_mode,
                        size: 36,
                        color: themeProvider.isDarkMode
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '다크',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: themeProvider.isDarkMode
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: themeProvider.isDarkMode
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          '글자 크기',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'A',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            Expanded(
              child: Slider(
                value: themeProvider.textScale,
                min: 0.85,
                max: 1.25,
                divisions: 8,
                label: '${(themeProvider.textScale * 100).round()}%',
                onChanged: (v) => themeProvider.setTextScale(v),
              ),
            ),
            Text(
              'A',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '포인트 색상',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: accentPresets.map((c) {
            final selected =
                themeProvider.accentColor.toARGB32() == c.toARGB32();
            return GestureDetector(
              onTap: () => themeProvider.setAccentColor(c),
              child: Tooltip(
                message:
                    '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}',
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: selected ? colorScheme.onSurface : Colors.white24,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              '다크 팔레트',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(다크 모드에서 적용)',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildDarkPaletteSelector(context, themeProvider, colorScheme),
      ],
    );
  }

  Widget _buildDarkPaletteSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    ColorScheme colorScheme,
  ) {
    final presets = const <_DarkPalettePresetSpec>[
      _DarkPalettePresetSpec(
        preset: DarkPalettePreset.github,
        label: 'GitHub',
        subtitle: 'cool blue · 코드 친화',
        bg: Color(0xFF161B22),
        surface: Color(0xFF2D333B),
        highest: Color(0xFF444C56),
        text: Color(0xFFE6EDF3),
      ),
      _DarkPalettePresetSpec(
        preset: DarkPalettePreset.neutral,
        label: 'Neutral',
        subtitle: 'pure gray · 미니멀',
        bg: Color(0xFF18181B),
        surface: Color(0xFF2F2F33),
        highest: Color(0xFF52525B),
        text: Color(0xFFFAFAFA),
      ),
      _DarkPalettePresetSpec(
        preset: DarkPalettePreset.mild,
        label: 'Mild',
        subtitle: 'warm tint · 부드러움',
        bg: Color(0xFF1B1815),
        surface: Color(0xFF2A2624),
        highest: Color(0xFF3D3733),
        text: Color(0xFFEAE7E5),
      ),
      _DarkPalettePresetSpec(
        preset: DarkPalettePreset.slack,
        label: 'Slack',
        subtitle: 'deep canvas · 카드 부상',
        bg: Color(0xFF19171D),
        surface: Color(0xFF36373B),
        highest: Color(0xFF4F5258),
        text: Color(0xFFF8F8F8),
      ),
    ];
    final selected = themeProvider.darkPalette;
    return Row(
      children: [
        for (var i = 0; i < presets.length; i++) ...[
          Expanded(
            child: _DarkPaletteCard(
              spec: presets[i],
              selected: selected == presets[i].preset,
              onTap: () => themeProvider.setDarkPalette(presets[i].preset),
              colorScheme: colorScheme,
            ),
          ),
          if (i < presets.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  // ── 액션 핸들러 ──────────────────────────────

  Future<void> _handleLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    // root navigator를 미리 캡처 (pop 이전에 반드시 호출해야 함)
    final nav = Navigator.of(context, rootNavigator: true);

    // 설정 다이얼로그가 열린 상태에서 확인창을 띄움 (context 유효성 유지)
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: GlassContainer(
              padding: const EdgeInsets.all(0),
              borderRadius: 24.0,
              blur: 25.0,
              gradientColors: [
                cs.surface.withValues(alpha: 0.6),
                cs.surface.withValues(alpha: 0.5),
              ],
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '로그아웃',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '로그아웃하시겠습니까?',
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: cs.primary.withValues(alpha: 0.15),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            '로그아웃',
                            style: TextStyle(
                              color: cs.primary,
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
        );
      },
    );

    if (confirmed != true) return;

    await authProvider.logout();
    // 캡처한 root navigator로 모든 라우트 제거 후 로그인 화면으로 이동
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleRegenerateToken(
    BuildContext context,
    WorkspaceProvider wsProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대 코드 재발급'),
        content: const Text('기존 초대 링크는 더 이상 사용할 수 없게 됩니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('재발급'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await wsProvider.regenerateInviteToken();
  }

  Future<void> _handleRemoveMember(
    BuildContext context,
    WorkspaceProvider wsProvider,
    WorkspaceMember member,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 강퇴'),
        content: Text('${member.username}님을 워크스페이스에서 강퇴하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
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

  Future<void> _handleLeaveWorkspace(
    BuildContext context,
    WorkspaceProvider wsProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('워크스페이스 탈퇴'),
        content: const Text('워크스페이스에서 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await wsProvider.leaveWorkspace();
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _GitHubTokenEditor extends StatefulWidget {
  final ColorScheme colorScheme;
  final GitHubProvider ghProvider;

  const _GitHubTokenEditor({
    required this.colorScheme,
    required this.ghProvider,
  });

  @override
  State<_GitHubTokenEditor> createState() => _GitHubTokenEditorState();
}

// ── Mattermost 설정 카드 ─────────────────────────────────────────────────────

class _MattermostSettingCard extends StatefulWidget {
  final ColorScheme colorScheme;

  const _MattermostSettingCard({required this.colorScheme});

  @override
  State<_MattermostSettingCard> createState() => _MattermostSettingCardState();
}

class _MattermostSettingCardState extends State<_MattermostSettingCard> {
  final _service = MattermostService();
  final _urlCtrl = TextEditingController();
  bool _hasSetting = false;
  bool _isEnabled = false;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final setting = await _service.getMySetting();
      if (!mounted) return;
      setState(() {
        _hasSetting = setting.hasSetting;
        _isEnabled = setting.isEnabled;
        _urlCtrl.text = setting.webhookUrl;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _service.upsertMySetting(webhookUrl: url, isEnabled: _isEnabled);
      if (!mounted) return;
      setState(() {
        _hasSetting = true;
        _isEditing = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mattermost 설정이 저장되었습니다')),
      );
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _isEnabled = value);
    if (_hasSetting) {
      try {
        await _service.upsertMySetting(webhookUrl: _urlCtrl.text.trim(), isEnabled: value);
      } catch (_) {}
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mattermost 설정 삭제'),
        content: const Text('저장된 웹훅 설정을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: widget.colorScheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _service.deleteMySetting();
    if (!mounted) return;
    setState(() {
      _hasSetting = false;
      _isEnabled = false;
      _urlCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              Text(
                'Mattermost 알림',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (_hasSetting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '연결됨',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade700),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '미연결',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '작업 할당, 상태 변경, 코멘트 등의 알림을 Mattermost로 받습니다.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 10),
          if (!_isLoading) ...[
            // 활성화 토글 (설정이 있을 때만)
            if (_hasSetting) ...[
              Row(
                children: [
                  Text(
                    '알림 활성화',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isEnabled,
                    onChanged: _toggleEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // 연결된 상태 + 편집 아님
            if (_hasSetting && !_isEditing)
              Row(
                children: [
                  Text(
                    '웹훅이 저장되어 있습니다.',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit, size: 13),
                      label: const Text('편집', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: OutlinedButton(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
                      ),
                      child: const Text('삭제', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              )
            // 미연결 또는 편집 모드
            else if (!_hasSetting || _isEditing)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      decoration: InputDecoration(
                        labelText: '웹훅 URL',
                        hintText: 'https://chat.example.com/hooks/...',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('저장'),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('취소'),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GitHubTokenEditorState extends State<_GitHubTokenEditor> {
  final _ctrl = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final ghProvider = widget.ghProvider;

    // 연결됨 상태이고 편집 모드가 아니면 입력란 숨김
    if (ghProvider.hasUserToken && !_isEditing) {
      return Row(
        children: [
          Text(
            '토큰이 저장되어 있습니다.',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, size: 13),
              label: const Text('편집', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: ghProvider.isLoading
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('GitHub 토큰 삭제'),
                          content: const Text('저장된 GitHub 토큰을 삭제할까요?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('취소'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error,
                              ),
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ghProvider.deleteMyToken();
                      }
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
              ),
              child: const Text('삭제', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      );
    }

    // 미연결 상태이거나 편집 모드일 때 입력란 표시
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Personal Access Token',
              hintText: 'ghp_…',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: ghProvider.isLoading
              ? null
              : () async {
                  final token = _ctrl.text.trim();
                  if (token.isEmpty) return;
                  await ghProvider.upsertMyToken(token);
                  if (mounted) {
                    _ctrl.clear();
                    setState(() => _isEditing = false);
                  }
                },
          child: ghProvider.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
        if (_isEditing) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => setState(() {
              _isEditing = false;
              _ctrl.clear();
            }),
            child: const Text('취소'),
          ),
        ],
      ],
    );
  }
}

// ── API 토큰 섹션 ────────────────────────────────────────────────────────────

class _ApiTokenSection extends StatefulWidget {
  const _ApiTokenSection();

  @override
  State<_ApiTokenSection> createState() => _ApiTokenSectionState();
}

class _ApiTokenSectionState extends State<_ApiTokenSection> {
  final _service = ApiTokenService();
  List<ApiTokenInfo> _tokens = [];
  bool _loading = true;
  String? _newlyCreatedToken; // 방금 발급된 원문 토큰 (딱 한 번 표시)

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    setState(() => _loading = true);
    try {
      final tokens = await _service.listTokens();
      if (mounted) setState(() => _tokens = tokens);
    } catch (_) {
      // 에러 무시 — 빈 목록으로 표시
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showGenerateDialog() async {
    final nameCtrl = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 API 토큰 발급'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '토큰 이름',
            hintText: 'ex) request-issue-app',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('발급'),
          ),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    try {
      final result = await _service.generateToken(nameCtrl.text.trim());
      setState(() => _newlyCreatedToken = result['token'] as String);
      await _loadTokens();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('토큰 발급 실패: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _revokeToken(ApiTokenInfo token) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('토큰 폐기'),
        content: Text('"${token.name}" 토큰을 폐기하면 해당 토큰으로 연동된 서비스가 즉시 인증 불가 상태가 됩니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('폐기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.revokeToken(token.id);
      await _loadTokens();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('토큰 폐기 실패: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '외부 서비스 연동용 API 토큰을 발급하고 관리합니다.',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Base URL: http://서버주소:4000/api/ri',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 16),

        // 방금 발급된 토큰 표시 배너
        if (_newlyCreatedToken != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '토큰이 발급되었습니다. 지금만 확인 가능합니다.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _newlyCreatedToken!,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 18,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _newlyCreatedToken!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('토큰이 클립보드에 복사되었습니다'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      tooltip: '복사',
                    ),
                    IconButton(
                      iconSize: 18,
                      onPressed: () => setState(() => _newlyCreatedToken = null),
                      icon: Icon(Icons.close, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      tooltip: '닫기',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 토큰 목록 헤더
        Row(
          children: [
            Text(
              '발급된 토큰',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _showGenerateDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('새 토큰'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_tokens.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '발급된 토큰이 없습니다',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          )
        else
          ...(_tokens.map((token) => _TokenListItem(
            token: token,
            onRevoke: () => _revokeToken(token),
            formatDate: _formatDate,
          ))),
      ],
    );
  }
}

class _TokenListItem extends StatelessWidget {
  const _TokenListItem({
    required this.token,
    required this.onRevoke,
    required this.formatDate,
  });

  final ApiTokenInfo token;
  final VoidCallback onRevoke;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.vpn_key, size: 16, color: colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${token.tokenPrefix}••••••••  ·  ${formatDate(token.createdAt)} 발급',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              iconSize: 18,
              onPressed: onRevoke,
              icon: Icon(Icons.delete_outline, color: colorScheme.error.withValues(alpha: 0.7)),
              tooltip: '폐기',
            ),
          ],
        ),
      ),
    );
  }
}

/// 다크 팔레트 카드 표시용 스펙
class _DarkPalettePresetSpec {
  final DarkPalettePreset preset;
  final String label;
  final String subtitle;
  final Color bg;
  final Color surface;
  final Color highest;
  final Color text;
  const _DarkPalettePresetSpec({
    required this.preset,
    required this.label,
    required this.subtitle,
    required this.bg,
    required this.surface,
    required this.highest,
    required this.text,
  });
}

/// 다크 팔레트 선택 카드 — mini swatch + 라벨 + 선택 표시
class _DarkPaletteCard extends StatelessWidget {
  final _DarkPalettePresetSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _DarkPaletteCard({
    required this.spec,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 미니 시안 — 4 layer 스트라이프 + 본문 가짜 텍스트
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 56,
                color: spec.bg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 6, color: spec.bg),
                    Container(
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: spec.surface,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Container(width: 32, height: 3, color: spec.text),
                          Container(width: 22, height: 3, color: spec.text.withValues(alpha: 0.55)),
                        ],
                      ),
                    ),
                    Container(
                      height: 12,
                      margin: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                      color: spec.highest,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    spec.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              spec.subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
