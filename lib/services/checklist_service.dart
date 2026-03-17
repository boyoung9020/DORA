import '../models/checklist.dart';
import '../utils/api_client.dart';

/// 체크리스트 서비스
class ChecklistService {
  /// 태스크별 체크리스트 목록 가져오기
  Future<List<Checklist>> getChecklistsByTaskId(String taskId) async {
    try {
      final response = await ApiClient.get('/api/checklists/task/$taskId');
      final data = ApiClient.handleListResponse(response);
      return data
          .map((json) => Checklist.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('체크리스트 목록 가져오기 실패: $e');
    }
  }

  /// 체크리스트 생성
  Future<Checklist> createChecklist({
    required String taskId,
    String title = 'Checklist',
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/checklists/',
        body: {'task_id': taskId, 'title': title},
      );
      final data = ApiClient.handleResponse(response);
      return Checklist.fromJson(data);
    } catch (e) {
      throw Exception('체크리스트 생성 실패: $e');
    }
  }

  /// 체크리스트 제목 수정
  Future<Checklist> updateChecklist(String checklistId, {required String title}) async {
    try {
      final response = await ApiClient.patch(
        '/api/checklists/$checklistId',
        body: {'title': title},
      );
      final data = ApiClient.handleResponse(response);
      return Checklist.fromJson(data);
    } catch (e) {
      throw Exception('체크리스트 수정 실패: $e');
    }
  }

  /// 체크리스트 삭제
  Future<void> deleteChecklist(String checklistId) async {
    try {
      final response = await ApiClient.delete('/api/checklists/$checklistId');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('체크리스트 삭제 실패: $e');
    }
  }

  /// 체크리스트 항목 추가
  Future<ChecklistItem> addItem({
    required String checklistId,
    required String content,
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/checklists/$checklistId/items',
        body: {'checklist_id': checklistId, 'content': content},
      );
      final data = ApiClient.handleResponse(response);
      return ChecklistItem.fromJson(data);
    } catch (e) {
      throw Exception('체크리스트 항목 추가 실패: $e');
    }
  }

  /// 체크리스트 항목 수정
  Future<ChecklistItem> updateItem(
    String itemId, {
    bool? isChecked,
    String? content,
    String? assigneeId,
    DateTime? dueDate,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (isChecked != null) body['is_checked'] = isChecked;
      if (content != null) body['content'] = content;
      if (assigneeId != null) body['assignee_id'] = assigneeId;
      if (dueDate != null) body['due_date'] = dueDate.toIso8601String();

      final response = await ApiClient.patch(
        '/api/checklists/items/$itemId',
        body: body,
      );
      final data = ApiClient.handleResponse(response);
      return ChecklistItem.fromJson(data);
    } catch (e) {
      throw Exception('체크리스트 항목 수정 실패: $e');
    }
  }

  /// 체크리스트 항목 삭제
  Future<void> deleteItem(String itemId) async {
    try {
      final response = await ApiClient.delete('/api/checklists/items/$itemId');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('체크리스트 항목 삭제 실패: $e');
    }
  }
}
