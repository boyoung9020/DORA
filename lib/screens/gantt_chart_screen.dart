import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../services/auth_service.dart';
import '../utils/avatar_color.dart';
import '../widgets/glass_container.dart';

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
    
    // 각 날짜마다 세로선 그리기
    for (int i = 0; i <= days; i++) {
      final x = i * dayWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
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

/// 간트 차트 화면
class GanttChartScreen extends StatefulWidget {
  const GanttChartScreen({super.key});

  @override
  State<GanttChartScreen> createState() => _GanttChartScreenState();
}

class _GanttChartScreenState extends State<GanttChartScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  final Map<String, Future<List<User>>> _assignedMembersCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskProvider = context.watch<TaskProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final currentProjectId = projectProvider.currentProject?.id;

    // 현재 프로젝트의 태스크만 필터링 (backlog 제외)
    final projectTasks = currentProjectId != null
        ? taskProvider.tasks
            .where((task) => 
                task.projectId == currentProjectId && 
                task.status != TaskStatus.backlog)
            .toList()
        : <Task>[];

    // 태스크들 중 가장 빠른 날짜 찾기
    if (projectTasks.isNotEmpty) {
      DateTime? earliestDate;
      DateTime? latestDate;
      
      for (final task in projectTasks) {
        // 시작일 기준 (startDate가 있으면 startDate, 없으면 createdAt)
        final taskStart = task.startDate ?? task.createdAt;
        if (earliestDate == null || taskStart.isBefore(earliestDate)) {
          earliestDate = taskStart;
        }
        
        // 종료일 기준 (endDate가 있으면 endDate, 없으면 updatedAt 또는 createdAt + 1일)
        final taskEnd = task.endDate ?? 
            (task.updatedAt.isAfter(task.createdAt)
                ? task.updatedAt
                : task.createdAt.add(const Duration(days: 1)));
        if (latestDate == null || taskEnd.isAfter(latestDate)) {
          latestDate = taskEnd;
        }
      }
      
      if (earliestDate != null) {
        // 가장 빠른 날짜를 시작일로 설정 (정확히 그 날짜부터)
        final calculatedStartDate = DateTime(
          earliestDate.year,
          earliestDate.month,
          earliestDate.day,
        );
        
        // 시작일로부터 정확히 한 달 후를 종료일로 설정
        final calculatedEndDate = DateTime(
          calculatedStartDate.year,
          calculatedStartDate.month + 1,
          calculatedStartDate.day,
        );
        
        // 날짜가 변경되었을 때만 업데이트
        if (_startDate != calculatedStartDate || _endDate != calculatedEndDate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _startDate = calculatedStartDate;
                _endDate = calculatedEndDate;
              });
            }
          });
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (날짜 범위 조정 버튼만)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 날짜 범위 조정 버튼
              GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.primary.withOpacity(0.3),
                  colorScheme.primary.withOpacity(0.2),
                ],
                child: IconButton(
                  icon: Icon(Icons.date_range, color: colorScheme.primary),
                  onPressed: () => _showDateRangePicker(context),
                  tooltip: '날짜 범위 설정',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 간트 차트
          Expanded(
            child: taskProvider.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  )
                : _buildGanttChart(context, projectTasks, colorScheme),
          ),
        ],
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
            colorScheme.surface.withOpacity(0.3),
            colorScheme.surface.withOpacity(0.2),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timeline,
                size: 64,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '태스크가 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 가장 빠른 작업 일자 기준으로 정렬 (시작일 기준)
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) {
      final aStart = a.startDate ?? a.createdAt;
      final bStart = b.startDate ?? b.createdAt;
      return aStart.compareTo(bStart);
    });

    final days = _endDate.difference(_startDate).inDays;
    final dayWidth = 40.0;
    const taskRowHeight = 56.0;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20.0,
      blur: 25.0,
      gradientColors: [
        colorScheme.surface.withOpacity(0.4),
        colorScheme.surface.withOpacity(0.3),
      ],
      child: Column(
        children: [
          // 헤더 (작업 이름 영역 + 날짜 영역)
          Row(
            children: [
              // 작업 이름 헤더 (고정)
              Container(
                width: 200,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: colorScheme.onSurface.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  'Task',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              // 날짜 헤더 (스크롤 가능)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: days * dayWidth,
                    child: _buildDateHeader(context, colorScheme, dayWidth),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 간트 차트 바
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작업 이름 영역 (고정)
                Container(
                  width: 200,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    itemCount: sortedTasks.length,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        height: taskRowHeight,
                        child: _buildTaskInfoTile(
                          context,
                          sortedTasks[index],
                          colorScheme,
                          taskRowHeight,
                        ),
                      );
                    },
                  ),
                ),
                // 날짜/바 영역 (스크롤 가능)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: days * dayWidth,
                      child: ListView.builder(
                        itemCount: sortedTasks.length,
                        itemBuilder: (context, index) {
                          return Container(
                            height: taskRowHeight,
                            margin: const EdgeInsets.only(left: 4, right: 4),
                            child: _buildGanttBar(
                              context,
                              sortedTasks[index],
                              colorScheme,
                              dayWidth,
                              taskRowHeight,
                            ),
                          );
                        },
                      ),
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

  Widget _buildTaskInfoTile(
    BuildContext context,
    Task task,
    ColorScheme colorScheme,
    double rowHeight,
  ) {
    final statusColor = task.status.color;
    final assignedMembers = task.assignedMemberIds;

    return Container(
      height: rowHeight,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPriorityChip(task.priority, colorScheme),
                  if (assignedMembers.isNotEmpty)
                    FutureBuilder<List<User>>(
                      future: _loadAssignedMembers(assignedMembers),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final members = snapshot.data;
                        if (members == null || members.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildAssigneeStack(members, colorScheme),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(TaskPriority priority, ColorScheme colorScheme) {
    final priorityColor = priority.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.displayName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: priorityColor,
        ),
      ),
    );
  }

  Widget _buildAssigneeStack(List<User> members, ColorScheme colorScheme) {
    if (members.isEmpty) return const SizedBox.shrink();
    final display = members.take(3).toList();
    final overflow = members.length - display.length;

    return SizedBox(
      height: 28,
      width: (display.length * 24 + (overflow > 0 ? 28 : 0)).toDouble(),
      child: Stack(
        children: [
          for (int i = 0; i < display.length; i++)
            Positioned(
              left: i * 20,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: AvatarColor.getColorForUser(display[i].id),
                child: Text(
                  AvatarColor.getInitial(display[i].username),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: display.length * 20,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: colorScheme.onSurface.withOpacity(0.4),
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<List<User>> _loadAssignedMembers(List<String> memberIds) {
    final cacheKey = memberIds.join(',');
    if (_assignedMembersCache.containsKey(cacheKey)) {
      return _assignedMembersCache[cacheKey]!;
    }

    final future = AuthService().getAllUsers().then((users) {
      return users.where((user) => memberIds.contains(user.id)).toList();
    }).catchError((_) => <User>[]);

    _assignedMembersCache[cacheKey] = future;
    return future;
  }

  /// 날짜 헤더
  Widget _buildDateHeader(
    BuildContext context,
    ColorScheme colorScheme,
    double dayWidth,
  ) {
    final days = _endDate.difference(_startDate).inDays;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 주 단위 헤더
          Container(
            height: 24,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: (days / 7).ceil(),
              itemBuilder: (context, weekIndex) {
                final weekStart = _startDate.add(Duration(days: weekIndex * 7));
                final weekEnd = weekStart.add(const Duration(days: 6));
                final actualEnd = weekEnd.isAfter(_endDate) ? _endDate : weekEnd;
                
                return Container(
                  width: dayWidth * 7,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.onSurface.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${weekStart.month}/${weekStart.day} - ${actualEnd.month}/${actualEnd.day}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 일 단위 헤더
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: days,
              itemBuilder: (context, dayIndex) {
                final date = _startDate.add(Duration(days: dayIndex));
                if (date.isAfter(_endDate)) return const SizedBox.shrink();
                
                final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                
                return Container(
                  width: dayWidth,
                  decoration: BoxDecoration(
                    color: isToday 
                        ? colorScheme.primary.withOpacity(0.1)
                        : isWeekend
                            ? colorScheme.onSurface.withOpacity(0.03)
                            : null,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.onSurface.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getWeekdayAbbr(date.weekday),
                        style: TextStyle(
                          fontSize: 9,
                          color: isWeekend
                              ? colorScheme.onSurface.withOpacity(0.5)
                              : colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isToday
                              ? colorScheme.primary
                              : isWeekend
                                  ? colorScheme.onSurface.withOpacity(0.6)
                                  : colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 요일 약자 반환
  String _getWeekdayAbbr(int weekday) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[weekday - 1];
  }

  /// 간트 바 위젯
  Widget _buildGanttBar(
    BuildContext context,
    Task task,
    ColorScheme colorScheme,
    double dayWidth,
    double rowHeight,
  ) {
    final statusColor = task.status.color;
    // 시작일과 종료일 사용 (없으면 createdAt/updatedAt 사용)
    final taskStart = task.startDate ?? task.createdAt;
    final taskEnd = task.endDate ?? 
        (task.updatedAt.isAfter(task.createdAt)
            ? task.updatedAt
            : task.createdAt.add(const Duration(days: 1)));

    // 날짜 범위 내에 있는지 확인
    if (taskStart.isAfter(_endDate) || taskEnd.isBefore(_startDate)) {
      return const SizedBox.shrink();
    }

    final startOffset = taskStart.isBefore(_startDate)
        ? 0.0
        : taskStart.difference(_startDate).inDays * dayWidth;
    final endOffset = taskEnd.isAfter(_endDate)
        ? _endDate.difference(_startDate).inDays * dayWidth
        : taskEnd.difference(_startDate).inDays * dayWidth;
    final barWidth = (endOffset - startOffset).clamp(dayWidth, double.infinity);

    final days = _endDate.difference(_startDate).inDays;

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // 날짜별 세로선 배경
          CustomPaint(
            size: Size(days * dayWidth, rowHeight),
            painter: _DateGridPainter(
              startDate: _startDate,
              endDate: _endDate,
              dayWidth: dayWidth,
              lineColor: colorScheme.onSurface.withOpacity(0.1),
            ),
          ),
          // 간트 바
          Positioned(
            left: startOffset,
            top: (rowHeight - 32) / 2,
            child: Container(
              width: barWidth,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  task.status.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 날짜 범위 선택 다이얼로그
  void _showDateRangePicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              children: [
                Text(
                  '날짜 범위 설정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _startDate = date;
                      });
                    }
                  },
                  child: Text(
                    '시작일: ${_startDate.year}-${_startDate.month}-${_startDate.day}',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
                      });
                    }
                  },
                  child: Text(
                    '종료일: ${_endDate.year}-${_endDate.month}-${_endDate.day}',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '확인',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

