import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    // 현재 월에 해당하는 태스크 필터링 (시작일/종료일 기준)
    final projectTasks = currentProjectId != null
        ? taskProvider.tasks.where((task) => task.projectId == currentProjectId).toList()
        : taskProvider.tasks;
    
    // 현재 월의 첫날과 마지막날
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    // 현재 월에 기간이 겹치는 태스크만 필터링
    final tasksInMonth = projectTasks.where((task) {
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;
      // 태스크 기간이 현재 월과 겹치는지 확인
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
                '달력',
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

  /// 달력 위젯
  Widget _buildCalendar(
    BuildContext context,
    List<Task> tasks,
    ColorScheme colorScheme,
  ) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    // 주 시작일 계산 (월요일 기준)
    final startOffset = (firstDayWeekday == 7) ? 0 : firstDayWeekday;
    
    // 태스크 행 인덱스 맵 생성 (같은 태스크는 같은 행에 배치)
    final taskRowMap = _buildTaskRowMap(tasks);

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
        // 날짜 그리드
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 42, // 6주 * 7일
                    itemBuilder: (context, index) {
                      if (index < startOffset || index >= startOffset + daysInMonth) {
                        return const SizedBox.shrink();
                      }

                      final day = index - startOffset + 1;
                      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                      final isSelected = date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;
                      final isToday = date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary
                                    : isToday
                                        ? colorScheme.primary.withOpacity(0.2)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isToday && !isSelected
                                    ? Border.all(
                                        color: colorScheme.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 날짜 숫자
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '$day',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected || isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),
                            // 이 날짜의 태스크 바들 (날짜 숫자 아래에 표시, 같은 태스크는 같은 행)
                            ..._buildTaskBarsForDate(
                              date,
                              tasks,
                              colorScheme,
                              isSelected,
                              taskRowMap,
                            ),
                          ],
                        ),
                      );
                    },
                  );
            },
          ),
        ),
      ],
    );
  }

  /// 태스크 행 인덱스 맵 생성 (같은 태스크는 같은 행에 배치)
  Map<String, int> _buildTaskRowMap(List<Task> tasks) {
    final Map<String, int> taskRowMap = {};
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) {
      final aStart = a.startDate ?? a.createdAt;
      final bStart = b.startDate ?? b.createdAt;
      return aStart.compareTo(bStart);
    });

    int currentRow = 0;
    for (final task in sortedTasks) {
      if (currentRow >= 3) break; // 최대 3개 행만 사용
      taskRowMap[task.id] = currentRow;
      currentRow++;
    }

    return taskRowMap;
  }

  /// 특정 날짜에 대한 태스크 바들 생성 (연속 표시, 같은 태스크는 같은 행)
  List<Widget> _buildTaskBarsForDate(
    DateTime date,
    List<Task> tasks,
    ColorScheme colorScheme,
    bool isSelected,
    Map<String, int> taskRowMap,
  ) {
    final dayTasks = _getTasksForDate(date, tasks);
    final List<Widget> bars = [];

    for (final task in dayTasks) {
      // 태스크가 행 맵에 없으면 건너뛰기 (최대 3개만 표시)
      if (!taskRowMap.containsKey(task.id) || taskRowMap[task.id]! >= 3) {
        continue;
      }

      final rowIndex = taskRowMap[task.id]!;
      final statusColor = task.status.color;
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;
      
      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
      final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
      
      // 이 날짜가 태스크의 시작일인지, 중간인지, 종료일인지 확인
      final isStart = dateOnly.isAtSameMomentAs(startOnly);
      final isEnd = dateOnly.isAtSameMomentAs(endOnly);
      final isSingleDay = isStart && isEnd;
      
      // 왼쪽/오른쪽 모서리 둥글게 처리
      BorderRadius borderRadius;
      if (isSingleDay) {
        borderRadius = BorderRadius.circular(2);
      } else if (isStart) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(2),
          bottomLeft: Radius.circular(2),
        );
      } else if (isEnd) {
        borderRadius = const BorderRadius.only(
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(2),
        );
      } else {
        borderRadius = BorderRadius.zero;
      }
      
      // 같은 행에 배치하기 위해 Positioned 사용
      bars.add(
        Positioned(
          left: 0,
          right: 0,
          top: 30.0 + (rowIndex * 18.0), // 날짜 숫자 아래 + 행 인덱스 * 간격
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: EdgeInsets.symmetric(
              horizontal: isStart || isSingleDay ? 4 : 2,
              vertical: 1,
            ),
            constraints: const BoxConstraints(
              minHeight: 14,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(1.0),
              borderRadius: borderRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isStart || isSingleDay)
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return bars;
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
            color: colorScheme.onSurface.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final statusColor = task.status.color;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 15.0,
            blur: 20.0,
            gradientColors: [
              Colors.white.withOpacity(0.5),
              Colors.white.withOpacity(0.4),
            ],
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    ],
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
