import '../models/comment.dart';
import '../models/task.dart';
import '../utils/api_client.dart';

class SearchResult {
  final String query;
  final List<Task> tasks;
  final List<Comment> comments;

  const SearchResult({
    required this.query,
    required this.tasks,
    required this.comments,
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
  }) async {
    final queryParams = <String, String>{
      'q': query,
    };
    if (workspaceId != null) queryParams['workspace_id'] = workspaceId;
    if (projectId != null) queryParams['project_id'] = projectId;

    final response = await ApiClient.get('/api/search/', queryParams: queryParams);
    final data = ApiClient.handleResponse(response);

    final tasks = (data['tasks'] as List<dynamic>? ?? [])
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
    final comments = (data['comments'] as List<dynamic>? ?? [])
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();

    return SearchResult(
      query: data['query']?.toString() ?? query,
      tasks: tasks,
      comments: comments,
    );
  }
}
