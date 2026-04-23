import '../models/workspace.dart';
import '../models/member_stats.dart';
import '../utils/api_client.dart';

/// ?뚰겕?ㅽ럹?댁뒪 ?쒕퉬??
class WorkspaceService {
  /// ?닿? ?랁븳 ?뚰겕?ㅽ럹?댁뒪 紐⑸줉
  Future<List<Workspace>> getMyWorkspaces() async {
    final response = await ApiClient.get('/api/workspaces/');
    final data = ApiClient.handleListResponse(response);
    return data.map((json) => Workspace.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// ?뚰겕?ㅽ럹?댁뒪 ?앹꽦
  Future<Workspace> createWorkspace({required String name, String? description}) async {
    final response = await ApiClient.post(
      '/api/workspaces/',
      body: {'name': name, 'description': description},
    );
    return Workspace.fromJson(ApiClient.handleResponse(response));
  }

  /// 珥덈? ?좏겙?쇰줈 李몄뿬
  Future<Workspace> joinByToken(String inviteToken) async {
    final response = await ApiClient.post(
      '/api/workspaces/join',
      body: {'invite_token': inviteToken},
    );
    return Workspace.fromJson(ApiClient.handleResponse(response));
  }

  /// ?뚰겕?ㅽ럹?댁뒪 硫ㅻ쾭 紐⑸줉
  Future<List<WorkspaceMember>> getMembers(String workspaceId) async {
    final response = await ApiClient.get('/api/workspaces/$workspaceId/members');
    final data = ApiClient.handleListResponse(response);
    return data.map((json) => WorkspaceMember.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// 珥덈? ?좏겙 ?щ컻湲?
  Future<Workspace> regenerateInviteToken(String workspaceId) async {
    final response = await ApiClient.post('/api/workspaces/$workspaceId/invite/regenerate');
    return Workspace.fromJson(ApiClient.handleResponse(response));
  }

  /// 硫ㅻ쾭 媛뺥눜 (owner留?
  Future<void> removeMember(String workspaceId, String userId) async {
    final response = await ApiClient.delete('/api/workspaces/$workspaceId/members/$userId');
    ApiClient.handleResponse(response);
  }

  /// 워크스페이스 삭제 (owner만)
  Future<void> deleteWorkspace(String workspaceId) async {
    final response = await ApiClient.delete('/api/workspaces/$workspaceId');
    ApiClient.handleResponse(response);
  }

  /// ?뚰겕?ㅽ럹?댁뒪 ?덊눜
  Future<void> leaveWorkspace(String workspaceId) async {
    final response = await ApiClient.delete('/api/workspaces/$workspaceId/leave');
    ApiClient.handleResponse(response);
  }

  /// 珥덈? 留곹겕 ?앹꽦 (?대씪?댁뼵???ъ씠??
  /// 워크스페이스 멤버별 작업 통계
  Future<List<MemberStats>> getMemberStats(String workspaceId) async {
    final response = await ApiClient.get('/api/workspaces/$workspaceId/member-stats');
    final data = ApiClient.handleResponse(response);
    final members = data['members'] as List<dynamic>? ?? [];
    return members
        .map((json) => MemberStats.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 어제(또는 지정 날짜)의 미완료 작업 조회
  Future<List<MemberTodayTask>> getYesterdayIncompleteTasks(
    String workspaceId, {
    String? targetDate,
  }) async {
    final queryParams = <String, String>{};
    if (targetDate != null) queryParams['target_date'] = targetDate;
    final response = await ApiClient.get(
      '/api/workspaces/$workspaceId/yesterday-incomplete',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
    final data = ApiClient.handleResponse(response);
    final tasks = data['incomplete_tasks'] as List<dynamic>? ?? [];
    return tasks
        .map((json) => MemberTodayTask.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  String buildInviteLink(String inviteToken) {
    // 紐⑤컮???λ쭅???뺤옣 ?鍮? sync://join/<token>
    // ?? baseUrl/join/<token>
    return '${ApiClient.baseUrl}/join/$inviteToken';
  }
}
