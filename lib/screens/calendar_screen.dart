import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../models/task.dart';
import '../widgets/glass_container.dart';

/// 달력 화면
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  bool _isLocaleReady = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko').then((_) {
      if (mounted) {
        setState(() {
          _isLocaleReady = true;
        });
      }
    });
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

    final projectTasks = currentProjectId != null
        ? taskProvider.tasks
            .where((task) => 
                task.projectId == currentProjectId && 
                task.status != TaskStatus.backlog)
            .toList()
        : <Task>[];
    
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    final tasksInMonth = projectTasks.where((task) {
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;
      return (startDate.isBefore(lastDayOfMonth.add(const Duration(days: 1))) &&
          endDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))));
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                _isLocaleReady
                    ? DateFormat.MMMM('ko').format(_currentMonth)
                    : '${_currentMonth.month}월',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              // 이전 달 버튼
              GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.primary.withOpacity(0.3),
                  colorScheme.primary.withOpacity(0.2),
                ],
                child: IconButton(
                  icon: Icon(Icons.chevron_left, color: colorScheme.primary),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 현재 월 표시
              Text(
                '${_currentMonth.year}년 ${_currentMonth.month}월',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              // 다음 달 버튼
              GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.primary.withOpacity(0.3),
                  colorScheme.primary.withOpacity(0.2),
                ],
                child: IconButton(
                  icon: Icon(Icons.chevron_right, color: colorScheme.primary),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month + 1,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 달력
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 달력 위젯
                Expanded(
                  flex: 2,
                  child: GlassContainer(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 20.0,
                    blur: 25.0,
                    gradientColors: [
                      colorScheme.surface.withOpacity(0.4),
                      colorScheme.surface.withOpacity(0.3),
                    ],
                    child: _buildCalendar(context, tasksInMonth, colorScheme),
                  ),
                ),
                const SizedBox(width: 24),
                // 선택된 날짜의 태스크 목록
                Expanded(
                  flex: 1,
                  child: GlassContainer(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 20.0,
                    blur: 25.0,
                    gradientColors: [
                      colorScheme.surface.withOpacity(0.4),
                      colorScheme.surface.withOpacity(0.3),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _buildTaskList(
                            context,
                            _getTasksForDate(_selectedDate, tasksInMonth),
                            colorScheme,
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

  /// 특정 날짜의 태스크 가져오기
  List<Task> _getTasksForDate(DateTime date, List<Task> tasks) {
    return tasks.where((task) {
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;
      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
      final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
      return dateOnly.isAtSameMomentAs(startOnly) ||
          dateOnly.isAtSameMomentAs(endOnly) ||
          (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly));
    }).toList();
  }

  /// 달력 위젯 (주 단위 타임라인 방식)
  Widget _buildCalendar(
    BuildContext context,
    List<Task> tasks,
    ColorScheme colorScheme,
  ) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final firstDayWeekday = firstDayOfMonth.weekday;
    
    // 달력 시작일 (월요일부터 시작)
    final startOffset = (firstDayWeekday == 7) ? 0 : firstDayWeekday;
    final calendarStartDate = firstDayOfMonth.subtract(Duration(days: startOffset));
    
    // 6주치 날짜 생성
    final weeks = <List<DateTime>>[];
    for (int week = 0; week < 6; week++) {
      final weekDates = <DateTime>[];
      for (int day = 0; day < 7; day++) {
        weekDates.add(calendarStartDate.add(Duration(days: week * 7 + day)));
      }
      weeks.add(weekDates);
    }

    return Column(
      children: [
        // 요일 헤더
        Row(
          children: ['월', '화', '수', '목', '금', '토', '일'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 주 단위 행들 (스크롤 가능)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: weeks.map((weekDates) {
                return _buildWeekRow(weekDates, tasks, colorScheme);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// 한 주 행 빌드 (태스크 바를 Positioned로 배치)
  Widget _buildWeekRow(
    List<DateTime> weekDates,
    List<Task> tasks,
    ColorScheme colorScheme,
  ) {
    // 이 주에 걸리는 태스크들 필터링 및 행 배정
    final weekTasks = tasks.where((task) {
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;
      return weekDates.any((date) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return dateOnly.isAtSameMomentAs(startOnly) ||
            dateOnly.isAtSameMomentAs(endOnly) ||
            (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly));
      });
    }).toList();

    // 태스크 행 할당 (충돌 방지, 무제한)
    final taskRows = _assignTaskRows(weekTasks, weekDates);
    
    // 필요한 행 수 계산
    final maxRow = taskRows.values.isEmpty ? 0 : taskRows.values.reduce((a, b) => a > b ? a : b);
    final taskBarHeight = 12.0;
    final taskBarSpacing = 4.0;
    final dateNumberHeight = 24.0;
    final topPadding = 32.0;
    final bottomPadding = 8.0;
    final weekHeight = dateNumberHeight + topPadding + (maxRow + 1) * (taskBarHeight + taskBarSpacing) + bottomPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = constraints.maxWidth / 7;
        
        return SizedBox(
          height: weekHeight,
          child: Stack(
            children: [
              // 날짜 셀들
              Row(
              children: weekDates.map((date) {
                final isCurrentMonth = date.month == _currentMonth.month;
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: !isCurrentMonth
                                        ? colorScheme.onSurface.withOpacity(0.3)
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
              // 태스크 바들 (Positioned)
              ...taskRows.entries.map((entry) {
                final task = entry.key;
                final row = entry.value;
                return _buildTaskBar(task, weekDates, dayWidth, row, colorScheme);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  /// 태스크에 행 번호 할당 (간단한 충돌 방지)
  Map<Task, int> _assignTaskRows(List<Task> tasks, List<DateTime> weekDates) {
    final Map<Task, int> taskRows = {};
    final List<List<DateTime>> occupiedRanges = [];

    // 시작일 기준 정렬
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) {
      final aStart = a.startDate ?? a.createdAt;
      final bStart = b.startDate ?? b.createdAt;
      return aStart.compareTo(bStart);
    });

    for (final task in sortedTasks) {
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;
      
      // 이 주에서 태스크가 차지하는 날짜 범위
      final taskDates = weekDates.where((date) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return dateOnly.isAtSameMomentAs(startOnly) ||
            dateOnly.isAtSameMomentAs(endOnly) ||
            (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly));
      }).toList();

      if (taskDates.isEmpty) continue;

      // 빈 행 찾기
      int assignedRow = 0;
      for (int row = 0; row < occupiedRanges.length; row++) {
        final occupied = occupiedRanges[row];
        final hasConflict = taskDates.any((date) => occupied.contains(date));
        if (!hasConflict) {
          assignedRow = row;
          occupiedRanges[row].addAll(taskDates);
          break;
        }
        assignedRow = row + 1;
      }

      if (assignedRow >= occupiedRanges.length) {
        occupiedRanges.add(taskDates);
      }

      // 모든 태스크 표시 (제한 없음)
      taskRows[task] = assignedRow;
    }

    return taskRows;
  }

  /// 태스크 바 위젯 (Positioned로 주 전체에 걸쳐 배치)
  Widget _buildTaskBar(
    Task task,
    List<DateTime> weekDates,
    double dayWidth,
    int row,
    ColorScheme colorScheme,
  ) {
    final startDate = task.startDate ?? task.createdAt;
    final endDate = task.endDate ?? task.updatedAt;
    final statusColor = task.status.color;

    // 이 주에서 태스크 시작·종료 컬럼 찾기
    int? startCol;
    int? endCol;

    for (int i = 0; i < weekDates.length; i++) {
      final date = weekDates[i];
      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
      final endOnly = DateTime(endDate.year, endDate.month, endDate.day);

      if (dateOnly.isAtSameMomentAs(startOnly) ||
          (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly)) ||
          (startCol == null && dateOnly.isAfter(startOnly))) {
        startCol ??= i;
      }

      if (dateOnly.isAtSameMomentAs(endOnly) ||
          dateOnly.isBefore(endOnly)) {
        endCol = i;
      }
    }

    if (startCol == null || endCol == null) return const SizedBox.shrink();

    final left = startCol * dayWidth;
    final width = (endCol - startCol + 1) * dayWidth;
    final taskBarHeight = 12.0;
    final taskBarSpacing = 4.0;
    final top = 32.0 + row * (taskBarHeight + taskBarSpacing); // 날짜 숫자 아래부터 시작

    // 시작/끝 모서리 둥글게
    final dateOnly = DateTime(weekDates[startCol].year, weekDates[startCol].month, weekDates[startCol].day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    
    final isStart = dateOnly.isAtSameMomentAs(startOnly);
    final isEnd = weekDates[endCol].day == endOnly.day &&
        weekDates[endCol].month == endOnly.month &&
        weekDates[endCol].year == endOnly.year;

    BorderRadius borderRadius;
    if (isStart && isEnd) {
      borderRadius = BorderRadius.circular(4);
    } else if (isStart) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(4),
        bottomLeft: Radius.circular(4),
      );
    } else if (isEnd) {
      borderRadius = const BorderRadius.only(
        topRight: Radius.circular(4),
        bottomRight: Radius.circular(4),
      );
    } else {
      borderRadius = BorderRadius.zero;
    }

    return Positioned(
      left: left + 2,
      top: top,
      width: width - 4,
      height: taskBarHeight,
      child: Container(
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.8),
          borderRadius: borderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: isStart
            ? Text(
                task.title,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )
            : null,
      ),
    );
  }

  /// 태스크 목록 위젯
  Widget _buildTaskList(
    BuildContext context,
    List<Task> tasks,
    ColorScheme colorScheme,
  ) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          '이 날짜에 태스크가 없습니다',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final statusColor = task.status.color;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
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
        );
      },
    );
  }
}
