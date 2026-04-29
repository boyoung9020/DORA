import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member_stats.dart';
import '../models/activity_stats.dart';
import '../providers/workspace_provider.dart';
import '../providers/theme_provider.dart';
import '../services/workspace_service.dart';
import '../widgets/workspace/member_stat_card.dart';
import '../widgets/workspace/member_stat_detail.dart';
import '../widgets/workspace/team_today_dashboard.dart';
import '../widgets/workspace/contribution_heatmap.dart';

class WorkspaceMemberStatsScreen extends StatefulWidget {
  const WorkspaceMemberStatsScreen({super.key});

  @override
  State<WorkspaceMemberStatsScreen> createState() =>
      _WorkspaceMemberStatsScreenState();
}

class _WorkspaceMemberStatsScreenState
    extends State<WorkspaceMemberStatsScreen> {
  final _service = WorkspaceService();

  List<MemberStats> _allMembers = [];
  List<MemberStats> _filtered = [];
  String _filter = 'all'; // all | active | done
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _loadedWorkspaceId;
  String? _error;
  String _viewMode = 'dashboard'; // dashboard | detail

  // 히트맵 데이터
  ActivityHeatmap? _heatmap;
  bool _heatmapLoading = false;

  // 멤버 관리에서 핀된 사용자 셋 (TeamTodayDashboard 가 콜백으로 알려줌)
  // null = 아직 로드 전 (히트맵 필터 미적용 — 전체 표시)
  Set<String>? _pinnedUserIds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wsId = context.read<WorkspaceProvider>().currentWorkspace?.id;
    if (wsId != null && wsId != _loadedWorkspaceId) {
      _load(wsId);
    }
  }

  Future<void> _load(String workspaceId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final members = await _service.getMemberStats(workspaceId);
      setState(() {
        _allMembers = members;
        _loadedWorkspaceId = workspaceId;
        _applyFilter();
        _isLoading = false;
      });
      // 히트맵은 비동기로 추가 로드 (대시보드 진입 시 필요)
      _loadHeatmap(workspaceId);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHeatmap(String workspaceId) async {
    setState(() => _heatmapLoading = true);
    try {
      final hm = await _service.getActivityHeatmap(workspaceId, weeks: 12);
      if (!mounted) return;
      setState(() {
        _heatmap = hm;
        _heatmapLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _heatmapLoading = false);
    }
  }


  void _applyFilter() {
    switch (_filter) {
      case 'active':
        _filtered =
            _allMembers.where((m) => m.hasActiveTasks).toList();
        break;
      case 'done':
        _filtered =
            _allMembers.where((m) => m.recentDone.isNotEmpty).toList();
        break;
      default:
        _filtered = List.from(_allMembers);
    }
    if (_selectedIndex >= _filtered.length && _filtered.isNotEmpty) {
      _selectedIndex = 0;
    }
  }

  void _setFilter(String f) {
    setState(() {
      _filter = f;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final wsProvider = context.watch<WorkspaceProvider>();
    final ws = wsProvider.currentWorkspace;
    if (ws == null) {
      return const Center(child: Text('워크스페이스를 선택하세요'));
    }
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '${ws.name} 멤버',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _load(ws.id),
            tooltip: '새로고침',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _viewModeChip('대시보드', 'dashboard', Icons.dashboard_outlined),
                const SizedBox(width: 8),
                _viewModeChip('상세보기', 'detail', Icons.person_outline),
                if (_viewMode == 'detail') ...[
                  const SizedBox(width: 16),
                  Container(
                    width: 1,
                    height: 20,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 16),
                  _filterChip('전체', 'all'),
                  const SizedBox(width: 8),
                  _filterChip('진행 중', 'active'),
                  const SizedBox(width: 8),
                  _filterChip('최근 완료', 'done'),
                ],
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 40,
                          color:
                              colorScheme.error.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      Text('불러오기 실패',
                          style: TextStyle(
                              fontSize: 14, color: colorScheme.error)),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => _load(ws.id),
                          child: const Text('다시 시도')),
                    ],
                  ),
                )
              : _viewMode == 'dashboard'
                  ? _buildDashboardWithHeatmap(ws.id)
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            '해당 조건의 멤버가 없습니다',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 700;
                            if (isWide) {
                              return _buildWideLayout(context);
                            } else {
                              return _buildNarrowLayout(context);
                            }
                          },
                        ),
    );
  }

  /// 대시보드 + 하단 활동 히트맵
  /// 순서: 오늘의 팀 현황 (위) → 활동 히트맵 (아래)
  /// 히트맵은 멤버 관리에서 핀된 멤버만 필터링해서 표시한다.
  Widget _buildDashboardWithHeatmap(String workspaceId) {
    final accent = context.watch<ThemeProvider>().accentColor;

    // 핀 필터 적용된 히트맵 데이터
    ActivityHeatmap? filteredHeatmap;
    if (_heatmap != null) {
      final pinned = _pinnedUserIds;
      if (pinned == null) {
        filteredHeatmap = _heatmap;
      } else {
        filteredHeatmap = ActivityHeatmap(
          fromDate: _heatmap!.fromDate,
          toDate: _heatmap!.toDate,
          weeks: _heatmap!.weeks,
          members: _heatmap!.members
              .where((m) => pinned.contains(m.userId))
              .toList(),
        );
      }
    }

    // 화면 구성 (스크롤 없이 한 화면):
    //  ┌─ 오늘의 팀 현황 (summary bar)
    //  ├─ Contribution heatmap  (TeamTodayDashboard 의 middleSlot 으로 주입)
    //  └─ 오늘 일정 (멤버별 카드 grid)  ← 자체적으로 남은 공간 채움
    final heatmapWidget = (_heatmapLoading && _heatmap == null)
        ? const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          )
        : (filteredHeatmap != null
            ? ContributionHeatmap(data: filteredHeatmap, accent: accent)
            : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: TeamTodayDashboard(
        allMembers: _allMembers,
        workspaceId: workspaceId,
        onRefresh: () => _load(workspaceId),
        onPinnedChanged: (pinned) {
          if (!mounted) return;
          setState(() => _pinnedUserIds = pinned);
        },
        middleSlot: heatmapWidget,
      ),
    );
  }

  // 넓은 화면: 좌측 멤버 리스트 + 우측 상세
  Widget _buildWideLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        // 좌측 멤버 리스트
        SizedBox(
          width: 240,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    '${_filtered.length}명',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) => MemberStatCard(
                      member: _filtered[i],
                      isSelected: _selectedIndex == i,
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 우측 상세
        Expanded(
          child: _filtered.isNotEmpty
              ? MemberStatDetail(member: _filtered[_selectedIndex])
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // 좁은 화면: 세로 스크롤 리스트
  Widget _buildNarrowLayout(BuildContext context) {
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, i) {
        final member = _filtered[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemberStatCard(
              member: member,
              isSelected: false,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(member.username),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                      ),
                      body: MemberStatDetail(member: member),
                    ),
                  ),
                );
              },
            ),
            Divider(
              height: 1,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.3),
            ),
          ],
        );
      },
    );
  }

  Widget _viewModeChip(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _viewMode == value;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface.withValues(alpha: 0.65)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _filter == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}
