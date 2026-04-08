import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/comment.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/search_service.dart';
import '../services/task_service.dart';
import 'task_detail_screen.dart';

const _kRecentSearchKey = 'global_search_recent_queries';
const _kRecentMax = 10;

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.workspaceId,
    this.projectId,
  });

  final String? workspaceId;
  final String? projectId;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final SearchService _searchService = SearchService();
  final TaskService _taskService = TaskService();

  Timer? _debounce;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  SearchResult _result = SearchResult.empty('');
  List<String> _recentQueries = [];

  String? _taskStatus; // API: backlog, ready, inProgress, inReview, done
  String? _taskPriority; // p0..p3
  String _sortBy = 'updated_at';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentSearchKey) ?? [];
    if (mounted) setState(() => _recentQueries = list);
  }

  Future<void> _saveRecent(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final next = <String>[
      trimmed,
      ..._recentQueries.where((e) => e != trimmed),
    ].take(_kRecentMax).toList();
    await prefs.setStringList(_kRecentSearchKey, next);
    if (mounted) setState(() => _recentQueries = next);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value.trim(), reset: true);
    });
  }

  Future<void> _runSearch(String query, {bool reset = true}) async {
    if (query.isEmpty) {
      setState(() => _result = SearchResult.empty(''));
      return;
    }

    if (reset) {
      setState(() => _isLoading = true);
    } else {
      if (_isLoadingMore || !_result.hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    final skip = reset ? 0 : _result.tasks.length;

    try {
      final result = await _searchService.search(
        query: query,
        workspaceId: widget.workspaceId,
        projectId: widget.projectId,
        taskStatus: _taskStatus,
        taskPriority: _taskPriority,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        skip: skip,
        limit: 30,
      );
      if (!mounted) return;

      if (reset) {
        await _saveRecent(query);
        setState(() {
          _result = result;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        final seenTasks = {..._result.tasks.map((t) => t.id)};
        final mergedTasks = [
          ..._result.tasks,
          ...result.tasks.where((t) => !seenTasks.contains(t.id)),
        ];
        final seenC = {..._result.comments.map((c) => c.id)};
        final mergedComments = [
          ..._result.comments,
          ...result.comments.where((c) => !seenC.contains(c.id)),
        ];
        setState(() {
          _result = SearchResult(
            query: result.query,
            tasks: mergedTasks,
            comments: mergedComments,
            taskTotal: result.taskTotal,
            hasMore: result.hasMore,
          );
          _isLoadingMore = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openTaskById(String taskId) async {
    final taskProvider = context.read<TaskProvider>();
    Task? task;
    for (final t in taskProvider.tasks) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    task ??= await _taskService.getTaskById(taskId);
    if (task == null || !mounted) return;

    await showGeneralDialog(
      context: context,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          TaskDetailScreen(task: task!),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  TextSpan _highlightText(
    String text,
    String query,
    TextStyle baseStyle,
    TextStyle hitStyle,
  ) {
    if (query.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;
    final children = <TextSpan>[];

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx < 0) {
        children.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (idx > start) {
        children.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      children.add(
        TextSpan(
          text: text.substring(idx, idx + lowerQuery.length),
          style: hitStyle,
        ),
      );
      start = idx + lowerQuery.length;
    }
    return TextSpan(children: children);
  }

  Widget _buildTaskRow(Task task, String query, ColorScheme colorScheme) {
    final base = TextStyle(color: colorScheme.onSurface);
    final hit = TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.task_alt, color: task.status.color),
      title: RichText(text: _highlightText(task.title, query, base, hit)),
      subtitle: task.description.isNotEmpty
          ? RichText(
              text: _highlightText(
                task.description,
                query,
                base.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7)),
                hit,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () => _openTaskById(task.id),
    );
  }

  Widget _buildCommentRow(
    Comment comment,
    String query,
    ColorScheme colorScheme,
  ) {
    final base = TextStyle(color: colorScheme.onSurface);
    final hit = TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.comment_outlined),
      title: RichText(
        text: _highlightText(comment.content, query, base, hit),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(comment.username),
      onTap: () => _openTaskById(comment.taskId),
    );
  }

  Widget _filterBar(ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String?>(
          value: _taskStatus,
          hint: const Text('상태'),
          items: [
            const DropdownMenuItem(value: null, child: Text('전체 상태')),
            ...[
              ('backlog', '백로그'),
              ('ready', '준비됨'),
              ('inProgress', '진행 중'),
              ('inReview', '검토 중'),
              ('done', '완료'),
            ].map(
              (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
            ),
          ],
          onChanged: (v) {
            setState(() => _taskStatus = v);
            final q = _controller.text.trim();
            if (q.isNotEmpty) _runSearch(q, reset: true);
          },
        ),
        DropdownButton<String?>(
          value: _taskPriority,
          hint: const Text('우선순위'),
          items: [
            const DropdownMenuItem(value: null, child: Text('전체 우선순위')),
            ...['p0', 'p1', 'p2', 'p3']
                .map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))),
          ],
          onChanged: (v) {
            setState(() => _taskPriority = v);
            final q = _controller.text.trim();
            if (q.isNotEmpty) _runSearch(q, reset: true);
          },
        ),
        DropdownButton<String>(
          value: _sortBy,
          items: const [
            DropdownMenuItem(value: 'updated_at', child: Text('정렬: 수정일')),
            DropdownMenuItem(value: 'created_at', child: Text('정렬: 생성일')),
            DropdownMenuItem(value: 'title', child: Text('정렬: 제목')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _sortBy = v);
            final q = _controller.text.trim();
            if (q.isNotEmpty) _runSearch(q, reset: true);
          },
        ),
        ToggleButtons(
          isSelected: [_sortOrder == 'desc', _sortOrder == 'asc'],
          onPressed: (i) {
            setState(() => _sortOrder = i == 0 ? 'desc' : 'asc');
            final q = _controller.text.trim();
            if (q.isNotEmpty) _runSearch(q, reset: true);
          },
          borderRadius: BorderRadius.circular(8),
          constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('내림차순'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('오름차순'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final query = _controller.text.trim();

    return Dialog(
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '전체 검색 (1글자 이상)',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: _onChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _filterBar(colorScheme),
              if (_recentQueries.isNotEmpty && query.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '최근 검색',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _recentQueries.map((r) {
                    return ActionChip(
                      label: Text(r, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onPressed: () {
                        _controller.text = r;
                        _runSearch(r, reset: true);
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        '태스크 (${_result.tasks.length}${_result.taskTotal > _result.tasks.length ? ' / ${_result.taskTotal}건' : '건'})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._result.tasks
                          .map((task) => _buildTaskRow(task, query, colorScheme)),
                      if (_result.hasMore && query.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: _isLoadingMore
                                ? const CircularProgressIndicator()
                                : TextButton.icon(
                                    onPressed: () =>
                                        _runSearch(query, reset: false),
                                    icon: const Icon(Icons.expand_more),
                                    label: const Text('태스크 더 보기'),
                                  ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        '댓글 (${_result.comments.length}건)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._result.comments.map(
                        (comment) =>
                            _buildCommentRow(comment, query, colorScheme),
                      ),
                      if (_result.tasks.isEmpty &&
                          _result.comments.isEmpty &&
                          query.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            '검색 결과가 없습니다.',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
