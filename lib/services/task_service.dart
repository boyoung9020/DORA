import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../utils/api_client.dart';

/// 태스크 서비스 클래스
/// 
/// 이 클래스는 태스크 데이터 관리 기능을 담당합니다:
/// - 태스크 생성
/// - 태스크 수정
/// - 태스크 삭제
/// - 태스크 조회
class TaskService {
  /// 모든 태스크 가져오기
  Future<List<Task>> getAllTasks({String? projectId, TaskStatus? status}) async {
    try {
      final queryParams = <String, String>{};
      if (projectId != null) {
        queryParams['project_id'] = projectId;
      }
      if (status != null) {
        queryParams['status'] = status.name;
      }
      
      final response = await ApiClient.get(
        '/api/tasks',
        queryParams: queryParams.isEmpty ? null : queryParams,
      );
      
      final tasksData = ApiClient.handleListResponse(response);
      return tasksData.map((json) => Task.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('태스크 목록 가져오기 실패: $e');
    }
  }

  /// 새 태스크 생성
  Future<Task> createTask({
    required String title,
    String description = '',
    TaskStatus status = TaskStatus.backlog,
    required String projectId,
    DateTime? startDate,
    DateTime? endDate,
    String detail = '',
    TaskPriority priority = TaskPriority.p2,
    List<String>? assignedMemberIds,
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/tasks',
        body: {
          'title': title,
          'description': description,
          'status': status.name,
          'project_id': projectId,
          'start_date': startDate?.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
          'detail': detail,
          'priority': priority.name,
          'assigned_member_ids': assignedMemberIds ?? [],
        },
      );
      
      final taskData = ApiClient.handleResponse(response);
      return Task.fromJson(taskData);
    } catch (e) {
      throw Exception('태스크 생성 실패: $e');
    }
  }

  /// 태스크 업데이트
  Future<void> updateTask(Task task) async {
    try {
      final body = <String, dynamic>{
        'title': task.title,
        'description': task.description,
        'status': task.status.name,
        'start_date': task.startDate?.toIso8601String(),
        'end_date': task.endDate?.toIso8601String(),
        'detail': task.detail,
        'priority': task.priority.name,
        'assigned_member_ids': task.assignedMemberIds,
      };
      
      final response = await ApiClient.patch(
        '/api/tasks/${task.id}',
        body: body,
      );
      
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('태스크 업데이트 실패: $e');
    }
  }

  /// 태스크 삭제
  Future<void> deleteTask(String taskId) async {
    try {
      final response = await ApiClient.delete('/api/tasks/$taskId');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('태스크 삭제 실패: $e');
    }
  }

  /// 상태별 태스크 가져오기
  Future<List<Task>> getTasksByStatus(TaskStatus status, {String? projectId}) async {
    return getAllTasks(projectId: projectId, status: status);
  }

  /// 프로젝트별 태스크 가져오기
  Future<List<Task>> getTasksByProject(String projectId) async {
    return getAllTasks(projectId: projectId);
  }

  /// 태스크 상태 변경
  Future<void> changeTaskStatus(String taskId, TaskStatus newStatus) async {
    try {
      // FastAPI는 쿼리 파라미터로 new_status를 받음
      final uri = Uri.parse('${ApiClient.baseUrl}/api/tasks/$taskId/status')
          .replace(queryParameters: {'new_status': newStatus.name});
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      final token = await ApiClient.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.patch(uri, headers: headers);
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('태스크 상태 변경 실패: $e');
    }
  }
}
