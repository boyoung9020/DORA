import '../models/comment.dart';
import '../models/task.dart';
import '../utils/api_client.dart';

class SearchResult {
  final String query;
  final List<Task> tasks;
  final List<Comment> comments;
  final int taskTotal;
  final bool hasMore;

  const SearchResult({
    required this.query,
    required this.tasks,
    required this.comments,
    this.taskTotal = 0,
    this.hasMore = false,
  });

  factory SearchResult.empty(String query) {
    return SearchResult(query: query, tasks: const [], comments: const []);
  }
}

class SearchService {
  Future<SearchResult> search({
    required String query,
    String? workspaceId,
    String? projectId,
    String? taskStatus,
    String? taskPriority,
    String sortBy = 'updated_at',
    String sortOrder = 'desc',
    int skip = 0,
    int limit = 30,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'skip': '$skip',
      'limit': '$limit',
    };
    if (workspaceId != null) queryParams['workspace_id'] = workspaceId;
    if (projectId != null) queryParams['project_id'] = projectId;
    if (taskStatus != null && taskStatus.isNotEmpty) {
      queryParams['task_status'] = taskStatus;
    }
    if (taskPriority != null && taskPriority.isNotEmpty) {
      queryParams['task_priority'] = taskPriority;
    }

    final response =
        await ApiClient.get('/api/search/', queryParams: queryParams);
    final data = ApiClient.handleResponse(response);

    final tasks = (data['tasks'] as List<dynamic>? ?? [])
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
    final comments = (data['comments'] as List<dynamic>? ?? [])
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();

    final taskTotal = data['task_total'] is int
        ? data['task_total'] as int
        : int.tryParse('${data['task_total']}') ?? tasks.length;
    final hasMore = data['has_more'] == true ||
        (data['has_more'] == 1) ||
        (taskTotal > skip + tasks.length);

    return SearchResult(
      query: data['query']?.toString() ?? query,
      tasks: tasks,
      comments: comments,
      taskTotal: taskTotal,
      hasMore: hasMore,
    );
  }
}
