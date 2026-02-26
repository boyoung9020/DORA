import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/workspace_provider.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';
import 'admin_approval_screen.dart';
import 'task_detail_screen.dart';

/// ??쒕낫???붾㈃ - ???붾㈃
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<User>>? _usersFuture;
  final PageController _projectProgressPageController = PageController();
  int _projectProgressPage = 0;
  final AiService _aiService = AiService();
  String? _aiSummary;
  bool _aiLoading = false;
  String? _aiError;
  DateTime? _aiGeneratedAt;
  String? _lastAiScopeKey;
  String? _lastTaskRefreshKey;

  @override
  void initState() {
    super.initState();
    _usersFuture = AuthService().getAllUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastAiScopeKey = _currentAiScopeKey();
      _loadAISummary(); // 캐시 있으면 즉시 표시, 없으면 API 호출
    });
  }

  @override
  void dispose() {
    _projectProgressPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 대시보드는 전체 태스크를 표시하므로 user/workspace 변경 시에만 재로드
    // ProjectProvider는 의존성으로 등록하지 않음 (프로젝트 전환마다 불필요한 재로드 방지)
    final workspaceId =
        Provider.of<WorkspaceProvider>(context).currentWorkspaceId ?? '';
    final userId = Provider.of<AuthProvider>(context).currentUser?.id ?? '';
    final scopeKey = '$userId|$workspaceId';

    if (_lastTaskRefreshKey != scopeKey) {
      _lastTaskRefreshKey = scopeKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<TaskProvider>().loadAllTasks();
      });
    }

    if (_lastAiScopeKey != null && _lastAiScopeKey != scopeKey) {
      _lastAiScopeKey = scopeKey;
      _loadAISummary();
    }
  }

  Future<void> _loadAISummary({bool forceRefresh = false}) async {
    if (!mounted) return;
    final workspaceId = context.read<WorkspaceProvider>().currentWorkspaceId;
    final userId = context.read<AuthProvider>().currentUser?.id;

    // 캐시 우선 로딩: 로딩 상태 표시 없이 즉시 캐시 데이터 표시
    if (!forceRefresh) {
      final cached = await _aiService.getCachedSummary(
        userId: userId,
        workspaceId: workspaceId,
        projectId: null,
      );
      if (cached != null && mounted) {
        setState(() {
          _aiSummary = cached.summary.isNotEmpty ? cached.summary : null;
          _aiGeneratedAt = cached.generatedAt ?? DateTime.now();
          _aiError = null;
        });
        return; // 캐시 히트 - API 호출 불필요
      }
    }

    // 캐시 없음 또는 강제 새로고침 - 로딩 상태 표시 후 API 호출
    if (!mounted) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });

    try {
      final result = await _aiService.getSummary(
        workspaceId: workspaceId,
        projectId: null,
        userId: userId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _aiSummary = result.summary.isNotEmpty ? result.summary : null;
        _aiGeneratedAt = result.generatedAt ?? DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiError = 'AI 요약을 불러오지 못했습니다';
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiLoading = false;
        });
      }
    }
  }

  String _formatAiGeneratedAt(DateTime dateTime) {
    final meridiem = dateTime.hour < 12 ? '오전' : '오후';
    var hour = dateTime.hour % 12;
    if (hour == 0) hour = 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$meridiem $hour:$minute';
  }

  String _currentAiScopeKey() {
    final workspaceId =
        context.read<WorkspaceProvider>().currentWorkspaceId ?? '';
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    return '$userId|$workspaceId';
  }

  Widget _buildAISummaryCard(
    BuildContext context,
    ColorScheme colorScheme, {
    double? maxBodyHeight,
  }) {
    final gradientColors = colorScheme.brightness == Brightness.dark
        ? const [Color(0xFF232840), Color(0xFF1D2236)]
        : const [Color(0xFFF3EDFF), Color(0xFFE9F0FF)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF3B30),
            Color(0xFFFF9500),
            Color(0xFFFFCC00),
            Color(0xFF34C759),
            Color(0xFF007AFF),
            Color(0xFF5856D6),
            Color(0xFFFF2D55),
          ],
        ),
      ),
      child: GlassContainer(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        borderRadius: 17.0,
        blur: 22.0,
        gradientColors: gradientColors,
        borderColor: Colors.transparent,
        borderWidth: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_aiLoading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 220,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ] else if (_aiError != null) ...[
              Text(
                _aiError!,
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadAISummary,
                icon: const Icon(Icons.replay),
                label: const Text('다시 시도'),
              ),
            ] else ...[
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight ?? 260),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: SelectionArea(child: MarkdownBody(
                      selectable: false,
                      data: _aiSummary ?? '요약 내용이 없습니다.',
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: colorScheme.onSurface,
                        ),
                        h1: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        h2: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        h3: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        em: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurface,
                        ),
                        code: TextStyle(
                          fontSize: 13,
                          color: colorScheme.primary,
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                        ),
                        blockquote: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        listBullet: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ?ㅻ뒛 ?????꾪꽣留?(紐⑤뱺 ?꾨줈?앺듃) - In review? In progress留? ?꾩옱 ?ъ슜?먯뿉寃??좊떦??寃껊쭔
  List<Task> _getTodayTasks(List<Task> allTasks, String? currentUserId) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    return allTasks.where((task) {
      if (currentUserId == null ||
          !task.assignedMemberIds.contains(currentUserId)) {
        return false;
      }

      // 백로그/완료는 제외
      if (task.status == TaskStatus.backlog || task.status == TaskStatus.done) {
        return false;
      }

      final startDate = task.startDate;
      final endDate = task.endDate;

      // 시작/종료가 모두 있으면 기간 포함 여부로 판단
      if (startDate != null && endDate != null) {
        final startDateOnly = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return (todayStart.isAfter(
              startDateOnly.subtract(const Duration(days: 1)),
            ) &&
            todayStart.isBefore(endDateOnly.add(const Duration(days: 1))));
      }

      // 한쪽 날짜만 있으면 해당 날짜 기준, 둘 다 없으면 생성일 기준
      final dateToCheck = startDate ?? endDate ?? task.createdAt;
      final dateOnly = DateTime(
        dateToCheck.year,
        dateToCheck.month,
        dateToCheck.day,
      );
      return dateOnly.isAtSameMomentAs(todayStart);
    }).toList();
  }

  /// ?좎쭨 ?щ㎎??
  String _formatDate(DateTime date) {
    final months = [
      '1월',
      '2월',
      '3월',
      '4월',
      '5월',
      '6월',
      '7월',
      '8월',
      '9월',
      '10월',
      '11월',
      '12월',
    ];
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.year}년 ${months[date.month - 1]} ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  /// ?꾨줈?앺듃蹂??ㅻ뒛 ????洹몃９??
  Map<String, List<Task>> _getTodayTasksByProject(
    List<Task> allTasks,
    List<Project> projects,
    String? currentUserId,
  ) {
    final todayTasks = _getTodayTasks(allTasks, currentUserId);
    final Map<String, List<Task>> tasksByProject = {};

    for (final project in projects) {
      tasksByProject[project.id] = todayTasks
          .where((task) => task.projectId == project.id)
          .toList();
    }

    return tasksByProject;
  }

  /// ?꾨줈?앺듃蹂?吏꾪뻾瑜?怨꾩궛
  double _calculateProgress(Project project, List<Task> allTasks) {
    final projectTasks = allTasks
        .where((task) => task.projectId == project.id)
        .toList();
    if (projectTasks.isEmpty) return 0.0;

    final doneTasks = projectTasks
        .where((task) => task.status == TaskStatus.done)
        .length;
    return doneTasks / projectTasks.length;
  }

  /// ?꾨줈?앺듃蹂??쒖뒪??媛쒖닔
  Map<String, int> _getTaskCountsByProject(List<Task> allTasks) {
    final Map<String, int> counts = {};
    for (final task in allTasks) {
      counts[task.projectId] = (counts[task.projectId] ?? 0) + 1;
    }
    return counts;
  }

  /// ?쒓컙?蹂??몄궗 硫붿떆吏 諛섑솚
  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return '좋은 아침입니다';
    } else if (hour >= 12 && hour < 17) {
      return '좋은 오후입니다';
    } else if (hour >= 17 && hour < 22) {
      return '좋은 저녁입니다';
    } else {
      return '안녕하세요';
    }
  }

  Map<TaskStatus, int> _getStatusCounts(List<Task> tasks) {
    final counts = <TaskStatus, int>{
      TaskStatus.backlog: 0,
      TaskStatus.ready: 0,
      TaskStatus.inProgress: 0,
      TaskStatus.inReview: 0,
      TaskStatus.done: 0,
    };
    for (final task in tasks) {
      counts[task.status] = (counts[task.status] ?? 0) + 1;
    }
    return counts;
  }

  List<MapEntry<String, int>> _buildWorkload(
    List<Task> tasks,
    List<User> users,
  ) {
    final usernameById = {for (final u in users) u.id: u.username};
    final counts = <String, int>{};
    for (final task in tasks) {
      for (final uid in task.assignedMemberIds) {
        counts[uid] = (counts[uid] ?? 0) + 1;
      }
    }

    final result =
        counts.entries
            .map((e) => MapEntry(usernameById[e.key] ?? e.key, e.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return result.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final projectProvider = Provider.of<ProjectProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final user = authProvider.currentUser;
    final allProjects = projectProvider.projects;
    final allTasks = taskProvider.allTasks;
    final statusCounts = _getStatusCounts(allTasks);
    final totalTaskCount = allTasks.length;

    // 紐⑤뱺 ?꾨줈?앺듃???ㅻ뒛 ?????꾪꽣留?
    final todayTasks = _getTodayTasks(allTasks, user?.id);
    final projectsById = {
      for (final project in allProjects) project.id: project,
    };
    final taskCountsByProject = _getTaskCountsByProject(allTasks);

    bool useFixedPanels = true;
    if (useFixedPanels) {
      return _buildFourPanelLayout(
        context: context,
        authProvider: authProvider,
        colorScheme: colorScheme,
        user: user,
        allProjects: allProjects,
        allTasks: allTasks,
        todayTasks: todayTasks,
        projectsById: projectsById,
        statusCounts: statusCounts,
        totalTaskCount: totalTaskCount,
        taskCountsByProject: taskCountsByProject,
      );
    }

    // ignore: dead_code
    final todayTasksByProject = _getTodayTasksByProject(
      allTasks,
      allProjects,
      user?.id,
    );

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ?ㅻ뜑 (?좎쭨 + ?섏쁺 硫붿떆吏 + 愿由ъ옄 踰꾪듉)
          Stack(
            children: [
              // ?몄궭留?(吏꾩쭨 以묒븰)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_getGreetingMessage()}, ',
                      style: TextStyle(
                        fontSize: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      "${user?.username ?? '사용자'}님",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (authProvider.isAdmin) ...[
                      const SizedBox(width: 12),
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        borderRadius: 12.0,
                        blur: 15.0,
                        gradientColors: [
                          colorScheme.primary.withValues(alpha: 0.3),
                          colorScheme.primary.withValues(alpha: 0.2),
                        ],
                        borderColor: colorScheme.primary.withValues(alpha: 0.5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '관리자',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // ?ㅻ뒛 ?좎쭨 (媛???쇱そ)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDate(DateTime.now()),
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              // 愿由ъ옄 ?섏씠吏 踰꾪듉 (?ㅻⅨ履?
              if (authProvider.isAdmin)
                Align(
                  alignment: Alignment.centerRight,
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 12.0,
                    blur: 20.0,
                    gradientColors: [
                      colorScheme.primary.withValues(alpha: 0.3),
                      colorScheme.primary.withValues(alpha: 0.2),
                    ],
                    child: IconButton(
                      icon: Icon(
                        Icons.admin_panel_settings,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: () {
                        // 愿由ъ옄 ?섏씠吏瑜??ㅼ씠?쇰줈洹몃줈 ?쒖떆
                        showDialog(
                          context: context,
                          builder: (context) => const AdminApprovalScreen(),
                        );
                      },
                      tooltip: '관리자 페이지',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // 硫붿씤 而⑦뀗痢?(2???덉씠?꾩썐)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ?쇱そ: ?ㅻ뒛 ????(紐⑤뱺 ?꾨줈?앺듃 醫낇빀)
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ?ㅻ뜑
                        Row(
                          children: [
                            Icon(
                              Icons.today,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '오늘 할 일',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${todayTasks.length}개',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ?ㅻ뒛 ????紐⑸줉 (?꾨줈?앺듃蹂꾨줈 洹몃９??
                        todayTasks.isEmpty
                            ? Column(
                                children: [
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 48,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '오늘 할 일이 없습니다',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 1,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildAISummaryCard(context, colorScheme),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...allProjects
                                      .where((project) {
                                        final projectTasks =
                                            todayTasksByProject[project.id] ??
                                            [];
                                        return projectTasks.isNotEmpty;
                                      })
                                      .map((project) {
                                        final projectTasks =
                                            todayTasksByProject[project.id] ??
                                            [];

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 20,
                                          ),
                                          child: GlassContainer(
                                            padding: const EdgeInsets.all(20),
                                            borderRadius: 15.0,
                                            blur: 20.0,
                                            gradientColors: [
                                              colorScheme.surface.withValues(
                                                alpha: 0.5,
                                              ),
                                              colorScheme.surface.withValues(
                                                alpha: 0.4,
                                              ),
                                            ],
                                            borderColor: project.color
                                                .withValues(alpha: 0.4),
                                            borderWidth: 1.0,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // ?꾨줈?앺듃 ?ㅻ뜑
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: project.color,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      project.name,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: colorScheme
                                                            .onSurface,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: project.color
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '${projectTasks.length}개',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: project.color,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                // ?꾨줈?앺듃蹂??쒖뒪??紐⑸줉
                                                ...projectTasks.map((task) {
                                                  final statusColor =
                                                      task.status.color;

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    child: InkWell(
                                                      onTap: () {
                                                        showGeneralDialog(
                                                          context: context,
                                                          transitionDuration:
                                                              Duration.zero,
                                                          pageBuilder:
                                                              (
                                                                context,
                                                                animation,
                                                                secondaryAnimation,
                                                              ) =>
                                                                  TaskDetailScreen(
                                                                    task: task,
                                                                  ),
                                                          transitionBuilder:
                                                              (
                                                                context,
                                                                animation,
                                                                secondaryAnimation,
                                                                child,
                                                              ) => child,
                                                        );
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12.0,
                                                          ),
                                                      child: GlassContainer(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                        borderRadius: 12.0,
                                                        blur: 15.0,
                                                        borderWidth: 1.0,
                                                        gradientColors: [
                                                          colorScheme.surface
                                                              .withValues(
                                                                alpha: 0.6,
                                                              ),
                                                          colorScheme.surface
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                        ],
                                                        borderColor: statusColor
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        child: Row(
                                                          children: [
                                                            // ?곹깭 ?됱긽 ?몃뵒耳?댄꽣
                                                            Container(
                                                              width: 4,
                                                              height: 40,
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    statusColor,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      2,
                                                                    ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            // ?쒖뒪???댁슜
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    task.title,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  if (task
                                                                      .description
                                                                      .isNotEmpty) ...[
                                                                    const SizedBox(
                                                                      height: 4,
                                                                    ),
                                                                    Text(
                                                                      task.description,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        color: colorScheme
                                                                            .onSurface
                                                                            .withValues(
                                                                              alpha: 0.7,
                                                                            ),
                                                                      ),
                                                                      maxLines:
                                                                          2,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ],
                                                                  // ?좊떦??????쒓렇
                                                                  if (task
                                                                      .assignedMemberIds
                                                                      .isNotEmpty) ...[
                                                                    const SizedBox(
                                                                      height: 8,
                                                                    ),
                                                                    FutureBuilder<
                                                                      List<
                                                                        dynamic
                                                                      >
                                                                    >(
                                                                      future: _loadAssignedMembers(
                                                                        task.assignedMemberIds,
                                                                      ),
                                                                      builder:
                                                                          (
                                                                            context,
                                                                            snapshot,
                                                                          ) {
                                                                            if (!snapshot.hasData ||
                                                                                snapshot.data!.isEmpty) {
                                                                              return const SizedBox.shrink();
                                                                            }
                                                                            final members =
                                                                                snapshot.data!;
                                                                            return Wrap(
                                                                              spacing: 4,
                                                                              runSpacing: 4,
                                                                              children: members.map(
                                                                                (
                                                                                  member,
                                                                                ) {
                                                                                  return GlassContainer(
                                                                                    padding: const EdgeInsets.symmetric(
                                                                                      horizontal: 6,
                                                                                      vertical: 2,
                                                                                    ),
                                                                                    borderRadius: 6.0,
                                                                                    blur: 10.0,
                                                                                    gradientColors: [
                                                                                      colorScheme.primary.withValues(
                                                                                        alpha: 0.2,
                                                                                      ),
                                                                                      colorScheme.primary.withValues(
                                                                                        alpha: 0.1,
                                                                                      ),
                                                                                    ],
                                                                                    borderColor: colorScheme.primary.withValues(
                                                                                      alpha: 0.3,
                                                                                    ),
                                                                                    child: Row(
                                                                                      mainAxisSize: MainAxisSize.min,
                                                                                      children: [
                                                                                        CircleAvatar(
                                                                                          radius: 6,
                                                                                          backgroundColor: AvatarColor.getColorForUser(
                                                                                            member.id,
                                                                                          ),
                                                                                          child: Text(
                                                                                            AvatarColor.getInitial(
                                                                                              member.username,
                                                                                            ),
                                                                                            style: const TextStyle(
                                                                                              fontSize: 8,
                                                                                              color: Colors.white,
                                                                                              fontWeight: FontWeight.bold,
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                        const SizedBox(
                                                                                          width: 4,
                                                                                        ),
                                                                                        Text(
                                                                                          member.username,
                                                                                          style: TextStyle(
                                                                                            fontSize: 10,
                                                                                            color: colorScheme.onSurface,
                                                                                            fontWeight: FontWeight.w500,
                                                                                          ),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              ).toList(),
                                                                            );
                                                                          },
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            // ?곹깭 諛곗?
                                                            GlassContainer(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical: 6,
                                                                  ),
                                                              borderRadius:
                                                                  12.0,
                                                              blur: 15.0,
                                                              gradientColors: [
                                                                statusColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                                statusColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    ),
                                                              ],
                                                              borderColor:
                                                                  statusColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.5,
                                                                      ),
                                                              child: Text(
                                                                task
                                                                    .status
                                                                    .displayName,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      statusColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                  Container(
                                    height: 1,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildAISummaryCard(context, colorScheme),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people_alt_outlined,
                                        color: colorScheme.primary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '팀원별 워크로드',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  FutureBuilder<List<User>>(
                                    future: _usersFuture,
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 24,
                                          ),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }

                                      final workload = _buildWorkload(
                                        allTasks,
                                        snapshot.data!,
                                      );
                                      if (workload.isEmpty) {
                                        return GlassContainer(
                                          padding: const EdgeInsets.all(16),
                                          borderRadius: 14.0,
                                          blur: 18.0,
                                          gradientColors: [
                                            colorScheme.surface.withValues(
                                              alpha: 0.5,
                                            ),
                                            colorScheme.surface.withValues(
                                              alpha: 0.4,
                                            ),
                                          ],
                                          child: Text(
                                            '담당자가 지정된 태스크가 없습니다',
                                            style: TextStyle(
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        );
                                      }

                                      final maxCount = workload.first.value;
                                      return GlassContainer(
                                        padding: const EdgeInsets.all(16),
                                        borderRadius: 14.0,
                                        blur: 18.0,
                                        gradientColors: [
                                          colorScheme.surface.withValues(
                                            alpha: 0.5,
                                          ),
                                          colorScheme.surface.withValues(
                                            alpha: 0.4,
                                          ),
                                        ],
                                        child: Column(
                                          children: workload.map((entry) {
                                            final ratio = maxCount == 0
                                                ? 0.0
                                                : entry.value / maxCount;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 12,
                                                    backgroundColor:
                                                        AvatarColor.getColorForUser(
                                                          entry.key,
                                                        ),
                                                    child: Text(
                                                      AvatarColor.getInitial(
                                                        entry.key,
                                                      ),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                entry.key,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  color: colorScheme
                                                                      .onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                            Text(
                                                              '${entry.value}개',
                                                              style: TextStyle(
                                                                color: colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.7,
                                                                    ),
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          child: LinearProgressIndicator(
                                                            value: ratio,
                                                            minHeight: 6,
                                                            backgroundColor:
                                                                colorScheme
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.12,
                                                                    ),
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(
                                                                  colorScheme
                                                                      .primary,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                // ?몃줈 援щ텇??
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: const Color(0xFFF3DECA),
                ),
                // ?ㅻⅨ履? ?꾨줈?앺듃蹂?吏꾪뻾瑜?
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ?ㅻ뜑
                        Row(
                          children: [
                            Icon(
                              Icons.assessment,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '프로젝트 진행률',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ?꾨줈?앺듃蹂?吏꾪뻾瑜?移대뱶
                        if (allProjects.isEmpty)
                          GlassContainer(
                            padding: const EdgeInsets.all(40),
                            borderRadius: 20.0,
                            blur: 25.0,
                            gradientColors: [
                              colorScheme.surface.withValues(alpha: 0.4),
                              colorScheme.surface.withValues(alpha: 0.3),
                            ],
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 48,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '프로젝트가 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...allProjects.map((project) {
                            final progress = _calculateProgress(
                              project,
                              allTasks,
                            );
                            final taskCounts = _getTaskCountsByProject(
                              allTasks,
                            );
                            final taskCount = taskCounts[project.id] ?? 0;
                            final doneCount = allTasks
                                .where(
                                  (task) =>
                                      task.projectId == project.id &&
                                      task.status == TaskStatus.done,
                                )
                                .length;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(20),
                                borderRadius: 20.0,
                                blur: 25.0,
                                borderWidth: 1.0,
                                gradientColors: [
                                  colorScheme.surface.withValues(alpha: 0.4),
                                  colorScheme.surface.withValues(alpha: 0.3),
                                ],
                                borderColor: project.color.withValues(
                                  alpha: 0.3,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ?꾨줈?앺듃 ?ㅻ뜑
                                    Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: project.color,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            project.name,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${(progress * 100).toInt()}%',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: project.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // 吏꾪뻾瑜?諛?
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 12,
                                        backgroundColor: const Color(
                                          0xFFF3DECA,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              project.color,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // ?쒖뒪???듦퀎
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.task,
                                          size: 16,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '전체: $taskCount개',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: TaskStatus.done.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '완료: $doneCount개',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(
                              Icons.stacked_bar_chart_outlined,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '상태별 태스크 통계',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GlassContainer(
                          padding: const EdgeInsets.all(16),
                          borderRadius: 14.0,
                          blur: 18.0,
                          gradientColors: [
                            colorScheme.surface.withValues(alpha: 0.45),
                            colorScheme.surface.withValues(alpha: 0.35),
                          ],
                          child: Column(
                            children:
                                [
                                  TaskStatus.backlog,
                                  TaskStatus.ready,
                                  TaskStatus.inProgress,
                                  TaskStatus.inReview,
                                  TaskStatus.done,
                                ].map((status) {
                                  final count = statusCounts[status] ?? 0;
                                  final ratio = totalTaskCount == 0
                                      ? 0.0
                                      : count / totalTaskCount;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
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
                                            Expanded(
                                              child: Text(
                                                status.displayName,
                                                style: TextStyle(
                                                  color: colorScheme.onSurface,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '$count',
                                              style: TextStyle(
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.75),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: ratio,
                                            minHeight: 6,
                                            backgroundColor: status.color
                                                .withValues(alpha: 0.15),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  status.color,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
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
    );
  }

  Widget _buildFourPanelLayout({
    required BuildContext context,
    required AuthProvider authProvider,
    required ColorScheme colorScheme,
    required User? user,
    required List<Project> allProjects,
    required List<Task> allTasks,
    required List<Task> todayTasks,
    required Map<String, Project> projectsById,
    required Map<TaskStatus, int> statusCounts,
    required int totalTaskCount,
    required Map<String, int> taskCountsByProject,
  }) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_getGreetingMessage()}, ',
                      style: TextStyle(
                        fontSize: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      "${user?.username ?? '사용자'}님",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (authProvider.isAdmin) ...[
                      const SizedBox(width: 12),
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        borderRadius: 12.0,
                        blur: 15.0,
                        gradientColors: [
                          colorScheme.primary.withValues(alpha: 0.3),
                          colorScheme.primary.withValues(alpha: 0.2),
                        ],
                        borderColor: colorScheme.primary.withValues(alpha: 0.5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '관리자',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDate(DateTime.now()),
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (authProvider.isAdmin)
                Align(
                  alignment: Alignment.centerRight,
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 12.0,
                    blur: 20.0,
                    gradientColors: [
                      colorScheme.primary.withValues(alpha: 0.3),
                      colorScheme.primary.withValues(alpha: 0.2),
                    ],
                    child: IconButton(
                      icon: Icon(
                        Icons.admin_panel_settings,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const AdminApprovalScreen(),
                        );
                      },
                      tooltip: '관리자 페이지',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽: 오늘 할 일 + AI 매니저 (통합)
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildAiSummarySection(
                          context: context,
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        flex: 2,
                        child: _buildTodayTasksSection(
                          context: context,
                          colorScheme: colorScheme,
                          todayTasks: todayTasks,
                          projectsById: projectsById,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                ),
                // 가운데: 프로젝트 진행률 + 상태별 통계 (통합)
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildProjectProgressSection(
                          context: context,
                          colorScheme: colorScheme,
                          allProjects: allProjects,
                          allTasks: allTasks,
                          taskCountsByProject: taskCountsByProject,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        flex: 2,
                        child: _buildStatusStatsSection(
                          context: context,
                          colorScheme: colorScheme,
                          statusCounts: statusCounts,
                          totalTaskCount: totalTaskCount,
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

  Widget _buildSectionHeader({
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing],
      ],
    );
  }

  Widget _buildTodayTasksSection({
    required BuildContext context,
    required ColorScheme colorScheme,
    required List<Task> todayTasks,
    required Map<String, Project> projectsById,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          colorScheme: colorScheme,
          icon: Icons.today,
          title: '오늘 할 일',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${todayTasks.length}개',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16.0,
            blur: 20.0,
            gradientColors: [
              colorScheme.surface.withValues(alpha: 0.45),
              colorScheme.surface.withValues(alpha: 0.35),
            ],
            child: todayTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '오늘 할 일이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: todayTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = todayTasks[index];
                      final project = projectsById[task.projectId];
                      final statusColor = task.status.color;

                      return InkWell(
                        onTap: () {
                          showGeneralDialog(
                            context: context,
                            transitionDuration: Duration.zero,
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    TaskDetailScreen(task: task),
                            transitionBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) => child,
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      project?.name ?? '프로젝트 미지정',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.68,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  task.status.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiSummarySection({
    required BuildContext context,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionHeader(
              colorScheme: colorScheme,
              icon: Icons.auto_awesome,
              title: 'AI 매니저',
            ),
            const Spacer(),
            if (_aiGeneratedAt != null)
              Text(
                '요약 생성 ${_formatAiGeneratedAt(_aiGeneratedAt!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.topLeft,
                child: _buildAISummaryCard(
                  context,
                  colorScheme,
                  maxBodyHeight: constraints.maxHeight - 20,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProjectProgressSection({
    required BuildContext context,
    required ColorScheme colorScheme,
    required List<Project> allProjects,
    required List<Task> allTasks,
    required Map<String, int> taskCountsByProject,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          colorScheme: colorScheme,
          icon: Icons.assessment,
          title: '프로젝트 진행률',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16.0,
            blur: 20.0,
            gradientColors: [
              colorScheme.surface.withValues(alpha: 0.45),
              colorScheme.surface.withValues(alpha: 0.35),
            ],
            child: FutureBuilder<List<User>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                final users = snapshot.data ?? const <User>[];
                if (allProjects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 48,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '프로젝트가 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    users.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                const pageSize = 4;
                final totalPages = (allProjects.length / pageSize).ceil();

                if (totalPages > 0 && _projectProgressPage >= totalPages) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final targetPage = totalPages - 1;
                    setState(() => _projectProgressPage = targetPage);
                    _projectProgressPageController.jumpToPage(targetPage);
                  });
                }

                return Stack(
                  children: [
                    PageView.builder(
                      controller: _projectProgressPageController,
                      onPageChanged: (page) {
                        if (_projectProgressPage != page) {
                          setState(() => _projectProgressPage = page);
                        }
                      },
                      itemCount: totalPages,
                      itemBuilder: (context, pageIndex) {
                        final start = pageIndex * pageSize;
                        final end = (start + pageSize > allProjects.length)
                            ? allProjects.length
                            : start + pageSize;
                        final pageProjects = allProjects.sublist(start, end);

                        return GridView.builder(
                          padding: EdgeInsets.only(
                            right:
                                (totalPages > 1 && pageIndex < totalPages - 1)
                                ? 44
                                : 0,
                          ),
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pageProjects.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 160,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                          itemBuilder: (context, index) {
                            final project = pageProjects[index];
                            final progress = _calculateProgress(
                              project,
                              allTasks,
                            );
                            final taskCount =
                                taskCountsByProject[project.id] ?? 0;
                            final doneCount = allTasks
                                .where(
                                  (task) =>
                                      task.projectId == project.id &&
                                      task.status == TaskStatus.done,
                                )
                                .length;
                            final memberProgress = _getMemberProgressByProject(
                              projectId: project.id,
                              allTasks: allTasks,
                              users: users,
                            );

                            return _buildProjectProgressCard(
                              colorScheme: colorScheme,
                              project: project,
                              progress: progress,
                              taskCount: taskCount,
                              doneCount: doneCount,
                              memberProgress: memberProgress,
                            );
                          },
                        );
                      },
                    ),
                    if (totalPages > 1 && _projectProgressPage < totalPages - 1)
                      Positioned(
                        right: 2,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                _projectProgressPageController.nextPage(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withValues(
                                    alpha: 0.92,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.outline.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 22,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectProgressCard({
    required ColorScheme colorScheme,
    required Project project,
    required double progress,
    required int taskCount,
    required int doneCount,
    required List<_MemberProgressEntry> memberProgress,
  }) {
    final displayedMembers = memberProgress.take(4).toList();
    final hiddenCount = memberProgress.length - displayedMembers.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: project.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: project.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        color: project.color,
                        backgroundColor: project.color.withValues(alpha: 0.15),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: memberProgress.isEmpty
                    ? Center(
                        child: Text(
                          '팀원 데이터 없음',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...displayedMembers.map((entry) {
                            final ratio = entry.total == 0
                                ? 0.0
                                : entry.done / entry.total;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      entry.username,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 4,
                                        backgroundColor: colorScheme.primary
                                            .withValues(alpha: 0.12),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              project.color,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      '${(ratio * 100).toInt()}%',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.75,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (hiddenCount > 0)
                            Text(
                              '+$hiddenCount명',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '완료 $doneCount / 전체 ${taskCount}개',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  List<_MemberProgressEntry> _getMemberProgressByProject({
    required String projectId,
    required List<Task> allTasks,
    required List<User> users,
  }) {
    final usernameById = {for (final user in users) user.id: user.username};
    final stats = <String, _MemberProgressEntry>{};

    for (final task in allTasks) {
      if (task.projectId != projectId) continue;
      for (final memberId in task.assignedMemberIds) {
        final current = stats[memberId];
        if (current == null) {
          stats[memberId] = _MemberProgressEntry(
            memberId: memberId,
            username: usernameById[memberId] ?? memberId,
            done: task.status == TaskStatus.done ? 1 : 0,
            total: 1,
          );
        } else {
          stats[memberId] = _MemberProgressEntry(
            memberId: memberId,
            username: current.username,
            done: current.done + (task.status == TaskStatus.done ? 1 : 0),
            total: current.total + 1,
          );
        }
      }
    }

    final entries = stats.values.toList()
      ..sort((a, b) {
        final ratioA = a.total == 0 ? 0.0 : a.done / a.total;
        final ratioB = b.total == 0 ? 0.0 : b.done / b.total;
        final ratioCompare = ratioB.compareTo(ratioA);
        if (ratioCompare != 0) return ratioCompare;
        return b.total.compareTo(a.total);
      });
    return entries.take(4).toList();
  }

  Widget _buildStatusStatsSection({
    required BuildContext context,
    required ColorScheme colorScheme,
    required Map<TaskStatus, int> statusCounts,
    required int totalTaskCount,
  }) {
    final statuses = [
      TaskStatus.backlog,
      TaskStatus.ready,
      TaskStatus.inProgress,
      TaskStatus.inReview,
      TaskStatus.done,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          colorScheme: colorScheme,
          icon: Icons.stacked_bar_chart_outlined,
          title: '상태별 태스크 통계',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16.0,
            blur: 20.0,
            gradientColors: [
              colorScheme.surface.withValues(alpha: 0.45),
              colorScheme.surface.withValues(alpha: 0.35),
            ],
            child: ListView.separated(
              itemCount: statuses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final status = statuses[index];
                final count = statusCounts[status] ?? 0;
                final ratio = totalTaskCount == 0
                    ? 0.0
                    : count / totalTaskCount;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Expanded(
                          child: Text(
                            status.displayName,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: status.color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(status.color),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// ?좊떦?????紐⑸줉 濡쒕뱶
  Future<List<dynamic>> _loadAssignedMembers(List<String> memberIds) async {
    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      return allUsers.where((user) => memberIds.contains(user.id)).toList();
    } catch (e) {
      return [];
    }
  }

  Widget _buildTeamMembersSection({
    required BuildContext context,
    required ColorScheme colorScheme,
    required List<Task> allTasks,
  }) {
    final currentProject = Provider.of<ProjectProvider>(context).currentProject;

    final projectColor = currentProject?.color ?? colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          colorScheme: colorScheme,
          icon: Icons.people_alt_outlined,
          title: '팀원별 현황',
          trailing: currentProject != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: currentProject.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentProject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: currentProject.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16.0,
            blur: 20.0,
            borderWidth: currentProject != null ? 1.0 : 0,
            gradientColors: [
              colorScheme.surface.withValues(alpha: 0.45),
              colorScheme.surface.withValues(alpha: 0.35),
            ],
            borderColor: projectColor.withValues(alpha: 0.35),
            child: currentProject == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 48,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '프로젝트를 선택하면\n팀원 현황을 볼 수 있습니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : FutureBuilder<List<User>>(
                    future: _usersFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = snapshot.data!;
                      final projectTasks = allTasks
                          .where((t) => t.projectId == currentProject.id)
                          .toList();
                      final workload = _buildWorkload(projectTasks, users);

                      if (workload.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                size: 40,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '담당자가 지정된\n태스크가 없습니다',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final maxCount = workload.first.value;
                      return ListView.separated(
                        itemCount: workload.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = workload[index];
                          final ratio = maxCount == 0
                              ? 0.0
                              : entry.value / maxCount;
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AvatarColor.getColorForUser(
                                  entry.key,
                                ),
                                child: Text(
                                  AvatarColor.getInitial(entry.key),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${entry.value}개',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 6,
                                        backgroundColor: currentProject.color
                                            .withValues(alpha: 0.15),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              currentProject.color,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _MemberProgressEntry {
  final String memberId;
  final String username;
  final int done;
  final int total;

  const _MemberProgressEntry({
    required this.memberId,
    required this.username,
    required this.done,
    required this.total,
  });
}
