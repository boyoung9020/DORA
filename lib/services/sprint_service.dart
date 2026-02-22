import '../models/sprint.dart';
import '../utils/api_client.dart';

class SprintService {
  Future<List<Sprint>> getSprints({String? projectId}) async {
    try {
      final queryParams = <String, String>{};
      if (projectId != null) {
        queryParams['project_id'] = projectId;
      }
      final response = await ApiClient.get(
        '/api/sprints/',
        queryParams: queryParams.isEmpty ? null : queryParams,
      );
      final data = ApiClient.handleListResponse(response);
      return data
          .map((json) => Sprint.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load sprints: $e');
    }
  }

  Future<Sprint> createSprint({
    required String projectId,
    required String name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await ApiClient.post(
      '/api/sprints/',
      body: {
        'project_id': projectId,
        'name': name,
        'goal': goal,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      },
    );
    return Sprint.fromJson(ApiClient.handleResponse(response));
  }

  Future<Sprint> updateSprint(Sprint sprint) async {
    final response = await ApiClient.patch(
      '/api/sprints/${sprint.id}',
      body: {
        'name': sprint.name,
        'goal': sprint.goal,
        'start_date': sprint.startDate?.toIso8601String(),
        'end_date': sprint.endDate?.toIso8601String(),
        'status': sprint.status.name,
        'task_ids': sprint.taskIds,
      },
    );
    return Sprint.fromJson(ApiClient.handleResponse(response));
  }

  Future<void> deleteSprint(String sprintId) async {
    final response = await ApiClient.delete('/api/sprints/$sprintId');
    ApiClient.handleResponse(response);
  }

  Future<Sprint> addTaskToSprint(String sprintId, String taskId) async {
    final response = await ApiClient.post('/api/sprints/$sprintId/tasks/$taskId');
    return Sprint.fromJson(ApiClient.handleResponse(response));
  }

  Future<Sprint> removeTaskFromSprint(String sprintId, String taskId) async {
    final response = await ApiClient.delete('/api/sprints/$sprintId/tasks/$taskId');
    return Sprint.fromJson(ApiClient.handleResponse(response));
  }
}
