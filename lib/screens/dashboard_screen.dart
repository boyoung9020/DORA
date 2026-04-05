import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/notification_provider.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../models/notification.dart' as app_notification;
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';
import '../utils/api_client.dart';
import 'task_detail_screen.dart';

/// 대시보드 화면 - AI 매니저 + 작업 테이블
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // AI 매니저 관련
  final AiService _aiService = AiService();
  String? _aiSummary;
  bool _aiLoading = false;
  String? _aiError;
  DateTime? _aiGeneratedAt;
  String? _lastAiScopeKey;
  String? _lastTaskRefreshKey;
  bool _aiCollapsed = false;
  /// AI 요약 범위: mine(내 할당), others(다른 팀원 할당), all(전체)
  String _aiSummaryScope = 'all';

  // 오늘 할 작업 관련
  bool _todayTasksCollapsed = false;

  // 최근 활동 관련
  bool _activityCollapsed = false;

  // 작업 테이블 관련
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Future<List<User>>? _usersFuture;

  // 컬럼별 필터 (멀티 셀렉트)
  final Set<TaskStatus> _statusFilters = {};
  final Set<TaskPriority> _priorityFilters = {};
  final Set<String> _projectFilters = {}; // project ids
  final Set<String> _assigneeFilters = {}; // user ids
  String? _dateFilterMode; // null, 'today', 'thisWeek', 'thisMonth', 'overdue'
  // 정렬
  String _sortColumn = 'createdAt';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastAiScopeKey = _currentAiScopeKey();
      _loadAISummary();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspaceId =
        Provider.of<WorkspaceProvider>(context).currentWorkspaceId ?? '';
    final userId = Provider.of<AuthProvider>(context).currentUser?.id ?? '';
    final scopeKey = '$userId|$workspaceId';

    if (_lastTaskRefreshKey != scopeKey) {
      _lastTaskRefreshKey = scopeKey;
      if (workspaceId.isNotEmpty) {
        setState(() {
          _usersFuture = AuthService().getUsersByWorkspace(workspaceId);
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final projectIds = context.read<ProjectProvider>().projects.map((p) => p.id).toList();
          context.read<TaskProvider>().loadAllTasks(projectIds: projectIds);
          final authProv = context.read<AuthProvider>();
          if (authProv.currentUser != null) {
            context.read<NotificationProvider>().loadNotifications(
              userId: authProv.currentUser!.id,
              currentUsername: authProv.currentUser!.username,
            );
          }
        }
      });
    }

    if (_lastAiScopeKey != null && _lastAiScopeKey != scopeKey) {
      _lastAiScopeKey = scopeKey;
      _loadAISummary();
    }
  }

  // ─── AI 매니저 ─────────────────────────────────────────────

  String _currentAiScopeKey() {
    final workspaceId =
        context.read<WorkspaceProvider>().currentWorkspaceId ?? '';
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    return '$userId|$workspaceId';
  }

  Future<void> _loadAISummary({bool forceRefresh = false}) async {
    if (!mounted) return;
    final workspaceId = context.read<WorkspaceProvider>().currentWorkspaceId;
    final userId = context.read<AuthProvider>().currentUser?.id;

    if (!forceRefresh) {
      final cached = await _aiService.getCachedSummary(
        userId: userId,
        workspaceId: workspaceId,
        projectId: null,
        summaryScope: _aiSummaryScope,
      );
      if (cached != null && mounted) {
        setState(() {
          _aiSummary = cached.summary.isNotEmpty ? cached.summary : null;
          _aiGeneratedAt = cached.generatedAt ?? DateTime.now();
          _aiError = null;
        });
        return;
      }
    }

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
        summaryScope: _aiSummaryScope,
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

  // ─── 작업 테이블 ─────────────────────────────────────────────

  bool _hasActiveFilters() {
    return _statusFilters.isNotEmpty ||
        _priorityFilters.isNotEmpty ||
        _projectFilters.isNotEmpty ||
        _assigneeFilters.isNotEmpty ||
        _dateFilterMode != null;
  }

  List<Task> _getFilteredTasks(List<Task> allTasks, List<Project> projects) {
    var filtered = allTasks.toList();

    // 작업 소유자 필터 (글로벌)
    final ownerFilter = context.read<TaskProvider>().taskOwnerFilter;
    if (ownerFilter == 'mine') {
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      if (currentUserId != null) {
        filtered = filtered.where((t) => t.assignedMemberIds.contains(currentUserId)).toList();
      }
    } else if (ownerFilter != null) {
      filtered = filtered.where((t) => t.assignedMemberIds.contains(ownerFilter)).toList();
    }

    // 상태 필터
    if (_statusFilters.isNotEmpty) {
      filtered = filtered.where((t) => _statusFilters.contains(t.status)).toList();
    }

    // 우선순위 필터
    if (_priorityFilters.isNotEmpty) {
      filtered = filtered.where((t) => _priorityFilters.contains(t.priority)).toList();
    }

    // 프로젝트 필터
    if (_projectFilters.isNotEmpty) {
      filtered = filtered.where((t) => _projectFilters.contains(t.projectId)).toList();
    }

    // 담당자 필터
    if (_assigneeFilters.isNotEmpty) {
      filtered = filtered.where((t) => t.assignedMemberIds.any((id) => _assigneeFilters.contains(id))).toList();
    }

    // 기간 필터
    if (_dateFilterMode != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      filtered = filtered.where((t) {
        switch (_dateFilterMode) {
          case 'today':
            return t.endDate != null && DateTime(t.endDate!.year, t.endDate!.month, t.endDate!.day) == today;
          case 'thisWeek':
            final weekEnd = today.add(Duration(days: 7 - today.weekday));
            return t.endDate != null && !t.endDate!.isBefore(today) && !t.endDate!.isAfter(weekEnd);
          case 'thisMonth':
            return t.endDate != null && t.endDate!.year == now.year && t.endDate!.month == now.month;
          case 'overdue':
            return t.endDate != null && t.endDate!.isBefore(today) && t.status != TaskStatus.done;
          default:
            return true;
        }
      }).toList();
    }

    // 검색어 필터
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(query) ||
            task.description.toLowerCase().contains(query);
      }).toList();
    }

    // 정렬
    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'title':
          cmp = a.title.compareTo(b.title);
          break;
        case 'status':
          cmp = a.status.index.compareTo(b.status.index);
          break;
        case 'priority':
          cmp = a.priority.index.compareTo(b.priority.index);
          break;
        case 'project':
          cmp = a.projectId.compareTo(b.projectId);
          break;
        case 'endDate':
          final aDate = a.endDate ?? DateTime(2099);
          final bDate = b.endDate ?? DateTime(2099);
          cmp = aDate.compareTo(bDate);
          break;
        case 'createdAt':
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _formatDateRange(Task task) {
    if (task.startDate == null && task.endDate == null) return '-';
    final start =
        task.startDate != null ? _formatDate(task.startDate!) : '미정';
    final end = task.endDate != null ? _formatDate(task.endDate!) : '미정';
    return '$start ~ $end';
  }

  // ─── BUILD ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskProvider = Provider.of<TaskProvider>(context);
    final projectProvider = Provider.of<ProjectProvider>(context);
    final allTasks = taskProvider.allTasks;
    final allProjects = projectProvider.projects;
    final projectsById = {
      for (final p in allProjects) p.id: p,
    };

    final filteredTasks = _getFilteredTasks(allTasks, allProjects);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 인사 멘트
          Row(
            children: [
              Text(
                '${_getGreetingMessage()}, ',
                style: TextStyle(
                  fontSize: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '${user?.username ?? '사용자'}님',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 상태 카운트 카드 행
          _buildStatusCountRow(context, colorScheme, allTasks, allProjects),
          const SizedBox(height: 16),
          // AI 매니저 섹션
          _buildAiManagerSection(context, colorScheme),
          const SizedBox(height: 20),
          // 작업 테이블 + 최근 활동
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작업 테이블 (7)
                Expanded(
                  flex: 7,
                  child: _buildTaskTableSection(
                    context,
                    colorScheme,
                    filteredTasks,
                    allProjects,
                    projectsById,
                  ),
                ),
                const SizedBox(width: 16),
                // 오늘 할 작업 + 최근 활동 (3)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // 오늘 할 작업
                      Expanded(
                        flex: 5,
                        child: _buildTodayTasksSection(context, colorScheme, allTasks),
                      ),
                      const SizedBox(height: 16),
                      // 최근 활동
                      Expanded(
                        flex: 4,
                        child: _buildRecentActivitySection(context, colorScheme),
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

  // ─── 시간대별 인사 메시지 ──────────────────────────────────────
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

  // ─── 상태 카운트 카드 행 ────────────────────────────────────────

  Widget _buildStatusCountRow(
    BuildContext context,
    ColorScheme colorScheme,
    List<Task> allTasks,
    List<Project> allProjects,
  ) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final totalProjects = allProjects.length;
    final totalTasks = allTasks.length;

    // 대기 = backlog + ready 합산
    final pendingCount = allTasks
        .where((t) =>
            t.status == TaskStatus.backlog || t.status == TaskStatus.ready)
        .length;
    final inProgressCount =
        allTasks.where((t) => t.status == TaskStatus.inProgress).length;
    final inReviewCount =
        allTasks.where((t) => t.status == TaskStatus.inReview).length;
    final doneCount =
        allTasks.where((t) => t.status == TaskStatus.done).length;

    double pct(int count) =>
        totalTasks == 0 ? 0.0 : count / totalTasks;

    String pctStr(int count) => totalTasks == 0
        ? '0.0%'
        : '${(count / totalTasks * 100).toStringAsFixed(1)}%';

    final cards = [
      _StatusCardData(
        label: '전체 프로젝트',
        icon: Icons.folder_outlined,
        count: totalProjects,
        unit: '개',
        color: colorScheme.onSurface.withValues(alpha: 0.55),
        progress: null,
        pctLabel: null,
      ),
      _StatusCardData(
        label: '대기',
        icon: Icons.inbox_outlined,
        count: pendingCount,
        unit: '개',
        color: const Color(0xFF2196F3),
        progress: pct(pendingCount),
        pctLabel: pctStr(pendingCount),
      ),
      _StatusCardData(
        label: '진행 중',
        icon: Icons.sync_outlined,
        count: inProgressCount,
        unit: '개',
        color: const Color(0xFFFF9800),
        progress: pct(inProgressCount),
        pctLabel: pctStr(inProgressCount),
      ),
      _StatusCardData(
        label: '검토 중',
        icon: Icons.search_outlined,
        count: inReviewCount,
        unit: '개',
        color: const Color(0xFF9C27B0),
        progress: pct(inReviewCount),
        pctLabel: pctStr(inReviewCount),
      ),
      _StatusCardData(
        label: '완료',
        icon: Icons.check_circle_outline,
        count: doneCount,
        unit: '개',
        color: const Color(0xFF4CAF50),
        progress: pct(doneCount),
        pctLabel: pctStr(doneCount),
      ),
    ];

    final dividerColor = colorScheme.onSurface.withValues(alpha: isDark ? 0.1 : 0.08);

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      borderRadius: 14.0,
      blur: 20.0,
      gradientColors: isDark
          ? [
              colorScheme.surface.withValues(alpha: 0.85),
              colorScheme.surface.withValues(alpha: 0.9),
            ]
          : [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.98),
            ],
      borderColor: colorScheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.1),
      borderWidth: 1.0,
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(
                child: _buildStatusCard(context, colorScheme, isDark, cards[i]),
              ),
              if (i < cards.length - 1)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: dividerColor,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    _StatusCardData card,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라벨
          Row(
            children: [
              Icon(card.icon, size: 14, color: card.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 숫자 + 퍼센트
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${card.count}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  height: 1.1,
                ),
              ),
              Text(
                card.unit,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                  height: 1.1,
                ),
              ),
              if (card.pctLabel != null) ...[
                const Spacer(),
                Text(
                  card.pctLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    color: card.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          // 프로그레스 바
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: card.progress ?? 0,
              minHeight: 4,
              backgroundColor:
                  colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(card.color),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AI 매니저 섹션 ─────────────────────────────────────────────

  Widget _buildAiManagerSection(BuildContext context, ColorScheme colorScheme) {
    final gradientColors = colorScheme.brightness == Brightness.dark
        ? const [Color(0xFF2E2822), Color(0xFF242019)]
        : const [Color(0xFFF3EDFF), Color(0xFFE9F0FF)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderRadius: 13.0,
        blur: 22.0,
        gradientColors: gradientColors,
        borderColor: Colors.transparent,
        borderWidth: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (제목 + 새로고침 + 접기/펼치기)
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'AI 매니저',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (_aiGeneratedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_formatAiGeneratedAt(_aiGeneratedAt!)} 기준',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '범위',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _aiSummaryScope,
                    isDense: true,
                    padding: EdgeInsets.zero,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    dropdownColor: colorScheme.surface,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'mine',
                        child: Text('내 할당'),
                      ),
                      DropdownMenuItem(
                        value: 'others',
                        child: Text('다른 팀원'),
                      ),
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('전체'),
                      ),
                    ],
                    onChanged: _aiLoading
                        ? null
                        : (v) {
                            if (v == null || v == _aiSummaryScope) return;
                            setState(() => _aiSummaryScope = v);
                            _loadAISummary();
                          },
                  ),
                ),
                const SizedBox(width: 4),
                // 새로고침 버튼
                SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    icon: Icon(
                      Icons.refresh,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: _aiLoading
                        ? null
                        : () => _loadAISummary(forceRefresh: true),
                    tooltip: '새로고침',
                  ),
                ),
                const SizedBox(width: 2),
                // 접기/펼치기 버튼
                SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    icon: Icon(
                      _aiCollapsed
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: () {
                      setState(() {
                        _aiCollapsed = !_aiCollapsed;
                      });
                    },
                    tooltip: _aiCollapsed ? '펼치기' : '접기',
                  ),
                ),
              ],
            ),
            // 본문
            if (!_aiCollapsed) ...[
              const SizedBox(height: 8),
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
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('다시 시도'),
                ),
              ] else ...[
                Actions(
                  actions: {
                    CopySelectionTextIntent:
                        CallbackAction<CopySelectionTextIntent>(
                          onInvoke: (_) {
                            Clipboard.setData(
                              ClipboardData(text: _aiSummary ?? ''),
                            );
                            return null;
                          },
                        ),
                  },
                  child: SelectionArea(
                    child: MarkdownBody(
                      selectable: false,
                      data: _aiSummary ?? '요약 내용이 없습니다.',
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: colorScheme.onSurface,
                        ),
                        h1: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        h2: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        h3: TextStyle(
                          fontSize: 12,
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
                          fontSize: 11,
                          color: colorScheme.primary,
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.1),
                        ),
                        listBullet: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ─── 작업 테이블 섹션 ─────────────────────────────────────────────

  Widget _buildTaskTableSection(
    BuildContext context,
    ColorScheme colorScheme,
    List<Task> filteredTasks,
    List<Project> allProjects,
    Map<String, Project> projectsById,
  ) {
    final isDarkMode = colorScheme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더: 검색 + 필터 칩 + 개수
        Row(
          children: [
            // 검색
            SizedBox(
              width: 240,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? colorScheme.surfaceContainerHighest
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isDarkMode
                        ? colorScheme.onSurface.withValues(alpha: 0.1)
                        : const Color(0xFFE0E7FF),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '작업 검색...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Export 버튼
            InkWell(
              onTap: () => _showExportDialog(context, allProjects),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.ios_share_outlined,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 활성 필터 개수 표시
            if (_hasActiveFilters()) ...[
              InkWell(
                onTap: () => setState(() {
                  _statusFilters.clear();
                  _priorityFilters.clear();
                  _projectFilters.clear();
                  _assigneeFilters.clear();
                  _dateFilterMode = null;
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '필터 초기화',
                        style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.close, size: 14, color: colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            // 개수
            Text(
              '${filteredTasks.length}개',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 테이블
        Expanded(
          child: GlassContainer(
            padding: EdgeInsets.zero,
            borderRadius: 16.0,
            blur: 20.0,
            gradientColors: [
              colorScheme.surface.withValues(alpha: 0.45),
              colorScheme.surface.withValues(alpha: 0.35),
            ],
            child: Column(
              children: [
                // 테이블 헤더
                _buildTableHeader(context, colorScheme, allProjects),
                Divider(
                  height: 1,
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                // 테이블 바디
                Expanded(
                  child: filteredTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '작업이 없습니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FutureBuilder<List<User>>(
                          future: _usersFuture,
                          builder: (context, snapshot) {
                            final users = snapshot.data ?? [];
                            final usernameById = {
                              for (final u in users) u.id: u,
                            };
                            return ListView.separated(
                              itemCount: filteredTasks.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.06,
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final task = filteredTasks[index];
                                final project = projectsById[task.projectId];
                                return _buildTaskRow(
                                  context,
                                  colorScheme,
                                  task,
                                  project,
                                  usernameById,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 테이블 헤더 ─────────────────────────────────────────────

  Widget _buildTableHeader(BuildContext context, ColorScheme colorScheme, List<Project> allProjects) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // ID
          SizedBox(
            width: 80,
            child: _buildColumnHeader(
              context, colorScheme,
              label: 'ID',
              sortColumn: null,
              hasFilter: false,
              isFilterActive: false,
            ),
          ),
          // 상태
          SizedBox(
            width: 120,
            child: _buildColumnHeader(
              context, colorScheme,
              label: '상태',
              sortColumn: 'status',
              hasFilter: true,
              isFilterActive: _statusFilters.isNotEmpty,
              onFilterTap: (rect) => _showStatusFilterDropdown(context, rect),
            ),
          ),
          // 제목
          Expanded(
            child: _buildColumnHeader(
              context, colorScheme,
              label: '제목',
              sortColumn: 'title',
              hasFilter: false,
              isFilterActive: false,
            ),
          ),
          // 프로젝트
          SizedBox(
            width: 140,
            child: _buildColumnHeader(
              context, colorScheme,
              label: '프로젝트',
              sortColumn: 'project',
              hasFilter: true,
              isFilterActive: _projectFilters.isNotEmpty,
              onFilterTap: (rect) => _showProjectFilterDropdown(context, rect, allProjects),
            ),
          ),
          // 우선순위
          SizedBox(
            width: 130,
            child: _buildColumnHeader(
              context, colorScheme,
              label: '우선순위',
              sortColumn: 'priority',
              hasFilter: true,
              isFilterActive: _priorityFilters.isNotEmpty,
              onFilterTap: (rect) => _showPriorityFilterDropdown(context, rect),
            ),
          ),
          // 기간
          SizedBox(
            width: 140,
            child: _buildColumnHeader(
              context, colorScheme,
              label: '기간',
              sortColumn: 'endDate',
              hasFilter: true,
              isFilterActive: _dateFilterMode != null,
              onFilterTap: (rect) => _showDateFilterDropdown(context, rect),
            ),
          ),
          // 담당자
          SizedBox(
            width: 120,
            child: _buildColumnHeader(
              context, colorScheme,
              label: '담당자',
              sortColumn: null,
              hasFilter: true,
              isFilterActive: _assigneeFilters.isNotEmpty,
              onFilterTap: (rect) => _showAssigneeFilterDropdown(context, rect),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(
    BuildContext context,
    ColorScheme colorScheme, {
    required String label,
    required String? sortColumn,
    required bool hasFilter,
    required bool isFilterActive,
    void Function(Rect rect)? onFilterTap,
  }) {
    final isSortActive = sortColumn != null && _sortColumn == sortColumn;
    final headerColor = (isFilterActive || isSortActive)
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 컬럼명
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: headerColor,
            ),
          ),
          const SizedBox(width: 2),
          // 필터 드롭다운 아이콘
          if (hasFilter)
            _FilterIconButton(
              isActive: isFilterActive,
              color: headerColor,
              onTap: onFilterTap,
            ),
          // 정렬 아이콘
          if (sortColumn != null)
            SizedBox(
              width: 22,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                splashRadius: 14,
                icon: Icon(
                  isSortActive
                      ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                      : Icons.arrow_upward,
                  color: isSortActive
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.55),
                  size: 15,
                ),
                onPressed: () {
                  setState(() {
                    if (_sortColumn == sortColumn) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortColumn = sortColumn;
                      _sortAscending = true;
                    }
                  });
                },
                tooltip: isSortActive
                    ? (_sortAscending ? '내림차순' : '오름차순')
                    : '오름차순 정렬',
              ),
            ),
        ],
      ),
    );
  }

  // ─── 필터 드롭다운 ─────────────────────────────────────────────

  void _showStatusFilterDropdown(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: TaskStatus.values.map((status) {
        final isSelected = _statusFilters.contains(status);
        return PopupMenuItem<void>(
          height: 36,
          onTap: () {
            setState(() {
              if (isSelected) {
                _statusFilters.remove(status);
              } else {
                _statusFilters.add(status);
              }
            });
          },
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected ? status.color : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                status.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? status.color : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList()
        ..add(PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _statusFilters.clear()),
          child: Row(
            children: [
              Icon(Icons.clear_all, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('초기화', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        )),
    );
  }

  void _showPriorityFilterDropdown(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: TaskPriority.values.map((priority) {
        final isSelected = _priorityFilters.contains(priority);
        return PopupMenuItem<void>(
          height: 36,
          onTap: () {
            setState(() {
              if (isSelected) {
                _priorityFilters.remove(priority);
              } else {
                _priorityFilters.add(priority);
              }
            });
          },
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected ? priority.color : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: priority.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                priority.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? priority.color : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList()
        ..add(PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _priorityFilters.clear()),
          child: Row(
            children: [
              Icon(Icons.clear_all, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('초기화', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        )),
    );
  }

  void _showProjectFilterDropdown(BuildContext context, Rect buttonRect, List<Project> allProjects) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: allProjects.map((project) {
        final isSelected = _projectFilters.contains(project.id);
        return PopupMenuItem<void>(
          height: 36,
          onTap: () {
            setState(() {
              if (isSelected) {
                _projectFilters.remove(project.id);
              } else {
                _projectFilters.add(project.id);
              }
            });
          },
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected ? project.color : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: project.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  project.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? project.color : colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList()
        ..add(PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _projectFilters.clear()),
          child: Row(
            children: [
              Icon(Icons.clear_all, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('초기화', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        )),
    );
  }

  void _showDateFilterDropdown(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = <MapEntry<String?, String>>[
      const MapEntry(null, '전체'),
      const MapEntry('today', '오늘 마감'),
      const MapEntry('thisWeek', '이번 주'),
      const MapEntry('thisMonth', '이번 달'),
      const MapEntry('overdue', '기한 지남'),
    ];
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: options.map((option) {
        final isSelected = _dateFilterMode == option.key;
        return PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _dateFilterMode = option.key),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Text(
                option.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showAssigneeFilterDropdown(BuildContext context, Rect buttonRect) async {
    final colorScheme = Theme.of(context).colorScheme;
    final allUsers = await _usersFuture ?? [];
    if (!mounted) return;

    // 내가 속한 프로젝트들의 팀원 ID만 수집
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final visibleProjects = context.read<ProjectProvider>().projects;
    final memberIdSet = <String>{};
    for (final p in visibleProjects) {
      if (currentUserId != null && p.teamMemberIds.contains(currentUserId)) {
        memberIdSet.addAll(p.teamMemberIds);
      }
    }
    // 전체 유저 중 해당 프로젝트 팀원만 필터링 (순서 유지)
    final users = allUsers.where((u) => memberIdSet.contains(u.id)).toList();
    if (!mounted) return;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: users.map((user) {
        final isSelected = _assigneeFilters.contains(user.id);
        return PopupMenuItem<void>(
          height: 36,
          onTap: () {
            setState(() {
              if (isSelected) {
                _assigneeFilters.remove(user.id);
              } else {
                _assigneeFilters.add(user.id);
              }
            });
          },
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 10,
                backgroundColor: AvatarColor.getColorForUser(user.id),
                child: Text(
                  AvatarColor.getInitial(user.username),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList()
        ..add(PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _assigneeFilters.clear()),
          child: Row(
            children: [
              Icon(Icons.clear_all, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('초기화', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        )),
    );
  }

  // ─── 테이블 행 ─────────────────────────────────────────────

  Widget _buildTaskRow(
    BuildContext context,
    ColorScheme colorScheme,
    Task task,
    Project? project,
    Map<String, User> usernameById,
  ) {
    final statusColor = task.status.color;
    final priorityColor = task.priority.color;

    return InkWell(
      onTap: () {
        showGeneralDialog(
          context: context,
          transitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) =>
              TaskDetailScreen(task: task),
          transitionBuilder:
              (context, animation, secondaryAnimation, child) => child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            // ID
            SizedBox(
              width: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  task.displayId != null ? '#${task.displayId}' : '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            // 상태
            SizedBox(
              width: 120,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ),
            // 제목
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (task.description.isNotEmpty)
                      Text(
                        task.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            // 프로젝트
            SizedBox(
              width: 140,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (project != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: project.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        project?.name ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 우선순위
            SizedBox(
              width: 130,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.priority.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
              ),
            ),
            // 기간
            SizedBox(
              width: 140,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _formatDateRange(task),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
            // 담당자
            SizedBox(
              width: 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildAssigneeNames(
                  task.assignedMemberIds,
                  usernameById,
                  colorScheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeNames(
    List<String> memberIds,
    Map<String, User> usersById,
    ColorScheme colorScheme,
  ) {
    if (memberIds.isEmpty) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    final names = memberIds
        .map((id) => usersById[id]?.username ?? '?')
        .toList();
    final text = names.join(', ');

    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ─── 오늘 할 작업 섹션 ─────────────────────────────────────────────

  Widget _buildTodayTasksSection(
    BuildContext context,
    ColorScheme colorScheme,
    List<Task> allTasks,
  ) {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 오늘 작업해야 하는 진행중 작업 (endDate가 오늘이거나 오늘 이후, startDate가 오늘이거나 오늘 이전)
    // + 완료 상태이며 오늘 완료된 작업도 포함 (취소선으로 표시)
    final todayTasks = allTasks.where((task) {
      // 현재 사용자에게 할당된 작업만
      if (currentUserId != null && !task.assignedMemberIds.contains(currentUserId)) {
        return false;
      }

      // 완료된 작업: 오늘 완료된 것만 표시
      if (task.status == TaskStatus.done) {
        // statusHistory에서 done으로 변경된 마지막 기록 확인
        final doneHistory = task.statusHistory.where(
          (h) => h.toStatus == TaskStatus.done,
        );
        if (doneHistory.isNotEmpty) {
          final doneDate = doneHistory.last.changedAt;
          final doneDateOnly = DateTime(doneDate.year, doneDate.month, doneDate.day);
          return doneDateOnly == today;
        }
        // statusHistory가 없으면 updatedAt으로 판단
        final updatedDateOnly = DateTime(task.updatedAt.year, task.updatedAt.month, task.updatedAt.day);
        return updatedDateOnly == today;
      }

      // 진행중 작업: startDate~endDate 범위에 오늘이 포함되면 표시
      if (task.status == TaskStatus.inProgress) {
        if (task.startDate != null && task.endDate != null) {
          final start = DateTime(task.startDate!.year, task.startDate!.month, task.startDate!.day);
          final end = DateTime(task.endDate!.year, task.endDate!.month, task.endDate!.day);
          return !today.isBefore(start) && today.isBefore(end.add(const Duration(days: 1)));
        }
        if (task.endDate != null) {
          final end = DateTime(task.endDate!.year, task.endDate!.month, task.endDate!.day);
          return !today.isAfter(end);
        }
        if (task.startDate != null) {
          final start = DateTime(task.startDate!.year, task.startDate!.month, task.startDate!.day);
          return !today.isBefore(start);
        }
        // 날짜가 없는 진행중 작업도 포함
        return true;
      }

      return false;
    }).toList();

    // 진행중 먼저, 완료는 뒤로
    todayTasks.sort((a, b) {
      if (a.status == TaskStatus.done && b.status != TaskStatus.done) return 1;
      if (a.status != TaskStatus.done && b.status == TaskStatus.done) return -1;
      return 0;
    });

    final projectProvider = context.watch<ProjectProvider>();
    final projects = {for (var p in projectProvider.projects) p.id: p};

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16.0,
      blur: 20.0,
      gradientColors: [
        colorScheme.surface.withValues(alpha: 0.45),
        colorScheme.surface.withValues(alpha: 0.35),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                Icons.today,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '오늘 할 작업',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${todayTasks.where((t) => t.status != TaskStatus.done).length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: Icon(
                    _todayTasksCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _todayTasksCollapsed = !_todayTasksCollapsed;
                    });
                  },
                  tooltip: _todayTasksCollapsed ? '펼치기' : '접기',
                ),
              ),
            ],
          ),
          if (!_todayTasksCollapsed) ...[
            const SizedBox(height: 8),
            // 테이블 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  // 완료 체크
                  const SizedBox(width: 36),
                  // 제목
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Text(
                        '제목',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  // 프로젝트
                  SizedBox(
                    width: 90,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Text(
                        '프로젝트',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  // 우선순위
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: Text(
                        '우선순위',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.08)),
            // 테이블 본문
            Expanded(
              child: todayTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 40,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '오늘 할 작업이 없습니다',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: todayTasks.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                      itemBuilder: (context, index) {
                        final task = todayTasks[index];
                        final isDone = task.status == TaskStatus.done;
                        final project = projects[task.projectId];
                        final priorityColor = task.priority.color;

                        return InkWell(
                          onTap: () {
                            showGeneralDialog(
                              context: context,
                              transitionDuration: Duration.zero,
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  TaskDetailScreen(task: task),
                              transitionBuilder:
                                  (context, animation, secondaryAnimation, child) => child,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                // 체크박스
                                SizedBox(
                                  width: 36,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: isDone,
                                        onChanged: (value) async {
                                          if (value == true && !isDone) {
                                            final taskProvider = context.read<TaskProvider>();
                                            final authProvider = context.read<AuthProvider>();
                                            await taskProvider.updateTask(
                                              task.copyWith(status: TaskStatus.done),
                                              userId: authProvider.currentUser?.id,
                                              username: authProvider.currentUser?.username,
                                            );
                                          }
                                        },
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        activeColor: TaskStatus.done.color,
                                        side: BorderSide(
                                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                                          width: 1.5,
                                        ),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                ),
                                // 제목
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    child: Text(
                                      task.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDone
                                            ? colorScheme.onSurface.withValues(alpha: 0.4)
                                            : colorScheme.onSurface,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                // 프로젝트
                                SizedBox(
                                  width: 90,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Row(
                                      children: [
                                        if (project != null) ...[
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: project.color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            project?.name ?? '-',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDone
                                                  ? colorScheme.onSurface.withValues(alpha: 0.35)
                                                  : colorScheme.onSurface.withValues(alpha: 0.6),
                                              decoration: isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              decorationColor: colorScheme.onSurface.withValues(alpha: 0.3),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 우선순위
                                SizedBox(
                                  width: 60,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: priorityColor.withValues(alpha: isDone ? 0.08 : 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        task.priority.displayName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDone
                                              ? priorityColor.withValues(alpha: 0.4)
                                              : priorityColor,
                                        ),
                                      ),
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
          ],
        ],
      ),
    );
  }

  // ─── 최근 활동 섹션 ─────────────────────────────────────────────

  IconData _getNotificationIcon(app_notification.NotificationType type) {
    switch (type) {
      case app_notification.NotificationType.projectMemberAdded:
        return Icons.group_add;
      case app_notification.NotificationType.taskAssigned:
        return Icons.assignment_ind;
      case app_notification.NotificationType.taskOptionChanged:
        return Icons.settings;
      case app_notification.NotificationType.taskCommentAdded:
        return Icons.comment;
      case app_notification.NotificationType.taskMentioned:
        return Icons.alternate_email;
    }
  }

  Color _getNotificationColor(app_notification.NotificationType type) {
    switch (type) {
      case app_notification.NotificationType.projectMemberAdded:
        return const Color(0xFF4F46E5);
      case app_notification.NotificationType.taskAssigned:
        return const Color(0xFFF59E0B);
      case app_notification.NotificationType.taskOptionChanged:
        return const Color(0xFF8B5CF6);
      case app_notification.NotificationType.taskCommentAdded:
        return const Color(0xFF10B981);
      case app_notification.NotificationType.taskMentioned:
        return const Color(0xFF2563EB);
    }
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return '방금 전';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 2) {
      return '어제';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks주 전';
    } else {
      final months = (diff.inDays / 30).floor();
      return '$months개월 전';
    }
  }

  void _handleActivityTap(app_notification.Notification notification) async {
    final notificationProvider = context.read<NotificationProvider>();

    if (!notification.isRead) {
      await notificationProvider.markAsRead(notification.id);
    }

    if (notification.taskId != null && notification.taskId!.isNotEmpty) {
      if (!mounted) return;
      // 로컬 캐시에서 태스크 검색
      final taskProvider = context.read<TaskProvider>();
      var task = taskProvider.allTasks.where((t) => t.id == notification.taskId).firstOrNull;

      // 없으면 API에서 가져오기
      if (task == null) {
        try {
          task = await TaskService().getTaskById(notification.taskId!);
        } catch (_) {}
      }

      if (task != null && mounted) {
        showGeneralDialog(
          context: context,
          transitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) =>
              TaskDetailScreen(task: task!),
          transitionBuilder:
              (context, animation, secondaryAnimation, child) => child,
        );
      }
    }
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications = notificationProvider.notifications.take(20).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16.0,
      blur: 20.0,
      gradientColors: [
        colorScheme.surface.withValues(alpha: 0.45),
        colorScheme.surface.withValues(alpha: 0.35),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                Icons.history,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '최근 활동',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: Icon(
                    _activityCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _activityCollapsed = !_activityCollapsed;
                    });
                  },
                  tooltip: _activityCollapsed ? '펼치기' : '접기',
                ),
              ),
            ],
          ),
          if (!_activityCollapsed) ...[
            const SizedBox(height: 12),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 40,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '최근 활동이 없습니다',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _buildActivityItem(
                          context,
                          colorScheme,
                          notification,
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      BuildContext context,
      ColorScheme colorScheme,
      app_notification.Notification notification,
      ) {
    final icon = _getNotificationIcon(notification.type);
    final typeColor = _getNotificationColor(notification.type);
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: () => _handleActivityTap(notification),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: typeColor),
            ),
            const SizedBox(width: 10),
            // 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // 시간 + 읽지 않음 인디케이터
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatRelativeTime(notification.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Export 기능 ─────────────────────────────────────────────

  Future<void> _showExportDialog(BuildContext context, List<Project> allProjects) async {
    final colorScheme = Theme.of(context).colorScheme;
    final workspaceId = context.read<WorkspaceProvider>().currentWorkspaceId;

    final allUsers = await (_usersFuture ?? Future.value(<User>[]));
    if (!context.mounted) return;
    final memberIdSet = <String>{};
    for (final p in allProjects) {
      memberIdSet.addAll(p.teamMemberIds);
    }
    final teamUsers = allUsers.where((u) => memberIdSet.contains(u.id)).toList()
      ..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

    final selectedProjectIds = <String>{};
    final exportAssigneeIds = <String>{};
    String exportFormat = 'docs'; // 'docs' or 'md'
    DateTime exportStart = DateTime.now().subtract(const Duration(days: 7));
    DateTime exportEnd = DateTime.now();
    // 보고서 제목 기본값:보내기를 여는 당일(로컬) 기준 YYMMDD — 기간과 무관, 필드에서 수정 가능
    String defaultExportTitleForDate(DateTime d) {
      final y = (d.year % 100).toString().padLeft(2, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y$m$day 업무 보고';
    }

    final titleController = TextEditingController(
      text: defaultExportTitleForDate(DateTime.now()),
    );
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassContainer(
                padding: const EdgeInsets.all(24),
                borderRadius: 20.0,
                blur: 25.0,
                gradientColors: [
                  colorScheme.surface.withValues(alpha: 0.95),
                  colorScheme.surface.withValues(alpha: 0.9),
                ],
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.ios_share_outlined, size: 20, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '업무 보고서 내보내기',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 제목
                      Text('제목', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: '기본: 오늘 날짜(YYMMDD) 기준 — 필요 시 수정',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),

                      // 프로젝트 선택 (멀티셀렉트)
                      Row(
                        children: [
                          Text('프로젝트', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (selectedProjectIds.length == allProjects.length) {
                                  selectedProjectIds.clear();
                                } else {
                                  selectedProjectIds.clear();
                                  selectedProjectIds.addAll(allProjects.map((p) => p.id));
                                }
                              });
                            },
                            child: Text(
                              selectedProjectIds.length == allProjects.length ? '전체 해제' : '전체 선택',
                              style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: allProjects.map((project) {
                              final isSelected = selectedProjectIds.contains(project.id);
                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    if (isSelected) {
                                      selectedProjectIds.remove(project.id);
                                    } else {
                                      selectedProjectIds.add(project.id);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                        size: 18,
                                        color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          project.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      if (selectedProjectIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${selectedProjectIds.length}개 선택됨',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 기간 선택
                      Text('기간', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: ctx,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                            initialDateRange: DateTimeRange(start: exportStart, end: exportEnd),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              exportStart = picked.start;
                              exportEnd = picked.end;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 8),
                              Text(
                                '${exportStart.month}/${exportStart.day} ~ ${exportEnd.month}/${exportEnd.day}',
                                style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 담당자 (작업 테이블 담당자 필터와 동일: 멀티 선택 · 아바타 · 초기화)
                      Row(
                        children: [
                          Text(
                            '담당자',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => setDialogState(() => exportAssigneeIds.clear()),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.clear_all, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '초기화',
                                    style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '선택하지 않으면 기간·프로젝트 내 전체 작업입니다. 선택 시 해당 담당자가 할당된 작업만 포함합니다.',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: teamUsers.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '표시할 팀원이 없습니다. 프로젝트에 팀원이 있는지 확인해 주세요.',
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: teamUsers.map((user) {
                                    final isSelected = exportAssigneeIds.contains(user.id);
                                    return InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            exportAssigneeIds.remove(user.id);
                                          } else {
                                            exportAssigneeIds.add(user.id);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                              size: 18,
                                              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(width: 8),
                                            CircleAvatar(
                                              radius: 10,
                                              backgroundColor: AvatarColor.getColorForUser(user.id),
                                              child: Text(
                                                AvatarColor.getInitial(user.username),
                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                user.username,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: colorScheme.onSurface,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                      if (exportAssigneeIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${exportAssigneeIds.length}명 선택됨',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 형식 선택
                      Text('형식', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => exportFormat = 'docs'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: exportFormat == 'docs'
                                      ? colorScheme.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: exportFormat == 'docs'
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.description_outlined, size: 16,
                                      color: exportFormat == 'docs' ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6)),
                                    const SizedBox(width: 6),
                                    Text('Google Docs',
                                      style: TextStyle(fontSize: 13,
                                        color: exportFormat == 'docs' ? colorScheme.primary : colorScheme.onSurface,
                                        fontWeight: exportFormat == 'docs' ? FontWeight.w600 : FontWeight.normal)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => exportFormat = 'md'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: exportFormat == 'md'
                                      ? colorScheme.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: exportFormat == 'md'
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.code, size: 16,
                                      color: exportFormat == 'md' ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6)),
                                    const SizedBox(width: 6),
                                    Text('Markdown',
                                      style: TextStyle(fontSize: 13,
                                        color: exportFormat == 'md' ? colorScheme.primary : colorScheme.onSurface,
                                        fontWeight: exportFormat == 'md' ? FontWeight.w600 : FontWeight.normal)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 내보내기 버튼
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isLoading ? null : () async {
                            setDialogState(() => isLoading = true);
                            try {
                              final report = await _callExportApi(
                                title: titleController.text,
                                workspaceId: workspaceId,
                                projectIds: selectedProjectIds.isEmpty ? null : selectedProjectIds.toList(),
                                startDate: exportStart,
                                endDate: exportEnd,
                                format: exportFormat,
                                assigneeIds: exportAssigneeIds.isEmpty ? null : exportAssigneeIds.toList(),
                              );
                              if (ctx.mounted) {
                                Navigator.of(dialogContext).pop();
                                _showExportResultDialog(context, report, exportFormat);
                              }
                            } catch (e) {
                              setDialogState(() => isLoading = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('보고서 생성 실패: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          icon: isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(isLoading ? 'AI 보고서 생성 중...' : 'AI 보고서 생성'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) => titleController.dispose());
  }

  Future<String> _callExportApi({
    required String title,
    String? workspaceId,
    List<String>? projectIds,
    required DateTime startDate,
    required DateTime endDate,
    required String format,
    List<String>? assigneeIds,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'project_ids': projectIds,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'format': format,
      'task_scope': 'all',
    };
    if (workspaceId != null && workspaceId.isNotEmpty) {
      body['workspace_id'] = workspaceId;
    }
    if (assigneeIds != null && assigneeIds.isNotEmpty) {
      body['assignee_ids'] = assigneeIds;
    }
    final response = await ApiClient.post(
      '/api/ai/export-report',
      body: body,
    );
    final data = ApiClient.handleResponse(response);
    return data['report'] as String;
  }

  void _showExportResultDialog(BuildContext context, String report, String format) {
    final colorScheme = Theme.of(context).colorScheme;
    final scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 20.0,
            blur: 25.0,
            gradientColors: [
              colorScheme.surface.withValues(alpha: 0.95),
              colorScheme.surface.withValues(alpha: 0.9),
            ],
            child: SizedBox(
              width: 600,
              height: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.article_outlined, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '보고서',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: report));
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('클립보드에 복사되었습니다'), duration: Duration(seconds: 2)),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('복사'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: format == 'md'
                          ? Markdown(
                              data: report,
                              selectable: true,
                              controller: scrollController,
                              padding: EdgeInsets.zero,
                              styleSheet: MarkdownStyleSheet(
                                h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                h3: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.primary),
                                p: TextStyle(fontSize: 13, height: 1.6, color: colorScheme.onSurface),
                                listBullet: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                                strong: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                h2Padding: const EdgeInsets.only(bottom: 8),
                                h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
                                blockSpacing: 6,
                              ),
                            )
                          : Scrollbar(
                              controller: scrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: scrollController,
                                child: SelectableText(
                                  report,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
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
    );
  }
}

/// 필터 아이콘 버튼 - 위치 정보를 전달하기 위해 별도 위젯으로 분리
class _FilterIconButton extends StatelessWidget {
  final bool isActive;
  final Color color;
  final void Function(Rect rect)? onTap;

  const _FilterIconButton({
    required this.isActive,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 15,
        splashRadius: 14,
        icon: Icon(
          Icons.filter_list,
          color: isActive
              ? color
              : color.withValues(alpha: 0.55),
          size: 15,
        ),
        onPressed: () {
          final box = context.findRenderObject() as RenderBox;
          final offset = box.localToGlobal(Offset.zero);
          final rect = Rect.fromLTWH(offset.dx, offset.dy, box.size.width, box.size.height);
          onTap?.call(rect);
        },
        tooltip: '필터',
      ),
    );
  }
}

/// 상태 카운트 카드 데이터
class _StatusCardData {
  final String label;
  final IconData icon;
  final int count;
  final String unit;
  final Color color;
  final double? progress;
  final String? pctLabel;

  const _StatusCardData({
    required this.label,
    required this.icon,
    required this.count,
    required this.unit,
    required this.color,
    required this.progress,
    required this.pctLabel,
  });
}
