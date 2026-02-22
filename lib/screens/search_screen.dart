import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comment.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/search_service.dart';
import '../services/task_service.dart';
import 'task_detail_screen.dart';

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
  SearchResult _result = const SearchResult(query: '', tasks: [], comments: []);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    if (query.length < 2) {
      setState(() => _result = SearchResult.empty(query));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await _searchService.search(
        query: query,
        workspaceId: widget.workspaceId,
        projectId: widget.projectId,
      );
      if (mounted) {
        setState(() => _result = result);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
      pageBuilder: (context, animation, secondaryAnimation) => TaskDetailScreen(task: task!),
      transitionBuilder: (context, animation, secondaryAnimation, child) => child,
    );
  }

  TextSpan _highlightText(String text, String query, TextStyle baseStyle, TextStyle hitStyle) {
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
      children.add(TextSpan(text: text.substring(idx, idx + lowerQuery.length), style: hitStyle));
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
                base.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                hit,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () => _openTaskById(task.id),
    );
  }

  Widget _buildCommentRow(Comment comment, String query, ColorScheme colorScheme) {
    final base = TextStyle(color: colorScheme.onSurface);
    final hit = TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.comment_outlined),
      title: RichText(
        text: _highlightText(
          comment.content,
          query,
          base,
          hit,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(comment.username),
      onTap: () => _openTaskById(comment.taskId),
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
                        hintText: '전체 검색 (최소 2글자)',
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
              const SizedBox(height: 12),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        '태스크 (${_result.tasks.length}건)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._result.tasks.map((task) => _buildTaskRow(task, query, colorScheme)),
                      const SizedBox(height: 16),
                      Text(
                        '댓글 (${_result.comments.length}건)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._result.comments.map((comment) => _buildCommentRow(comment, query, colorScheme)),
                      if (_result.tasks.isEmpty && _result.comments.isEmpty && query.length >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            '검색 결과가 없습니다.',
                            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
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
