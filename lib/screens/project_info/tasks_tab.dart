import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/glass_container.dart';
import '../task_detail_screen.dart';

class TasksTab extends StatefulWidget {
  final List<Task> allTasks;
  final List<User> teamMembers;
  final List<User> allUsers;

  const TasksTab({
    super.key,
    required this.allTasks,
    required this.teamMembers,
    this.allUsers = const [],
  });

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<TaskStatus> _statusFilters = {};
  final Set<TaskPriority> _priorityFilters = {};
  final Set<String> _assigneeFilters = {};
  String? _dateFilterMode;

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _hasActiveFilters() {
    return _statusFilters.isNotEmpty ||
        _priorityFilters.isNotEmpty ||
        _assigneeFilters.isNotEmpty ||
        _dateFilterMode != null;
  }

  List<Task> _getFilteredTasks() {
    var filtered = widget.allTasks.where((task) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!task.title.toLowerCase().contains(q) &&
            !task.description.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_statusFilters.isNotEmpty && !_statusFilters.contains(task.status)) {
        return false;
      }
      if (_priorityFilters.isNotEmpty &&
          !_priorityFilters.contains(task.priority)) {
        return false;
      }
      if (_assigneeFilters.isNotEmpty) {
        if (!task.assignedMemberIds.any((id) => _assigneeFilters.contains(id))) {
          return false;
        }
      }
      if (_dateFilterMode != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final endDate = task.endDate;
        switch (_dateFilterMode) {
          case 'today':
            if (endDate == null) return false;
            final end = DateTime(endDate.year, endDate.month, endDate.day);
            if (end != today) return false;
            break;
          case 'thisWeek':
            if (endDate == null) return false;
            final weekEnd = today.add(Duration(days: 7 - today.weekday));
            if (endDate.isAfter(weekEnd) || endDate.isBefore(today)) {
              return false;
            }
            break;
          case 'thisMonth':
            if (endDate == null) return false;
            if (endDate.month != now.month || endDate.year != now.year) {
              return false;
            }
            break;
          case 'overdue':
            if (endDate == null) return false;
            if (!endDate.isBefore(today)) return false;
            if (task.status == TaskStatus.done) return false;
            break;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'status':
          cmp = a.status.index.compareTo(b.status.index);
          break;
        case 'title':
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'priority':
          cmp = a.priority.index.compareTo(b.priority.index);
          break;
        case 'endDate':
          if (a.endDate == null && b.endDate == null) {
            cmp = 0;
          } else if (a.endDate == null) {
            cmp = 1;
          } else if (b.endDate == null) {
            cmp = -1;
          } else {
            cmp = a.endDate!.compareTo(b.endDate!);
          }
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

  String _formatDate(DateTime date) => '${date.month}/${date.day}';

  String _formatDateRange(Task task) {
    if (task.startDate == null && task.endDate == null) return '-';
    final start =
        task.startDate != null ? _formatDate(task.startDate!) : '미정';
    final end = task.endDate != null ? _formatDate(task.endDate!) : '미정';
    return '$start ~ $end';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lookupUsers = widget.allUsers.isNotEmpty ? widget.allUsers : widget.teamMembers;
    final usernameById = {
      for (final u in lookupUsers) u.id: u,
    };
    final filteredTasks = _getFilteredTasks();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        blur: 20,
        gradientColors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.8),
        ],
        shadowBlurRadius: 8,
        shadowOffset: const Offset(0, 2),
        child: Column(
          children: [
            // ─── 검색 + 필터 초기화 헤더
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.4)),
                        hintText: '작업 검색...',
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.4)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: colorScheme.outlineVariant),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${filteredTasks.length}개',
                    style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters())
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _statusFilters.clear();
                          _priorityFilters.clear();
                          _assigneeFilters.clear();
                          _dateFilterMode = null;
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('필터 초기화'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            // ─── 테이블 헤더
            _buildTableHeader(context, colorScheme),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            // ─── 테이블 본문
            if (filteredTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text('작업이 없습니다.',
                    style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5))),
              )
            else
              ...filteredTasks.map((task) =>
                  _buildTaskRow(context, colorScheme, task, usernameById)),
          ],
        ),
      ),
    );
  }

  // ─── 테이블 헤더

  Widget _buildTableHeader(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: colorScheme.onSurface.withValues(alpha: 0.03),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: _buildColumnHeader(context, colorScheme,
                label: '상태',
                sortColumn: 'status',
                hasFilter: true,
                isFilterActive: _statusFilters.isNotEmpty,
                onFilterTap: (r) => _showStatusFilterDropdown(context, r)),
          ),
          Expanded(
            child: _buildColumnHeader(context, colorScheme,
                label: '제목',
                sortColumn: 'title',
                hasFilter: false,
                isFilterActive: false),
          ),
          SizedBox(
            width: 130,
            child: _buildColumnHeader(context, colorScheme,
                label: '우선순위',
                sortColumn: 'priority',
                hasFilter: true,
                isFilterActive: _priorityFilters.isNotEmpty,
                onFilterTap: (r) => _showPriorityFilterDropdown(context, r)),
          ),
          SizedBox(
            width: 140,
            child: _buildColumnHeader(context, colorScheme,
                label: '기간',
                sortColumn: 'endDate',
                hasFilter: true,
                isFilterActive: _dateFilterMode != null,
                onFilterTap: (r) => _showDateFilterDropdown(context, r)),
          ),
          SizedBox(
            width: 140,
            child: _buildColumnHeader(context, colorScheme,
                label: '담당자',
                sortColumn: null,
                hasFilter: true,
                isFilterActive: _assigneeFilters.isNotEmpty,
                onFilterTap: (r) => _showAssigneeFilterDropdown(context, r)),
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
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: headerColor)),
          const SizedBox(width: 2),
          if (hasFilter)
            _FilterIconButton(
                isActive: isFilterActive,
                color: headerColor,
                onTap: onFilterTap),
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
                      ? (_sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
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

  // ─── 테이블 행

  Widget _buildTaskRow(
    BuildContext context,
    ColorScheme colorScheme,
    Task task,
    Map<String, User> usersById,
  ) {
    final statusColor = task.status.color;
    final priorityColor = task.priority.color;

    return InkWell(
      onTap: () {
        showGeneralDialog(
          context: context,
          transitionDuration: Duration.zero,
          pageBuilder: (ctx, _, __) => TaskDetailScreen(task: task),
          transitionBuilder: (ctx, _, __, child) => child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          children: [
            // 상태
            SizedBox(
              width: 120,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(task.status.displayName,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
              ),
            ),
            // 제목
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (task.description.isNotEmpty)
                      Text(task.description,
                          style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.55)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            // 우선순위
            SizedBox(
              width: 130,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(task.priority.displayName,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: priorityColor)),
                ),
              ),
            ),
            // 기간
            SizedBox(
              width: 140,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_formatDateRange(task),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.65))),
              ),
            ),
            // 담당자
            SizedBox(
              width: 140,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildAssigneeNames(
                    task.assignedMemberIds, usersById, colorScheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeNames(
    List<String> ids,
    Map<String, User> usersById,
    ColorScheme colorScheme,
  ) {
    if (ids.isEmpty) {
      return Text('-',
          style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.4)));
    }
    final names = ids.map((id) => usersById[id]?.username ?? '?').toList();
    return Text(names.join(', '),
        style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.7)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis);
  }

  // ─── 필터 드롭다운

  void _showStatusFilterDropdown(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: [
        ...TaskStatus.values.map((status) {
          final isSelected = _statusFilters.contains(status);
          return PopupMenuItem<void>(
            height: 36,
            onTap: () => setState(() {
              if (isSelected) {
                _statusFilters.remove(status);
              } else {
                _statusFilters.add(status);
              }
            }),
            child: Row(children: [
              Icon(
                  isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected
                      ? status.color
                      : colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: status.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(status.displayName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected ? status.color : colorScheme.onSurface)),
            ]),
          );
        }),
        PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _statusFilters.clear()),
          child: Row(children: [
            Icon(Icons.clear_all,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text('초기화',
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
      ],
    );
  }

  void _showPriorityFilterDropdown(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: [
        ...TaskPriority.values.map((priority) {
          final isSelected = _priorityFilters.contains(priority);
          return PopupMenuItem<void>(
            height: 36,
            onTap: () => setState(() {
              if (isSelected) {
                _priorityFilters.remove(priority);
              } else {
                _priorityFilters.add(priority);
              }
            }),
            child: Row(children: [
              Icon(
                  isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected
                      ? priority.color
                      : colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: priority.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(priority.displayName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? priority.color
                          : colorScheme.onSurface)),
            ]),
          );
        }),
        PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _priorityFilters.clear()),
          child: Row(children: [
            Icon(Icons.clear_all,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text('초기화',
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
      ],
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
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: options.map((option) {
        final isSelected = _dateFilterMode == option.key;
        return PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _dateFilterMode = option.key),
          child: Row(children: [
            Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(option.value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface)),
          ]),
        );
      }).toList(),
    );
  }

  void _showAssigneeFilterDropdown(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: [
        ...widget.teamMembers.map((user) {
          final isSelected = _assigneeFilters.contains(user.id);
          return PopupMenuItem<void>(
            height: 36,
            onTap: () => setState(() {
              if (isSelected) {
                _assigneeFilters.remove(user.id);
              } else {
                _assigneeFilters.add(user.id);
              }
            }),
            child: Row(children: [
              Icon(
                  isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text(user.username,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface)),
            ]),
          );
        }),
        PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _assigneeFilters.clear()),
          child: Row(children: [
            Icon(Icons.clear_all,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text('초기화',
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
      ],
    );
  }
}

// ─── 필터 아이콘 버튼

class _FilterIconButton extends StatelessWidget {
  final bool isActive;
  final Color color;
  final void Function(Rect rect)? onTap;

  const _FilterIconButton(
      {required this.isActive, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 15,
        splashRadius: 14,
        icon: Icon(Icons.filter_list,
            color: isActive ? color : color.withValues(alpha: 0.55), size: 15),
        onPressed: () {
          final box = context.findRenderObject() as RenderBox;
          final offset = box.localToGlobal(Offset.zero);
          final rect = Rect.fromLTWH(
              offset.dx, offset.dy, box.size.width, box.size.height);
          onTap?.call(rect);
        },
        tooltip: '필터',
      ),
    );
  }
}
