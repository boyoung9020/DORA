import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../utils/avatar_color.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../widgets/glass_container.dart';
import 'task_detail_screen.dart';

/// 날짜별 그리드 페인터
class _DateGridPainter extends CustomPainter {
  final DateTime startDate;
  final DateTime endDate;
  final double dayWidth;
  final Color lineColor;

  _DateGridPainter({
    required this.startDate,
    required this.endDate,
    required this.dayWidth,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    final days = endDate.difference(startDate).inDays;

    for (int i = 0; i <= days; i++) {
      final x = i * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DateGridPainter oldDelegate) {
    return oldDelegate.startDate != startDate ||
        oldDelegate.endDate != endDate ||
        oldDelegate.dayWidth != dayWidth ||
        oldDelegate.lineColor != lineColor;
  }
}

/// 계층 구조 표시를 위한 행 데이터
class _GanttRow {
  final Task task;
  final bool isParent;
  final bool isExpanded;
  final int childCount;
  final int doneChildCount;
  final int level;

  const _GanttRow({
    required this.task,
    required this.isParent,
    this.isExpanded = false,
    this.childCount = 0,
    this.doneChildCount = 0,
    this.level = 0,
  });
}

/// 간트 차트 화면
class GanttChartScreen extends StatefulWidget {
  const GanttChartScreen({super.key});

  @override
  State<GanttChartScreen> createState() => _GanttChartScreenState();
}

class _GanttChartScreenState extends State<GanttChartScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));
  bool _userOverrodeRange = false;
  bool _didInitialScroll = false;
  double _dayWidth = 40.0;
  final Map<String, Future<List<User>>> _assignedMembersCache = {};
  String? _lastLoadedProjectId;
  bool? _lastLoadedAllMode;

  // 부모 태스크 접기/펼치기 상태
  final Map<String, bool> _expandedParents = {};

  // 스크롤 동기화용 컨트롤러
  final ScrollController _headerHScrollController = ScrollController();
  final ScrollController _bodyHScrollController = ScrollController();
  final ScrollController _taskVScrollController = ScrollController();
  final ScrollController _barVScrollController = ScrollController();
  bool _syncingHScroll = false;
  bool _syncingVScroll = false;

  @override
  void initState() {
    super.initState();
    _headerHScrollController.addListener(() {
      if (_syncingHScroll) return;
      _syncingHScroll = true;
      if (_bodyHScrollController.hasClients) {
        _bodyHScrollController.jumpTo(_headerHScrollController.offset);
      }
      _syncingHScroll = false;
    });
    _bodyHScrollController.addListener(() {
      if (_syncingHScroll) return;
      _syncingHScroll = true;
      if (_headerHScrollController.hasClients) {
        _headerHScrollController.jumpTo(_bodyHScrollController.offset);
      }
      _syncingHScroll = false;
    });
    _taskVScrollController.addListener(() {
      if (_syncingVScroll) return;
      _syncingVScroll = true;
      if (_barVScrollController.hasClients) {
        _barVScrollController.jumpTo(_taskVScrollController.offset);
      }
      _syncingVScroll = false;
    });
    _barVScrollController.addListener(() {
      if (_syncingVScroll) return;
      _syncingVScroll = true;
      if (_taskVScrollController.hasClients) {
        _taskVScrollController.jumpTo(_barVScrollController.offset);
      }
      _syncingVScroll = false;
    });
  }

  @override
  void dispose() {
    _headerHScrollController.dispose();
    _bodyHScrollController.dispose();
    _taskVScrollController.dispose();
    _barVScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectProvider = context.read<ProjectProvider>();
    final projectId = projectProvider.currentProject?.id;
    final isAllMode = projectProvider.isAllProjectsMode;
    if (_lastLoadedProjectId != projectId || _lastLoadedAllMode != isAllMode) {
      _lastLoadedProjectId = projectId;
      _lastLoadedAllMode = isAllMode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TaskProvider>().loadTasks(
            projectId: isAllMode ? null : projectId,
          );
        }
      });
    }
  }

  /// 오늘 날짜 위치로 가로 스크롤 이동 (화면 좌측 1/3 지점에 오늘이 오도록)
  void _scrollToToday() {
    _didInitialScroll = true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(_startDate) || today.isAfter(_endDate)) return;

    final todayOffset = today.difference(_startDate).inDays * _dayWidth;
    // 타임라인 영역 너비를 대략적으로 계산 (전체 너비 - 왼쪽 패널 320 - 패딩)
    const timelineViewWidth = 600.0; // 보수적인 추정치
    final scrollTo = (todayOffset - timelineViewWidth / 3).clamp(0.0, double.infinity);

    if (_bodyHScrollController.hasClients) {
      _bodyHScrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (_headerHScrollController.hasClients) {
      _headerHScrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 플랫 태스크 리스트를 계층 구조 행 리스트로 변환
  List<_GanttRow> _buildHierarchicalRows(List<Task> tasks) {
    // 부모 ID → 자식 태스크 맵
    final childrenMap = <String, List<Task>>{};
    for (final t in tasks) {
      if (t.parentTaskId != null && t.parentTaskId!.isNotEmpty) {
        childrenMap.putIfAbsent(t.parentTaskId!, () => []).add(t);
      }
    }

    // 루트 태스크 = 부모가 없거나, 부모가 현재 목록에 없는 태스크
    final taskIds = tasks.map((t) => t.id).toSet();
    final rootTasks = tasks.where((t) {
      if (t.parentTaskId == null || t.parentTaskId!.isEmpty) return true;
      return !taskIds.contains(t.parentTaskId);
    }).toList();

    // 시작일 기준 정렬
    rootTasks.sort((a, b) {
      final aStart = a.startDate ?? a.createdAt;
      final bStart = b.startDate ?? b.createdAt;
      return aStart.compareTo(bStart);
    });

    final rows = <_GanttRow>[];
    void addRows(List<Task> taskList, int level) {
      for (final task in taskList) {
        final children = childrenMap[task.id] ?? [];
        final hasChildren = children.isNotEmpty;
        final isExpanded = _expandedParents[task.id] ?? true;
        final doneCount = children.where((c) => c.status == TaskStatus.done).length;

        rows.add(_GanttRow(
          task: task,
          isParent: hasChildren,
          isExpanded: isExpanded,
          childCount: children.length,
          doneChildCount: doneCount,
          level: level,
        ));

        if (hasChildren && isExpanded) {
          children.sort((a, b) {
            final aStart = a.startDate ?? a.createdAt;
            final bStart = b.startDate ?? b.createdAt;
            return aStart.compareTo(bStart);
          });
          addRows(children, level + 1);
        }
      }
    }

    addRows(rootTasks, 0);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskProvider = context.watch<TaskProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final currentProjectId = projectProvider.currentProject?.id;
    final isAllMode = projectProvider.isAllProjectsMode;

    var projectTasks = isAllMode
        ? taskProvider.tasks
              .where((task) => task.status != TaskStatus.backlog)
              .toList()
        : (currentProjectId != null
              ? taskProvider.tasks
                    .where(
                      (task) =>
                          task.projectId == currentProjectId &&
                          task.status != TaskStatus.backlog,
                    )
                    .toList()
              : <Task>[]);

    final ownerFilter = context.read<TaskProvider>().taskOwnerFilter;
    if (ownerFilter == 'mine') {
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      if (currentUserId != null) {
        projectTasks = projectTasks.where((task) => task.assignedMemberIds.contains(currentUserId)).toList();
      }
    } else if (ownerFilter != null) {
      projectTasks = projectTasks.where((task) => task.assignedMemberIds.contains(ownerFilter)).toList();
    }

    // 태스크 기반 날짜 범위 자동 계산: 모든 태스크를 포함하되 오늘 기준 최소 ±90일
    if (projectTasks.isNotEmpty && !_userOverrodeRange) {
      DateTime? earliestDate;
      DateTime? latestDate;

      for (final task in projectTasks) {
        final taskStart = task.startDate ?? task.createdAt;
        if (earliestDate == null || taskStart.isBefore(earliestDate)) {
          earliestDate = taskStart;
        }

        final taskEnd =
            task.endDate ??
            (task.updatedAt.isAfter(task.createdAt)
                ? task.updatedAt
                : task.createdAt.add(const Duration(days: 1)));
        if (latestDate == null || taskEnd.isAfter(latestDate)) {
          latestDate = taskEnd;
        }
      }

      final now = DateTime.now();
      // 오늘 기준 ±90일을 기본으로, 태스크 범위가 더 넓으면 확장
      var calculatedStartDate = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 90));
      var calculatedEndDate = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 90));

      if (earliestDate != null && earliestDate.isBefore(calculatedStartDate)) {
        calculatedStartDate = DateTime(
          earliestDate.year, earliestDate.month, earliestDate.day,
        ).subtract(const Duration(days: 7));
      }
      if (latestDate != null && latestDate.isAfter(calculatedEndDate)) {
        calculatedEndDate = DateTime(
          latestDate.year, latestDate.month, latestDate.day,
        ).add(const Duration(days: 7));
      }

      if (_startDate != calculatedStartDate ||
          _endDate != calculatedEndDate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _startDate = calculatedStartDate;
              _endDate = calculatedEndDate;
            });
            _scrollToToday();
          }
        });
      } else if (!_didInitialScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToToday();
        });
      }
    } else if (!_didInitialScroll && !_userOverrodeRange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToToday();
      });
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 컨트롤
          _buildToolbar(context, colorScheme),
          const SizedBox(height: 16),
          // 간트 차트
          Expanded(child: _buildGanttChart(context, projectTasks, colorScheme)),
        ],
      ),
    );
  }

  /// 특정 날짜 위치로 가로 스크롤 이동
  void _scrollToDate(DateTime date) {
    if (date.isBefore(_startDate) || date.isAfter(_endDate)) return;
    final dateOffset = date.difference(_startDate).inDays * _dayWidth;
    const timelineViewWidth = 600.0;
    final scrollTo = (dateOffset - timelineViewWidth / 3).clamp(0.0, double.infinity);

    if (_bodyHScrollController.hasClients) {
      _bodyHScrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (_headerHScrollController.hasClients) {
      _headerHScrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildToolbar(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        // 오늘 버튼
        _buildPresetButton(context, colorScheme, '오늘', Icons.today, () {
          if (_userOverrodeRange) {
            setState(() => _userOverrodeRange = false);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToToday();
          });
        }),
        const SizedBox(width: 6),
        // 이번 주 - 범위 유지, 해당 주 시작으로 스크롤
        _buildPresetButton(context, colorScheme, '이번 주', Icons.view_week, () {
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          if (_userOverrodeRange) {
            setState(() => _userOverrodeRange = false);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToDate(DateTime(weekStart.year, weekStart.month, weekStart.day));
          });
        }),
        const SizedBox(width: 6),
        // 이번 달 - 범위 유지, 해당 월 시작으로 스크롤
        _buildPresetButton(context, colorScheme, '이번 달', Icons.calendar_month, () {
          final now = DateTime.now();
          if (_userOverrodeRange) {
            setState(() => _userOverrodeRange = false);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToDate(DateTime(now.year, now.month, 1));
          });
        }),
        const SizedBox(width: 12),
        // 날짜 범위 선택 (인라인 칩)
        InkWell(
          onTap: () => _showDateRangePicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _userOverrodeRange
                    ? colorScheme.primary.withValues(alpha: 0.5)
                    : colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              color: _userOverrodeRange
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range, size: 14, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  _userOverrodeRange
                      ? '${_startDate.month}/${_startDate.day} ~ ${_endDate.month}/${_endDate.day}'
                      : '기간 설정',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                if (_userOverrodeRange)
                  GestureDetector(
                    onTap: () => setState(() => _userOverrodeRange = false),
                    child: Icon(Icons.close, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                  )
                else
                  Icon(Icons.arrow_drop_down, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
        const Spacer(),
        // 줌 컨트롤
        Icon(Icons.zoom_out, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        SizedBox(
          width: 120,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: colorScheme.primary,
              inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.12),
              thumbColor: colorScheme.primary,
            ),
            child: Slider(
              value: _dayWidth,
              min: 20,
              max: 80,
              onChanged: (v) => setState(() => _dayWidth = v),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.zoom_in, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
      ],
    );
  }

  Widget _buildPresetButton(
    BuildContext context,
    ColorScheme colorScheme,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 간트 차트 위젯
  Widget _buildGanttChart(
    BuildContext context,
    List<Task> tasks,
    ColorScheme colorScheme,
  ) {
    if (tasks.isEmpty) {
      return Center(
        child: GlassContainer(
          padding: const EdgeInsets.all(40),
          borderRadius: 20.0,
          blur: 25.0,
          gradientColors: [
            colorScheme.surface.withValues(alpha: 0.3),
            colorScheme.surface.withValues(alpha: 0.2),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timeline,
                size: 64,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '태스크가 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final visibleRows = _buildHierarchicalRows(tasks);
    final days = _endDate.difference(_startDate).inDays;
    final dayWidth = _dayWidth;
    const rowHeight = 44.0;
    final isDark = colorScheme.brightness == Brightness.dark;
    final borderColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.15)
        : const Color(0xFFE0E7FF);

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 16.0,
      blur: 25.0,
      gradientColors: [
        colorScheme.surface.withValues(alpha: 0.4),
        colorScheme.surface.withValues(alpha: 0.3),
      ],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  width: 320,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    border: Border(
                      right: BorderSide(color: borderColor, width: 1),
                      bottom: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '작업',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                    ),
                    child: SingleChildScrollView(
                      controller: _headerHScrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: days * dayWidth,
                        child: _buildDateHeader(context, colorScheme, dayWidth),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // 바디
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽: 계층형 이슈 리스트
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: borderColor, width: 1)),
                    ),
                    child: ListView.builder(
                      controller: _taskVScrollController,
                      itemCount: visibleRows.length,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          height: rowHeight,
                          child: _buildTaskRow(
                            context, visibleRows[index], colorScheme, borderColor,
                          ),
                        );
                      },
                    ),
                  ),
                  // 오른쪽: 타임라인 바
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _bodyHScrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: days * dayWidth,
                        child: Stack(
                          children: [
                            _buildTodayMarker(colorScheme, dayWidth, visibleRows.length * rowHeight),
                            ListView.builder(
                              controller: _barVScrollController,
                              itemCount: visibleRows.length,
                              itemBuilder: (context, index) {
                                return SizedBox(
                                  height: rowHeight,
                                  child: _buildGanttBar(
                                    context, visibleRows[index], colorScheme, dayWidth, rowHeight, borderColor,
                                  ),
                                );
                              },
                            ),
                          ],
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
    );
  }

  /// 왼쪽 패널: 계층형 태스크 행
  Widget _buildTaskRow(
    BuildContext context,
    _GanttRow row,
    ColorScheme colorScheme,
    Color borderColor,
  ) {
    final task = row.task;
    final isParent = row.isParent;

    return InkWell(
      onTap: isParent
          ? () => setState(() {
                _expandedParents[task.id] = !(row.isExpanded);
              })
          : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          color: isParent
              ? colorScheme.primary.withValues(alpha: 0.04)
              : null,
        ),
        padding: EdgeInsets.only(
          left: 12.0 + row.level * 20.0,
          right: 12,
        ),
        child: Row(
          children: [
            // 접기/펼치기 또는 인덴트
            if (isParent) ...[
              Icon(
                row.isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              // 부모 아이콘
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  size: 12,
                  color: colorScheme.primary,
                ),
              ),
            ] else ...[
              // 하위 태스크 상태 아이콘
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: task.status.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(
                  task.status == TaskStatus.done ? Icons.check : Icons.remove,
                  size: 10,
                  color: task.status.color,
                ),
              ),
            ],
            const SizedBox(width: 8),
            // 태스크 제목
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isParent ? FontWeight.w600 : FontWeight.normal,
                  color: colorScheme.onSurface.withValues(
                    alpha: task.status == TaskStatus.done ? 0.5 : 1.0,
                  ),
                  decoration: task.status == TaskStatus.done
                      ? TextDecoration.lineThrough
                      : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 담당자 아바타 (하위 태스크만)
            if (!isParent && task.assignedMemberIds.isNotEmpty) ...[
              const SizedBox(width: 6),
              FutureBuilder<List<User>>(
                future: _loadAssignedMembers(task.assignedMemberIds),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  if (members.isEmpty) return const SizedBox.shrink();
                  const avatarSize = 18.0;
                  const overlap = 10.0;
                  final shown = members.take(3).toList();
                  final extra = members.length - shown.length;
                  return SizedBox(
                    width: avatarSize + (shown.length - 1) * overlap + (extra > 0 ? overlap : 0),
                    height: avatarSize,
                    child: Stack(
                      children: [
                        ...shown.asMap().entries.map((e) {
                          final idx = e.key;
                          final member = e.value;
                          final color = AvatarColor.getColorForUser(member.id);
                          return Positioned(
                            left: idx * overlap,
                            child: Tooltip(
                              message: member.username,
                              waitDuration: const Duration(milliseconds: 300),
                              child: CircleAvatar(
                                radius: avatarSize / 2,
                                backgroundColor: color,
                                child: Text(
                                  AvatarColor.getInitial(member.username),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        if (extra > 0)
                          Positioned(
                            left: shown.length * overlap,
                            child: Tooltip(
                              message: members.skip(3).map((m) => m.username).join(', '),
                              waitDuration: const Duration(milliseconds: 300),
                              child: CircleAvatar(
                                radius: avatarSize / 2,
                                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.2),
                                child: Text(
                                  '+$extra',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(width: 6),
            // 상태 뱃지
            _buildStatusBadge(task.status, colorScheme),
            if (isParent && row.childCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                '${row.doneChildCount}/${row.childCount}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 상태 뱃지
  Widget _buildStatusBadge(TaskStatus status, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: status.color,
        ),
      ),
    );
  }

  /// 오늘 마커 세로선
  Widget _buildTodayMarker(ColorScheme colorScheme, double dayWidth, double totalHeight) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(_startDate) || today.isAfter(_endDate)) {
      return const SizedBox.shrink();
    }
    final offset = today.difference(_startDate).inDays * dayWidth + dayWidth / 2;
    return Positioned(
      left: offset,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: colorScheme.primary.withValues(alpha: 0.6),
      ),
    );
  }

  Future<List<User>> _loadAssignedMembers(List<String> memberIds) {
    final cacheKey = memberIds.join(',');
    if (_assignedMembersCache.containsKey(cacheKey)) {
      return _assignedMembersCache[cacheKey]!;
    }

    final future = AuthService()
        .getAllUsers()
        .then((users) {
          return users.where((user) => memberIds.contains(user.id)).toList();
        })
        .catchError((_) => <User>[]);

    _assignedMembersCache[cacheKey] = future;
    return future;
  }

  /// 날짜 헤더 (월 → 일 2단 구조)
  Widget _buildDateHeader(
    BuildContext context,
    ColorScheme colorScheme,
    double dayWidth,
  ) {
    final days = _endDate.difference(_startDate).inDays;
    final isDark = colorScheme.brightness == Brightness.dark;
    final borderColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.15)
        : const Color(0xFFE0E7FF);

    return SizedBox(
      height: 40,
      child: Row(
        children: List.generate(days, (dayIndex) {
          final date = _startDate.add(Duration(days: dayIndex));
          final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
          final isToday = date.year == DateTime.now().year &&
              date.month == DateTime.now().month &&
              date.day == DateTime.now().day;

          return Container(
            width: dayWidth,
            decoration: BoxDecoration(
              color: isToday
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : isWeekend
                      ? colorScheme.onSurface.withValues(alpha: 0.03)
                      : null,
              border: Border(right: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (dayWidth >= 30) Text(
                  _getWeekdayAbbr(date.weekday),
                  style: TextStyle(
                    fontSize: 9,
                    color: isToday
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: isWeekend ? 0.4 : 0.5),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: dayWidth >= 30 ? 12 : 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: isWeekend ? 0.5 : 0.75),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _getWeekdayAbbr(int weekday) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[weekday - 1];
  }

  /// 간트 바 위젯 (부모=진행도 바, 자식=상태별 둥근 바)
  Widget _buildGanttBar(
    BuildContext context,
    _GanttRow row,
    ColorScheme colorScheme,
    double dayWidth,
    double rowHeight,
    Color borderColor,
  ) {
    final task = row.task;
    final taskStart = task.startDate ?? task.createdAt;
    final taskEnd =
        task.endDate ??
        (task.updatedAt.isAfter(task.createdAt)
            ? task.updatedAt
            : task.createdAt.add(const Duration(days: 1)));

    if (taskStart.isAfter(_endDate) || taskEnd.isBefore(_startDate)) {
      return Container(
        height: rowHeight,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
      );
    }

    final startOffset = taskStart.isBefore(_startDate)
        ? 0.0
        : taskStart.difference(_startDate).inDays * dayWidth;
    final endOffset = taskEnd.isAfter(_endDate)
        ? _endDate.difference(_startDate).inDays * dayWidth
        : taskEnd.difference(_startDate).inDays * dayWidth;
    final barWidth = (endOffset - startOffset).clamp(dayWidth, double.infinity);

    final days = _endDate.difference(_startDate).inDays;
    final isDark = colorScheme.brightness == Brightness.dark;
    final gridColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.07)
        : const Color(0xFFE0E7FF).withValues(alpha: 0.4);

    final startStr = '${taskStart.month}/${taskStart.day}';
    final endStr = '${taskEnd.month}/${taskEnd.day}';
    final durationDays = taskEnd.difference(taskStart).inDays;
    final tooltipText = '${task.title}\n${task.status.displayName} · $startStr ~ $endStr ($durationDays일)';

    final statusColor = task.status.color;

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size(days * dayWidth, rowHeight),
            painter: _DateGridPainter(
              startDate: _startDate,
              endDate: _endDate,
              dayWidth: dayWidth,
              lineColor: gridColor,
            ),
          ),
          if (row.isParent) ...[
            // 부모 태스크: 진행도가 표시되는 바
            Positioned(
              left: startOffset + 4,
              top: (rowHeight - 22) / 2,
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.2),
                  builder: (_) => TaskDetailScreen(task: task),
                ),
                child: Tooltip(
                  message: tooltipText,
                  child: Container(
                  width: (barWidth - 8).clamp(4, double.infinity),
                  height: 22,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // 진행도 표시
                      if (row.childCount > 0)
                        FractionallySizedBox(
                          widthFactor: row.doneChildCount / row.childCount,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      // 텍스트
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            barWidth > 120 ? task.title : '${row.doneChildCount}/${row.childCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ] else ...[
            // 자식 태스크: 상태별 둥근 바
            Positioned(
              left: startOffset + 4,
              top: (rowHeight - 22) / 2,
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.2),
                  builder: (_) => TaskDetailScreen(task: task),
                ),
                child: Tooltip(
                  message: tooltipText,
                  child: Container(
                  width: (barWidth - 8).clamp(4, double.infinity),
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.85),
                        statusColor.withValues(alpha: 0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          barWidth > 80 ? task.title : task.status.displayName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (barWidth > 60 && task.assignedMemberIds.isNotEmpty)
                        FutureBuilder<List<User>>(
                          future: _loadAssignedMembers(task.assignedMemberIds),
                          builder: (context, snapshot) {
                            final members = snapshot.data;
                            if (members == null || members.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: CircleAvatar(
                                radius: 8,
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                child: Text(
                                  AvatarColor.getInitial(members.first.username),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  /// 날짜 범위 선택 (Flutter 기본 DateRangePicker 활용)
  void _showDateRangePicker(BuildContext context) async {
    final result = await showTaskDateRangePickerDialog(
      context: context,
      initialStartDate: _userOverrodeRange ? _startDate : null,
      initialEndDate: _userOverrodeRange ? _endDate : null,
      minDate: DateTime(2020),
      maxDate: DateTime(2030),
    );

    if (result != null && (result['startDate'] != null || result['endDate'] != null)) {
      setState(() {
        _userOverrodeRange = true;
        if (result['startDate'] != null) _startDate = result['startDate']!;
        if (result['endDate'] != null) {
          _endDate = result['endDate']!;
        } else {
          _endDate = result['startDate']!.add(const Duration(days: 30));
        }
      });
    }
  }
}

