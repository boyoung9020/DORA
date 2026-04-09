import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member_stats.dart';
import '../providers/workspace_provider.dart';
import '../services/workspace_service.dart';
import '../widgets/workspace/member_stat_card.dart';
import '../widgets/workspace/member_stat_detail.dart';

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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
          '${ws.name} 팀 현황',
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
                _filterChip('전체', 'all'),
                const SizedBox(width: 8),
                _filterChip('진행 중', 'active'),
                const SizedBox(width: 8),
                _filterChip('최근 완료', 'done'),
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
              : _filtered.isEmpty
                  ? Center(
                      child: Text(
                        '해당 조건의 멤버가 없습니다',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.45),
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
