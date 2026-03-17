import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../models/task.dart';
import '../widgets/glass_container.dart';
import 'task_detail_screen.dart';

/// ?щ젰 ?붾㈃
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  bool _isLocaleReady = false;
  String? _lastLoadedProjectId;
  bool? _lastLoadedAllMode;

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskProvider = context.watch<TaskProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final currentProjectId = projectProvider.currentProject?.id;
    final isAllMode = projectProvider.isAllProjectsMode;

    final projectTasks = isAllMode
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

    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );

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
          // ?ㅻ뜑
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
              // ?댁쟾 ??踰꾪듉
              GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.primary.withValues(alpha: 0.3),
                  colorScheme.primary.withValues(alpha: 0.2),
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
              // ?꾩옱 ???쒖떆
              Text(
                '${_currentMonth.year}년 ${_currentMonth.month}월',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              // ?ㅼ쓬 ??踰꾪듉
              GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.primary.withValues(alpha: 0.3),
                  colorScheme.primary.withValues(alpha: 0.2),
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
          // ?щ젰
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ?щ젰 ?꾩젽
                Expanded(
                  flex: 2,
                  child: GlassContainer(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 20.0,
                    blur: 25.0,
                    gradientColors: [
                      colorScheme.surface.withValues(alpha: 0.4),
                      colorScheme.surface.withValues(alpha: 0.3),
                    ],
                    child: _buildCalendar(context, tasksInMonth, colorScheme),
                  ),
                ),
                const SizedBox(width: 24),
                // ?좏깮???좎쭨???쒖뒪??紐⑸줉
                Expanded(
                  flex: 1,
                  child: GlassContainer(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 20.0,
                    blur: 25.0,
                    gradientColors: [
                      colorScheme.surface.withValues(alpha: 0.4),
                      colorScheme.surface.withValues(alpha: 0.3),
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

  /// ?뱀젙 ?좎쭨???쒖뒪??媛?몄삤湲?
  List<Task> _getTasksForDate(DateTime date, List<Task> tasks) {
    return tasks.where((task) {
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;
      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOnly = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
      return dateOnly.isAtSameMomentAs(startOnly) ||
          dateOnly.isAtSameMomentAs(endOnly) ||
          (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly));
    }).toList();
  }

  /// ?щ젰 ?꾩젽 (二??⑥쐞 ??꾨씪??諛⑹떇)
  Widget _buildCalendar(
    BuildContext context,
    List<Task> tasks,
    ColorScheme colorScheme,
  ) {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final firstDayWeekday = firstDayOfMonth.weekday;

    // ?щ젰 ?쒖옉??(?붿슂?쇰????쒖옉)
    final startOffset = (firstDayWeekday == 7) ? 0 : firstDayWeekday;
    final calendarStartDate = firstDayOfMonth.subtract(
      Duration(days: startOffset),
    );

    // 6二쇱튂 ?좎쭨 ?앹꽦
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
        // ?붿씪 ?ㅻ뜑
        Row(
          children: ['일', '월', '화', '수', '목', '금', '토'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 二??⑥쐞 ?됰뱾 (?ㅽ겕濡?媛??
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

  /// ??二???鍮뚮뱶 (?쒖뒪??諛붾? Positioned濡?諛곗튂)
  Widget _buildWeekRow(
    List<DateTime> weekDates,
    List<Task> tasks,
    ColorScheme colorScheme,
  ) {
    // ??二쇱뿉 嫄몃━???쒖뒪?щ뱾 ?꾪꽣留?諛???諛곗젙
    final weekTasks = tasks.where((task) {
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;
      return weekDates.any((date) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        final startOnly = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return dateOnly.isAtSameMomentAs(startOnly) ||
            dateOnly.isAtSameMomentAs(endOnly) ||
            (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly));
      });
    }).toList();

    // ?쒖뒪?????좊떦 (異⑸룎 諛⑹?, 臾댁젣??
    final taskRows = _assignTaskRows(weekTasks, weekDates);

    // ?꾩슂??????怨꾩궛
    final maxRow = taskRows.values.isEmpty
        ? 0
        : taskRows.values.reduce((a, b) => a > b ? a : b);
    final taskBarHeight = 12.0;
    final taskBarSpacing = 4.0;
    final dateNumberHeight = 24.0;
    final topPadding = 32.0;
    final bottomPadding = 8.0;
    final weekHeight =
        dateNumberHeight +
        topPadding +
        (maxRow + 1) * (taskBarHeight + taskBarSpacing) +
        bottomPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = constraints.maxWidth / 7;

        return SizedBox(
          height: weekHeight,
          child: Stack(
            children: [
              // ?좎쭨 ???
              Row(
                children: weekDates.map((date) {
                  final isCurrentMonth = date.month == _currentMonth.month;
                  final isSelected =
                      date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;
                  final isToday =
                      date.year == DateTime.now().year &&
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
                              ? Border.all(color: colorScheme.primary, width: 2)
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
                                          ? colorScheme.onSurface.withValues(
                                              alpha: 0.3,
                                            )
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
              // ?쒖뒪??諛붾뱾 (Positioned)
              ...taskRows.entries.map((entry) {
                final task = entry.key;
                final row = entry.value;
                return _buildTaskBar(
                  task,
                  weekDates,
                  dayWidth,
                  row,
                  colorScheme,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  /// ?쒖뒪?ъ뿉 ??踰덊샇 ?좊떦 (媛꾨떒??異⑸룎 諛⑹?)
  Map<Task, int> _assignTaskRows(List<Task> tasks, List<DateTime> weekDates) {
    final Map<Task, int> taskRows = {};
    final List<List<DateTime>> occupiedRanges = [];

    // ?쒖옉??湲곗? ?뺣젹
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) {
      final aStart = a.startDate ?? a.createdAt;
      final bStart = b.startDate ?? b.createdAt;
      return aStart.compareTo(bStart);
    });

    for (final task in sortedTasks) {
      final startDate = task.startDate ?? task.createdAt;
      final endDate = task.endDate ?? task.updatedAt;

      // ??二쇱뿉???쒖뒪?ш? 李⑥??섎뒗 ?좎쭨 踰붿쐞
      final taskDates = weekDates.where((date) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        final startOnly = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return dateOnly.isAtSameMomentAs(startOnly) ||
            dateOnly.isAtSameMomentAs(endOnly) ||
            (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly));
      }).toList();

      if (taskDates.isEmpty) continue;

      // 鍮???李얘린
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

      // 紐⑤뱺 ?쒖뒪???쒖떆 (?쒗븳 ?놁쓬)
      taskRows[task] = assignedRow;
    }

    return taskRows;
  }

  /// ?쒖뒪??諛??꾩젽 (Positioned濡?二??꾩껜??嫄몄퀜 諛곗튂)
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

    // ??二쇱뿉???쒖뒪???쒖옉쨌醫낅즺 而щ읆 李얘린
    int? startCol;
    int? endCol;

    for (int i = 0; i < weekDates.length; i++) {
      final date = weekDates[i];
      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOnly = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endOnly = DateTime(endDate.year, endDate.month, endDate.day);

      if (dateOnly.isAtSameMomentAs(startOnly) ||
          (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly)) ||
          (startCol == null && dateOnly.isAfter(startOnly))) {
        startCol ??= i;
      }

      if (dateOnly.isAtSameMomentAs(endOnly) || dateOnly.isBefore(endOnly)) {
        endCol = i;
      }
    }

    if (startCol == null || endCol == null) return const SizedBox.shrink();

    final left = startCol * dayWidth;
    final width = (endCol - startCol + 1) * dayWidth;
    final taskBarHeight = 12.0;
    final taskBarSpacing = 4.0;
    final top =
        32.0 + row * (taskBarHeight + taskBarSpacing); // ?좎쭨 ?レ옄 ?꾨옒遺???쒖옉

    // ?쒖옉/??紐⑥꽌由??κ?寃?
    final dateOnly = DateTime(
      weekDates[startCol].year,
      weekDates[startCol].month,
      weekDates[startCol].day,
    );
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);

    final isStart = dateOnly.isAtSameMomentAs(startOnly);
    final isEnd =
        weekDates[endCol].day == endOnly.day &&
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
          color: statusColor.withValues(alpha: 0.8),
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

  /// ?쒖뒪??紐⑸줉 ?꾩젽
  Widget _buildTaskList(
    BuildContext context,
    List<Task> tasks,
    ColorScheme colorScheme,
  ) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          '선택한 날짜에 일정이 없습니다',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final statusColor = task.status.color;

        return InkWell(
          onTap: () {
            showGeneralDialog(
              context: context,
              transitionDuration: Duration.zero,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  TaskDetailScreen(task: task),
              transitionBuilder: (context, animation, secondaryAnimation, child) =>
                  child,
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.brightness == Brightness.dark
                ? const Color(0xFF161B2E)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: colorScheme.brightness == Brightness.dark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFFD86B27).withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
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
        ),
        );
      },
    );
  }
}
