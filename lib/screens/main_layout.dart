import 'dart:async';
import 'package:flutter/material.dart';
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
import '../models/notification.dart' as models;
import '../models/project.dart';
import '../models/user.dart';
import '../widgets/app_title_bar.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'kanban_screen.dart';
import 'calendar_screen.dart';
import 'gantt_chart_screen.dart';
import 'quick_task_screen.dart';
import 'admin_approval_screen.dart';
import 'notification_screen.dart';
import 'chat_screen.dart';

/// 메인 레이아웃 - Slack 스타일 (왼쪽 사이드바 + 오른쪽 컨텐츠)
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _selectedIndex = 0; // 선택된 메뉴 인덱스
  WebSocketService? _webSocketService; // WebSocket 서비스

  // 메뉴 항목 정의 (상태로 관리하여 드래그로 순서 변경 가능)
  List<MenuItem> _menuItems = [
    MenuItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '홈',
      index: 0,
    ),
    MenuItem(
      icon: Icons.view_kanban_outlined,
      selectedIcon: Icons.view_kanban,
      label: '칸반 보드',
      index: 1,
    ),
    MenuItem(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: '달력',
      index: 2,
    ),
    MenuItem(
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline,
      label: '간트 차트',
      index: 3,
    ),
    MenuItem(
      icon: Icons.add_task_outlined,
      selectedIcon: Icons.add_task,
      label: '빠른 추가',
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
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 생명주기 관찰자 등록
    _loadMenuItems();
    // 로그인 시 사용자 정보를 ProjectProvider에 전달
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateProjectProviderUserInfo();
      _initializeNotificationService(); // 알림 서비스 초기화
      _connectWebSocket(); // WebSocket 연결
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 생명주기 관찰자 제거
    _webSocketService?.disconnect(); // WebSocket 연결 해제
    super.dispose();
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
    
    _webSocketService = WebSocketService();
    
    // 이벤트 핸들러 설정
    _webSocketService!.onEvent = (eventType, data) {
      print('[WebSocket] 이벤트 수신: $eventType');
      _handleWebSocketEvent(eventType, data);
    };
    
    await _webSocketService!.connect();
  }
  
  /// 알림 서비스 초기화 및 알림 로드
  Future<void> _initializeNotificationService() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      await notificationProvider.loadNotifications(userId: authProvider.currentUser!.id);
    }
  }

  /// WebSocket 이벤트 처리
  Future<void> _handleWebSocketEvent(String eventType, Map<String, dynamic> data) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
      return;
    }
    
    final user = authProvider.currentUser!;
    
    switch (eventType) {
      case 'project_created':
      case 'project_updated':
      case 'team_member_added':
        // 프로젝트 목록 새로고침
        await projectProvider.loadProjects(
          userId: user.id,
          isAdmin: authProvider.isAdmin,
          isPM: authProvider.isPM,
        );
        
        // 팀원 추가 시 인앱 토스트 표시
        if (eventType == 'team_member_added' && data['user_id'] == user.id) {
          final projectId = data['project_id'] as String?;
          try {
            final project = projectProvider.projects.firstWhere((p) => p.id == projectId);
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
        await taskProvider.loadTasks();
        
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
        // 댓글이 추가되었으므로 태스크 목록 새로고침
        await taskProvider.loadTasks();

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

        final senderUsername = data['sender_username'] as String?;
        final content = data['content'] as String?;
        if (senderUsername != null && content != null) {
          _showInAppToast(
            title: '$senderUsername님의 메시지',
            message: content.length > 50 ? '${content.substring(0, 50)}...' : content,
            type: models.NotificationType.taskCommentAdded,
          );
        }
        break;

      case 'chat_room_created':
        final chatProvider2 = Provider.of<ChatProvider>(context, listen: false);
        chatProvider2.handleRoomCreated(data);
        break;
    }

    // 백엔드에서 알림 목록 동기화 (중복 로컬 생성 대신 서버 데이터 기반)
    await notificationProvider.loadNotifications(userId: user.id);
  }

  /// 인앱 토스트 알림 표시 (Slack/Notion 스타일)
  void _showInAppToast({
    required String title,
    required String message,
    required models.NotificationType type,
    String? taskId,
  }) {
    if (!mounted) return;
    
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
      case models.NotificationType.taskOptionChanged:
        accentColor = const Color(0xFF8B5CF6);
        icon = Icons.settings;
        break;
      case models.NotificationType.taskCommentAdded:
        accentColor = const Color(0xFF10B981);
        icon = Icons.comment;
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
                color: accentColor.withOpacity(0.2),
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
                      color: Colors.white.withOpacity(0.8),
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
            ? const Color(0xFF1E293B)
            : const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '보기',
          textColor: accentColor,
          onPressed: () {
            // 알림 화면으로 이동
            final notifIndex = _menuItems.indexWhere((m) => m.label == '알림');
            if (notifIndex != -1) {
              setState(() {
                _selectedIndex = notifIndex;
              });
            }
          },
        ),
      ),
    );
  }


  /// ProjectProvider에 사용자 정보 업데이트
  void _updateProjectProviderUserInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      final user = authProvider.currentUser!;
      
      // 이전 사용자 데이터 초기화
      projectProvider.setUserInfo(
        user.id,
        authProvider.isAdmin,
        authProvider.isPM,
      );
      
      // 프로젝트 목록 다시 로드 (필터링 적용)
      await projectProvider.loadProjects(
        userId: user.id,
        isAdmin: authProvider.isAdmin,
        isPM: authProvider.isPM,
      );
      
      // 태스크 목록도 다시 로드
      await taskProvider.loadTasks();
    }
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
        icon: Icons.view_kanban_outlined,
        selectedIcon: Icons.view_kanban,
        label: '칸반 보드',
        index: 1,
      ),
      MenuItem(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: '달력',
        index: 2,
      ),
      MenuItem(
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline,
        label: '간트 차트',
        index: 3,
      ),
      MenuItem(
        icon: Icons.add_task_outlined,
        selectedIcon: Icons.add_task,
        label: '빠른 추가',
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
    ];

    // SharedPreferences에서 저장된 순서 로드
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('menu_item_order');
      if (savedOrder != null && savedOrder.length == defaultItems.length) {
        // 저장된 순서대로 재정렬
        final orderedItems = <MenuItem>[];
        for (final label in savedOrder) {
          final item = defaultItems.firstWhere(
            (item) => item.label == label,
            orElse: () => defaultItems[0],
          );
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
        if (mounted) {
          setState(() {
            _menuItems = orderedItems;
          });
        }
        return;
      }
    } catch (e) {
      // 에러 발생 시 기본 순서 사용
    }

    if (mounted) {
      setState(() {
        _menuItems = defaultItems;
      });
    }
  }

  /// 메뉴 아이템 순서 저장
  Future<void> _saveMenuItemsOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = _menuItems.map((item) => item.label).toList();
      await prefs.setStringList('menu_item_order', order);
    } catch (e) {
      // 에러 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);

    // 메뉴 아이템 (관리자 메뉴는 사이드바에서 제거, 대시보드 버튼으로 대체)
    final menuItems = List<MenuItem>.from(_menuItems);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final shellColor = isDarkMode
        ? const Color(0xFF0B0E14)
        : const Color(0xFFEEF2FF); // Indigo 50 — 은은한 인디고 톤
    
    return Scaffold(
      backgroundColor: shellColor,
      body: Column(
        children: [
          // 커스텀 타이틀바
          AppTitleBar(
            backgroundColor: shellColor,
            leadingWidth: 75,
            extraHeight: 8,
          ),
          // 메인 컨텐츠
          Expanded(
            child: Container(
              color: shellColor,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽 사이드바 (L자 형태로 타이틀바와 이어짐)
                  _buildSidebar(
                    context,
                    menuItems,
                    colorScheme,
                    authProvider,
                    isDarkMode,
                    shellColor,
                  ),
                  // 오른쪽 영역 (팀원 + 메인 - 같은 영역)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF161B2E) : null,
                          gradient: isDarkMode ? null : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFAFAFF), // 아주 연한 인디고 화이트
                              Color(0xFFF5F3FF), // Violet 50
                              Color(0xFFEEF2FF), // Indigo 50
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: isDarkMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 30,
                                    offset: const Offset(0, 18),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withOpacity(0.06),
                                    blurRadius: 40,
                                    offset: const Offset(0, 20),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Column(
                            children: [
                              // 프로젝트 선택 바 (최상단)
                              _buildProjectInfoBar(context),
                              // 하단 영역
                              Expanded(
                                child: _isDashboardSelected()
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 팀원 사이드바 (왼쪽)
                                          _buildTeamMemberSidebar(context, colorScheme, isDarkMode),
                                          // 구분선 (그림자 효과 포함 - 왼쪽으로만)
                                          Container(
                                            width: 1,
                                            decoration: BoxDecoration(
                                              color: colorScheme.outline.withOpacity(0.1),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(isDarkMode ? 0.45 : 0.14),
                                                  blurRadius: 8,
                                                  offset: const Offset(-1, 0),
                                                  spreadRadius: 0,
                                                ),
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.08),
                                                  blurRadius: 4,
                                                  offset: const Offset(-2, 0),
                                                  spreadRadius: 0,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // 메인 컨텐츠 (오른쪽)
                                          Expanded(
                                            child: _buildContent(context),
                                          ),
                                        ],
                                      )
                                    : _buildContent(context),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  /// 사이드바 위젯
  Widget _buildSidebar(
    BuildContext context,
    List<MenuItem> menuItems,
    ColorScheme colorScheme,
    AuthProvider authProvider,
    bool isDarkMode,
    Color shellColor,
  ) {
    return Container(
      width: 75,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.transparent),
        boxShadow: const [],
      ),
      child: Column(
          children: [
            // 유저 프로필 (상단)
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 8.0, right: 8.0),
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
                    } else if (_selectedIndex == newIndex && oldIndex < newIndex) {
                      _selectedIndex = newIndex - 1;
                    } else if (_selectedIndex == newIndex && oldIndex > newIndex) {
                      _selectedIndex = newIndex + 1;
                    } else if (_selectedIndex > oldIndex && _selectedIndex <= newIndex) {
                      _selectedIndex -= 1;
                    } else if (_selectedIndex < oldIndex && _selectedIndex >= newIndex) {
                      _selectedIndex += 1;
                    }
                  });
                  _saveMenuItemsOrder();
                },
                children: _menuItems.map((item) {
                  return _buildMenuItem(context, item, colorScheme, key: ValueKey(item.label));
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
                              color: colorScheme.onSurface.withOpacity(0.7),
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '설정',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 로그아웃 버튼 - 메뉴 아이템과 동일한 구조
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.2),
                          builder: (context) {
                            final dialogColorScheme = Theme.of(context).colorScheme;
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
                                    dialogColorScheme.surface.withOpacity(0.6),
                                    dialogColorScheme.surface.withOpacity(0.5),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '로그아웃',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: dialogColorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '로그아웃하시겠습니까?',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: dialogColorScheme.onSurface.withOpacity(0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text(
                                                '취소',
                                                style: TextStyle(
                                                  color: dialogColorScheme.onSurface.withOpacity(0.7),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              style: TextButton.styleFrom(
                                                backgroundColor: dialogColorScheme.primary.withOpacity(0.2),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              ),
                                              child: Text(
                                                '로그아웃',
                                                style: TextStyle(
                                                  color: dialogColorScheme.primary,
                                                  fontSize: 14,
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

                        if (confirmed == true && context.mounted) {
                          await authProvider.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          }
                        }
                      },
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
                              Icons.logout,
                              color: colorScheme.onSurface.withOpacity(0.7),
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '로그아웃',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withOpacity(0.7),
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
          ? 'http://localhost:8000${user.profileImageUrl!}'
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
        backgroundColor: AvatarColor.getColorForUser(user?.id ?? user?.username ?? 'U'),
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
          ? 'http://localhost:8000${member.profileImageUrl!}'
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
    final projectProvider = Provider.of<ProjectProvider>(context);
    final currentProject = projectProvider.currentProject;
    final authProvider = Provider.of<AuthProvider>(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? colorScheme.surface.withOpacity(0.7)
            : Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
        ),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        children: [
          // 프로젝트 드롭다운 버튼
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentProject != null) ...[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: currentProject.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          currentProject.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.folder_outlined,
                          size: 20,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '프로젝트를 선택하세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_drop_down,
                        color: colorScheme.onSurface.withOpacity(0.7),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            itemBuilder: (BuildContext context) {
              final items = <PopupMenuEntry<String>>[];
              
              // 프로젝트 목록
              for (var project in projectProvider.projects) {
                items.add(
                  PopupMenuItem<String>(
                    value: project.id,
                    child: GestureDetector(
                      // 오른쪽 클릭 감지
                      onSecondaryTapDown: (details) {
                        // 드롭다운 메뉴 닫기
                        Navigator.of(context).pop();
                        // 컨텍스트 메뉴 표시
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _showProjectContextMenu(
                            context,
                            project,
                            projectProvider,
                            authProvider,
                            details.globalPosition,
                          );
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: project.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            project.name,
                            style: TextStyle(
                              fontWeight: currentProject?.id == project.id
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: currentProject?.id == project.id
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                          if (currentProject?.id == project.id) ...[
                            const Spacer(),
                            Icon(
                              Icons.check,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              // 구분선과 새 프로젝트 버튼 (PM/Admin만)
              if (authProvider.isPM || authProvider.isAdmin) {
                items.add(const PopupMenuDivider());
                items.add(
                  PopupMenuItem<String>(
                    value: '__create_new__',
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '새 프로젝트',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return items;
            },
            onSelected: (String value) {
              if (value == '__create_new__') {
                _showCreateProjectDialog(context);
              } else {
                projectProvider.setCurrentProject(value);
              }
            },
          ),
        ],
      ),
    );
  }


  /// 프로젝트 컨텍스트 메뉴 표시 (오른쪽 클릭)
  void _showProjectContextMenu(
    BuildContext context,
    Project project,
    ProjectProvider projectProvider,
    AuthProvider authProvider,
    Offset position,
  ) {
    final size = MediaQuery.of(context).size;
    
    // PM 또는 Admin만 삭제 가능
    if (!authProvider.isPM && !authProvider.isAdmin) {
      return;
    }
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        size.width - position.dx,
        size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red,
              ),
              const SizedBox(width: 12),
              Text(
                '프로젝트 삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          onTap: () {
            // 메뉴가 닫힌 후에 다이얼로그 표시
            Future.delayed(const Duration(milliseconds: 100), () {
              _showDeleteProjectDialog(context, project, projectProvider);
            });
          },
        ),
      ],
    );
  }

  /// 프로젝트 삭제 확인 다이얼로그
  void _showDeleteProjectDialog(
    BuildContext context,
    Project project,
    ProjectProvider projectProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            '프로젝트 삭제',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            '${project.name} 프로젝트를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final success = await projectProvider.deleteProject(project.id);
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${project.name} 프로젝트가 삭제되었습니다'),
                        backgroundColor: colorScheme.primary,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          projectProvider.errorMessage ?? '프로젝트 삭제에 실패했습니다',
                        ),
                        backgroundColor: colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: Text(
                '삭제',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 프로젝트 생성 다이얼로그
  void _showCreateProjectDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final nameController = TextEditingController();
    
    // PM 권한 체크
    if (!authProvider.isPM && !authProvider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('프로젝트 생성 권한이 없습니다. PM 권한이 필요합니다.'),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '새 프로젝트',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '프로젝트 이름',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '취소',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isNotEmpty) {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final user = authProvider.currentUser;
                          final success = await projectProvider.createProject(
                            name: nameController.text.trim(),
                            isPM: authProvider.isPM || authProvider.isAdmin,
                            creatorUserId: user?.id, // 프로젝트 생성자 ID 전달
                          );
                          if (context.mounted) {
                            if (success) {
                              Navigator.of(context).pop();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(projectProvider.errorMessage ?? '프로젝트 생성에 실패했습니다.'),
                                  backgroundColor: colorScheme.error,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('생성'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 메뉴 항목 위젯
  Widget _buildMenuItem(
    BuildContext context,
    MenuItem item,
    ColorScheme colorScheme, {
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
                color: Colors.transparent,
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
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.7),
                        size: 24,
                      ),
                      // 알림/채팅 뱃지 (읽지 않은 항목이 있을 때만)
                      if ((isNotificationItem || isChatItem) && unreadCount > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF0B0E14)
                                    : const Color(0xFFEEF2FF),
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
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.7),
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
                Icon(
                  Icons.people,
                  color: colorScheme.primary,
                  size: 20,
                ),
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
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        if (authProvider.isPM || authProvider.isAdmin) {
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
                  final latestProject = provider.currentProject ?? currentProject;
                  return _buildTeamMemberList(context, latestProject, colorScheme, projectProvider);
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
      key: ValueKey('team_members_${currentProject?.id}_${currentProject?.teamMemberIds?.length ?? 0}'),
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
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  '팀원이 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    // 관리자나 PM만 추가 안내 메시지 표시
                    if (authProvider.isPM || authProvider.isAdmin) {
                      return Column(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            '+ 버튼을 눌러\n팀원을 추가하세요',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.5),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: colorScheme.surface.withOpacity(0.3),
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
                                  if (member.isPM) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: colorScheme.primary.withOpacity(0.5),
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
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            // 관리자나 PM만 제거 버튼 표시
                            if (authProvider.isPM || authProvider.isAdmin) {
                              return IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.red.withOpacity(0.7),
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
      // 승인된 사용자 목록 가져오기 (PM도 사용 가능)
      final approvedUsers = await authService.getApprovedUsers();
      // 프로젝트 팀원에 포함된 사용자만 필터링
      final teamMembers = approvedUsers
          .where((u) => currentProject.teamMemberIds.contains(u.id))
          .toList();
      
      // PM을 먼저 정렬
      teamMembers.sort((a, b) {
        if (a.isPM && !b.isPM) return -1;
        if (!a.isPM && b.isPM) return 1;
        return 0;
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // PM 권한 체크
    if (!authProvider.isPM && !authProvider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('팀원 초대 권한이 없습니다. PM 권한이 필요합니다.'),
          backgroundColor: colorScheme.error,
        ),
      );
      return;
    }
    
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
                    colorScheme.surface.withOpacity(0.6),
                    colorScheme.surface.withOpacity(0.5),
                  ],
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
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
                  colorScheme.surface.withOpacity(0.6),
                  colorScheme.surface.withOpacity(0.5),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                                  color: colorScheme.onSurface.withOpacity(0.7),
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
                                    await projectProvider.addTeamMember(
                                      currentProject.id,
                                      user.id,
                                    );
                                    Navigator.of(context).pop();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${user.username}님이 팀에 추가되었습니다'),
                                          backgroundColor: colorScheme.primary,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
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
      // 승인된 사용자 목록 가져오기 (PM도 사용 가능)
      final approvedUsers = await authService.getApprovedUsers();
      // 이미 팀원에 포함된 사용자는 제외
      return approvedUsers
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
              colorScheme.surface.withOpacity(0.6),
              colorScheme.surface.withOpacity(0.5),
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
                    color: colorScheme.onSurface.withOpacity(0.8),
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
                        backgroundColor: colorScheme.error.withOpacity(0.2),
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
      final updatedMemberIds =
          currentProject.teamMemberIds.where((id) => id != userId).toList();
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
    // 현재 선택된 메뉴 아이템의 label을 기반으로 화면 반환
    if (_selectedIndex >= 0 && _selectedIndex < _menuItems.length) {
      final selectedItem = _menuItems[_selectedIndex];
      return _getScreenByLabel(selectedItem.label);
    }
    return const DashboardScreen();
  }

  /// 현재 선택된 화면이 대시보드인지 확인
  bool _isDashboardSelected() {
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
      case '알림':
        return const NotificationScreen();
      case '채팅':
        return const ChatScreen();
      case '관리자 승인':
        return const AdminApprovalScreen();
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

  /// 설정 다이얼로그
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Consumer2<AuthProvider, ThemeProvider>(
            builder: (context, authProvider, themeProvider, _) {
              return GlassContainer(
                padding: const EdgeInsets.all(0),
                borderRadius: 24.0,
                blur: 25.0,
                gradientColors: [
                  colorScheme.surface.withOpacity(0.6),
                  colorScheme.surface.withOpacity(0.5),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                    maxHeight: 600,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '설정',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                              onPressed: () => Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // 사용자 정보
                        if (authProvider.currentUser != null) ...[
                      Row(
                        children: [
                          _ProfileImageButton(
                            colorScheme: colorScheme,
                            currentUser: authProvider.currentUser!,
                            onTap: () => _pickAndUploadProfileImage(authProvider),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authProvider.currentUser!.username,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  authProvider.currentUser!.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (authProvider.currentUser!.isAdmin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '관리자',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    if (authProvider.currentUser!.isPM)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'PM',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.secondary,
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
                      const SizedBox(height: 32),
                    ],
                    // 테마 설정
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.onSurface.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                size: 20,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '테마 설정',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => themeProvider.setLightMode(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !themeProvider.isDarkMode
                                          ? colorScheme.primary.withOpacity(0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: !themeProvider.isDarkMode
                                            ? colorScheme.primary
                                            : colorScheme.onSurface.withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.light_mode,
                                          color: !themeProvider.isDarkMode
                                              ? colorScheme.primary
                                              : colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '라이트',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: !themeProvider.isDarkMode
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: !themeProvider.isDarkMode
                                                ? colorScheme.primary
                                                : colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => themeProvider.setDarkMode(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: themeProvider.isDarkMode
                                          ? colorScheme.primary.withOpacity(0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: themeProvider.isDarkMode
                                            ? colorScheme.primary
                                            : colorScheme.onSurface.withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.dark_mode,
                                          color: themeProvider.isDarkMode
                                              ? colorScheme.primary
                                              : colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '다크',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: themeProvider.isDarkMode
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: themeProvider.isDarkMode
                                                ? colorScheme.primary
                                                : colorScheme.onSurface.withOpacity(0.7),
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
                    const SizedBox(height: 24),
                    // 로그아웃 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop(); // 설정 다이얼로그 닫기
                          final confirmed = await showDialog<bool>(
                            context: dialogContext,
                            barrierColor: Colors.black.withOpacity(0.2),
                            builder: (logoutDialogContext) {
                              final dialogColorScheme = Theme.of(logoutDialogContext).colorScheme;
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
                                      dialogColorScheme.surface.withOpacity(0.6),
                                      dialogColorScheme.surface.withOpacity(0.5),
                                    ],
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '로그아웃',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: dialogColorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '로그아웃하시겠습니까?',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: dialogColorScheme.onSurface.withOpacity(0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () => Navigator.of(logoutDialogContext).pop(false),
                                                child: Text(
                                                  '취소',
                                                  style: TextStyle(
                                                    color: dialogColorScheme.onSurface.withOpacity(0.7),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton(
                                                onPressed: () => Navigator.of(logoutDialogContext).pop(true),
                                                style: TextButton.styleFrom(
                                                  backgroundColor: dialogColorScheme.primary.withOpacity(0.2),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                ),
                                                child: Text(
                                                  '로그아웃',
                                                  style: TextStyle(
                                                    color: dialogColorScheme.primary,
                                                    fontSize: 14,
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

                          if (confirmed == true && dialogContext.mounted) {
                            await authProvider.logout();
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pushReplacement(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            }
                          }
                        },
                        icon: Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          '로그아웃',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
            },
          ),
        );
      },
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
                            ? 'http://localhost:8000${widget.currentUser.profileImageUrl!}'
                            : widget.currentUser.profileImageUrl!,
                      ),
                    )
                  : CircleAvatar(
                      radius: 30,
                      backgroundColor: AvatarColor.getColorForUser(widget.currentUser.id),
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
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : _hovered
                            ? [
                                BoxShadow(
                                  color: widget.colorScheme.primary.withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : null,
                  ),
                  child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
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


