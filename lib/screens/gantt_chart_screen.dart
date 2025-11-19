import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../models/task.dart';
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

    // 현재 프로젝트의 태스크만 필터링
    final projectTasks = currentProjectId != null
        ? taskProvider.tasks.where((task) => task.projectId == currentProjectId).toList()
        : taskProvider.tasks;

    // 태스크들 중 가장 빠른 날짜 찾기
    if (projectTasks.isNotEmpty) {
      DateTime? earliestDate;
      for (final task in projectTasks) {
        final taskStart = task.startDate ?? task.createdAt;
        if (earliestDate == null || taskStart.isBefore(earliestDate)) {
          earliestDate = taskStart;
        }
      }
      if (earliestDate != null) {
        // 가장 빠른 날짜를 시작일로 설정 (약간의 여유 공간 추가)
        final calculatedStartDate = DateTime(
          earliestDate.year,
          earliestDate.month,
          earliestDate.day,
        ).subtract(const Duration(days: 7));
        
        // 시작일이 변경되었을 때만 업데이트
        if (_startDate != calculatedStartDate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _startDate = calculatedStartDate;
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
                  '작업',
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
                      return Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: colorScheme.onSurface.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            sortedTasks[index].title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
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
                          return _buildGanttBar(
                            context,
                            sortedTasks[index],
                            colorScheme,
                            dayWidth,
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

  /// 날짜 헤더
  Widget _buildDateHeader(
    BuildContext context,
    ColorScheme colorScheme,
    double dayWidth,
  ) {
    final days = _endDate.difference(_startDate).inDays;
    final weeks = (days / 7).ceil();

    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weeks,
        itemBuilder: (context, weekIndex) {
          final weekStart = _startDate.add(Duration(days: weekIndex * 7));
          return Container(
            width: dayWidth * 7,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weekStart.month}/${weekStart.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(7, (dayIndex) {
                    final date = weekStart.add(Duration(days: dayIndex));
                    if (date.isAfter(_endDate)) return const SizedBox.shrink();
                    return Expanded(
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 간트 바 위젯
  Widget _buildGanttBar(
    BuildContext context,
    Task task,
    ColorScheme colorScheme,
    double dayWidth,
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
      height: 52,
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
            size: Size(days * dayWidth, 52),
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
            top: 10,
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

