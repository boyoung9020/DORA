import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/glass_container.dart';
import '../task_detail_screen.dart';

/// 작업에 붙은 문서 링크를 한 행으로 펼친 레코드
class _DocRow {
  final Task task;
  final Map<String, String> link;
  final String docTitle;
  final String docUrl;
  final String? host;

  _DocRow({
    required this.task,
    required this.link,
    required this.docTitle,
    required this.docUrl,
    required this.host,
  });

  factory _DocRow.from(Task task, Map<String, String> link) {
    final url = link['url']?.trim() ?? '';
    final title = (link['title']?.trim().isNotEmpty == true)
        ? link['title']!.trim()
        : (url.isNotEmpty ? url : '(제목 없음)');
    String? h;
    if (url.isNotEmpty) {
      try {
        final u = Uri.parse(url);
        if (u.host.isNotEmpty) h = u.host;
      } catch (_) {}
    }
    return _DocRow(
      task: task,
      link: link,
      docTitle: title,
      docUrl: url,
      host: h,
    );
  }
}

class DocumentsTab extends StatefulWidget {
  final List<Task> allTasks;
  final List<User> teamMembers;
  final List<User> allUsers;

  const DocumentsTab({
    super.key,
    required this.allTasks,
    required this.teamMembers,
    this.allUsers = const [],
  });

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<TaskStatus> _statusFilters = {};
  final Set<TaskPriority> _priorityFilters = {};
  final Set<String> _assigneeFilters = {};
  final Set<String> _hostFilters = {};
  String? _dateFilterMode;

  String _sortColumn = 'taskCreatedAt';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
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
        _hostFilters.isNotEmpty ||
        _dateFilterMode != null;
  }

  List<_DocRow> _flatten() {
    final out = <_DocRow>[];
    for (final t in widget.allTasks) {
      for (final link in t.documentLinks) {
        out.add(_DocRow.from(t, Map<String, String>.from(link)));
      }
    }
    return out;
  }

  Set<String> _allHosts(List<_DocRow> rows) {
    return {for (final r in rows) if (r.host != null) r.host!};
  }

  List<_DocRow> _getFilteredRows() {
    final base = _flatten();
    var rows = base.where((r) {
      final task = r.task;
      if (_statusFilters.isNotEmpty &&
          !_statusFilters.contains(task.status)) {
        return false;
      }
      if (_priorityFilters.isNotEmpty &&
          !_priorityFilters.contains(task.priority)) {
        return false;
      }
      if (_assigneeFilters.isNotEmpty) {
        if (!task.assignedMemberIds
            .any((id) => _assigneeFilters.contains(id))) {
          return false;
        }
      }
      if (_hostFilters.isNotEmpty) {
        if (r.host == null || !_hostFilters.contains(r.host)) {
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
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = task.title.toLowerCase().contains(q) ||
            task.description.toLowerCase().contains(q) ||
            r.docTitle.toLowerCase().contains(q) ||
            r.docUrl.toLowerCase().contains(q) ||
            (r.host != null && r.host!.toLowerCase().contains(q));
        if (!match) return false;
      }
      return true;
    }).toList();

    int cmpStr(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    rows.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'status':
          cmp = a.task.status.index.compareTo(b.task.status.index);
          break;
        case 'taskTitle':
          cmp = cmpStr(a.task.title, b.task.title);
          break;
        case 'docTitle':
          cmp = cmpStr(a.docTitle, b.docTitle);
          break;
        case 'host':
          cmp = cmpStr(a.host ?? '\uffff', b.host ?? '\uffff');
          break;
        case 'url':
          cmp = cmpStr(a.docUrl, b.docUrl);
          break;
        case 'priority':
          cmp = a.task.priority.index.compareTo(b.task.priority.index);
          break;
        case 'endDate':
          final ad = a.task.endDate ?? DateTime(2099);
          final bd = b.task.endDate ?? DateTime(2099);
          cmp = ad.compareTo(bd);
          break;
        case 'displayId':
          final ai = a.task.displayId ?? 1 << 30;
          final bi = b.task.displayId ?? 1 << 30;
          cmp = ai.compareTo(bi);
          break;
        case 'taskCreatedAt':
          cmp = a.task.createdAt.compareTo(b.task.createdAt);
          break;
        default:
          cmp = a.task.createdAt.compareTo(b.task.createdAt);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return rows;
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}';

  String _formatDateRange(Task task) {
    if (task.startDate == null && task.endDate == null) return '-';
    final start =
        task.startDate != null ? _formatDate(task.startDate!) : '미정';
    final end = task.endDate != null ? _formatDate(task.endDate!) : '미정';
    return '$start ~ $end';
  }

  Future<void> _openUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.hasScheme) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyUrl(BuildContext context, String url) {
    final t = url.trim();
    if (t.isEmpty) return;
    Clipboard.setData(ClipboardData(text: t));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL 복사됨'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  bool _isOpenableDocUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    return uri != null && uri.hasScheme;
  }

  Widget _docTitleCell(
    BuildContext context,
    ColorScheme colorScheme,
    _DocRow r,
  ) {
    final linked = _isOpenableDocUrl(r.docUrl);
    final pad =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10);
    final text = Text(
      r.docTitle,
      style: linked
          ? TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor:
                  colorScheme.primary.withValues(alpha: 0.35),
            )
          : TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    if (!linked) {
      return Padding(padding: pad, child: text);
    }

    return InkWell(
      onTap: () => _openUrl(r.docUrl),
      child: Padding(padding: pad, child: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final users =
        widget.allUsers.isNotEmpty ? widget.allUsers : widget.teamMembers;
    final usernameById = {for (final u in users) u.id: u};
    final filtered = _getFilteredRows();
    final hostOptions = _allHosts(_flatten()).toList()..sort();

    if (_flatten().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '문서 링크가 등록된 작업이 없습니다.\n작업 상세에서 링크를 추가할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color: colorScheme.onSurface.withValues(alpha: 0.4)),
                        hintText: '문서 제목, URL, 호스트, 작업명 검색…',
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
                    '${filtered.length}개',
                    style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters())
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _statusFilters.clear();
                        _priorityFilters.clear();
                        _assigneeFilters.clear();
                        _hostFilters.clear();
                        _dateFilterMode = null;
                      }),
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
            _buildTableHeader(context, colorScheme, hostOptions),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '조건에 맞는 문서가 없습니다.',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              )
            else
              ...filtered.map(
                  (r) => _buildRow(context, colorScheme, r, usernameById)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(
    BuildContext context,
    ColorScheme colorScheme,
    List<String> hostOptions,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: colorScheme.onSurface.withValues(alpha: 0.03),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: _colHeader(context, colorScheme,
                label: '상태',
                sortColumn: 'status',
                hasFilter: true,
                active: _statusFilters.isNotEmpty,
                onFilter: (r) => _statusMenu(context, r)),
          ),
          SizedBox(
            width: 52,
            child: _colHeader(context, colorScheme,
                label: 'ID',
                sortColumn: 'displayId',
                hasFilter: false,
                active: false),
          ),
          SizedBox(
            width: 76,
            child: _colHeader(context, colorScheme,
                label: '작성',
                sortColumn: 'taskCreatedAt',
                hasFilter: false,
                active: false),
          ),
          Expanded(
            flex: 2,
            child: _colHeader(context, colorScheme,
                label: '작업',
                sortColumn: 'taskTitle',
                hasFilter: false,
                active: false),
          ),
          Expanded(
            flex: 2,
            child: _colHeader(context, colorScheme,
                label: '문서 제목',
                sortColumn: 'docTitle',
                hasFilter: false,
                active: false),
          ),
          SizedBox(
            width: 130,
            child: _colHeader(context, colorScheme,
                label: '호스트',
                sortColumn: 'host',
                hasFilter: hostOptions.isNotEmpty,
                active: _hostFilters.isNotEmpty,
                onFilter: hostOptions.isEmpty
                    ? null
                    : (r) => _hostMenu(context, r, hostOptions)),
          ),
          Expanded(
            flex: 3,
            child: _colHeader(context, colorScheme,
                label: 'URL',
                sortColumn: 'url',
                hasFilter: false,
                active: false),
          ),
          SizedBox(
            width: 114,
            child: _colHeader(context, colorScheme,
                label: '우선순위',
                sortColumn: 'priority',
                hasFilter: true,
                active: _priorityFilters.isNotEmpty,
                onFilter: (r) => _priorityMenu(context, r)),
          ),
          SizedBox(
            width: 118,
            child: _colHeader(context, colorScheme,
                label: '기간',
                sortColumn: 'endDate',
                hasFilter: true,
                active: _dateFilterMode != null,
                onFilter: (r) => _dateMenu(context, r)),
          ),
          SizedBox(
            width: 120,
            child: _colHeader(context, colorScheme,
                label: '담당자',
                sortColumn: null,
                hasFilter: true,
                active: _assigneeFilters.isNotEmpty,
                onFilter: (r) => _assigneeMenu(context, r)),
          ),
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(
                '열기/복사',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colHeader(
    BuildContext context,
    ColorScheme colorScheme, {
    required String label,
    required String? sortColumn,
    required bool hasFilter,
    required bool active,
    void Function(Rect rect)? onFilter,
  }) {
    final sortOn = sortColumn != null && _sortColumn == sortColumn;
    final headerColor = (active || sortOn)
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: headerColor),
            ),
          ),
          if (hasFilter && onFilter != null)
            _FilterIconButton(
                isActive: active, color: headerColor, onTap: onFilter),
          if (sortColumn != null)
            SizedBox(
              width: 22,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                splashRadius: 14,
                icon: Icon(
                  sortOn
                      ? (_sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                      : Icons.arrow_upward,
                  color: sortOn
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.55),
                  size: 15,
                ),
                onPressed: () => setState(() {
                  if (_sortColumn == sortColumn) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortColumn = sortColumn;
                    _sortAscending = true;
                  }
                }),
                tooltip: sortOn
                    ? (_sortAscending ? '내림차순' : '오름차순')
                    : '정렬',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ColorScheme colorScheme,
    _DocRow r,
    Map<String, User> usersById,
  ) {
    final task = r.task;
    final statusColor = task.status.color;
    final priorityColor = task.priority.color;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
          ),
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                task.displayId != null ? '#${task.displayId}' : '-',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 4),
              child: Text(
                '${task.createdAt.month}/${task.createdAt.day}',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () {
                showGeneralDialog(
                  context: context,
                  transitionDuration: Duration.zero,
                  pageBuilder: (ctx, _, __) => TaskDetailScreen(task: task),
                  transitionBuilder: (ctx, _, __, child) => child,
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: colorScheme.primary.withValues(alpha: 0.35),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _docTitleCell(context, colorScheme, r),
          ),
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 6, right: 4),
              child: Text(
                r.host ?? '—',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: SelectableText(
                r.docUrl.isEmpty ? '—' : r.docUrl,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.3,
                ),
                maxLines: 3,
              ),
            ),
          ),
          SizedBox(
            width: 114,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
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
          ),
          SizedBox(
            width: 118,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 8),
              child: Text(
                _formatDateRange(task),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 8),
              child: _assigneeText(task.assignedMemberIds, usersById, colorScheme),
            ),
          ),
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (r.docUrl.isNotEmpty) ...[
                    IconButton(
                      icon: Icon(Icons.open_in_new,
                          size: 18,
                          color: colorScheme.primary.withValues(alpha: 0.85)),
                      tooltip: '열기',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openUrl(r.docUrl),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy_outlined,
                          size: 18,
                          color: colorScheme.onSurface.withValues(alpha: 0.45)),
                      tooltip: 'URL 복사',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyUrl(context, r.docUrl),
                    ),
                  ] else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assigneeText(
    List<String> ids,
    Map<String, User> usersById,
    ColorScheme colorScheme,
  ) {
    if (ids.isEmpty) {
      return Text('-',
          style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.4)));
    }
    final names = ids.map((id) => usersById[id]?.username ?? '?').join(', ');
    return Text(names,
        style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.7)),
        maxLines: 2,
        overflow: TextOverflow.ellipsis);
  }

  void _statusMenu(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: [
        ...TaskStatus.values.map((status) {
          final sel = _statusFilters.contains(status);
          return PopupMenuItem<void>(
            height: 36,
            onTap: () => setState(() {
              if (sel) {
                _statusFilters.remove(status);
              } else {
                _statusFilters.add(status);
              }
            }),
            child: Row(children: [
              Icon(sel ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: sel
                      ? status.color
                      : colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text(status.displayName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          sel ? FontWeight.w600 : FontWeight.normal,
                      color: sel ? status.color : colorScheme.onSurface)),
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

  void _priorityMenu(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: [
        ...TaskPriority.values.map((p) {
          final sel = _priorityFilters.contains(p);
          return PopupMenuItem<void>(
            height: 36,
            onTap: () => setState(() {
              if (sel) {
                _priorityFilters.remove(p);
              } else {
                _priorityFilters.add(p);
              }
            }),
            child: Row(children: [
              Icon(sel ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: sel
                      ? p.color
                      : colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text(p.displayName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          sel ? FontWeight.w600 : FontWeight.normal,
                      color: sel ? p.color : colorScheme.onSurface)),
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

  void _dateMenu(BuildContext context, Rect buttonRect) {
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
        final sel = _dateFilterMode == option.key;
        return PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _dateFilterMode = option.key),
          child: Row(children: [
            Icon(
                sel
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: sel
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(option.value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel
                        ? colorScheme.primary
                        : colorScheme.onSurface)),
          ]),
        );
      }).toList(),
    );
  }

  void _assigneeMenu(BuildContext context, Rect buttonRect) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: [
        ...widget.teamMembers.map((user) {
          final sel = _assigneeFilters.contains(user.id);
          return PopupMenuItem<void>(
            height: 36,
            onTap: () => setState(() {
              if (sel) {
                _assigneeFilters.remove(user.id);
              } else {
                _assigneeFilters.add(user.id);
              }
            }),
            child: Row(children: [
              Icon(sel ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: sel
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text(user.username,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      color: sel
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

  void _hostMenu(
      BuildContext context, Rect buttonRect, List<String> hosts) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: [
        ...hosts.map((h) {
          final sel = _hostFilters.contains(h);
          return PopupMenuItem<void>(
            height: 36,
            onTap: () => setState(() {
              if (sel) {
                _hostFilters.remove(h);
              } else {
                _hostFilters.add(h);
              }
            }),
            child: Row(children: [
              Icon(sel ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: sel
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(h,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel
                            ? colorScheme.primary
                            : colorScheme.onSurface)),
              ),
            ]),
          );
        }),
        PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _hostFilters.clear()),
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
