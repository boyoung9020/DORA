import '../models/workspace.dart';
import '../utils/api_client.dart';

/// 워크스페이스 서비스
class WorkspaceService {
  /// 내가 속한 워크스페이스 목록
  Future<List<Workspace>> getMyWorkspaces() async {
    final response = await ApiClient.get('/api/workspaces/');
    final data = ApiClient.handleListResponse(response);
    return data.map((json) => Workspace.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// 워크스페이스 생성
  Future<Workspace> createWorkspace({required String name, String? description}) async {
    final response = await ApiClient.post(
      '/api/workspaces/',
      body: {'name': name, 'description': description},
    );
    return Workspace.fromJson(ApiClient.handleResponse(response));
  }

  /// 초대 토큰으로 참여
  Future<Workspace> joinByToken(String inviteToken) async {
    final response = await ApiClient.post(
      '/api/workspaces/join',
      body: {'invite_token': inviteToken},
    );
    return Workspace.fromJson(ApiClient.handleResponse(response));
  }

  /// 워크스페이스 멤버 목록
  Future<List<WorkspaceMember>> getMembers(String workspaceId) async {
    final response = await ApiClient.get('/api/workspaces/$workspaceId/members');
    final data = ApiClient.handleListResponse(response);
    return data.map((json) => WorkspaceMember.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// 초대 토큰 재발급
  Future<Workspace> regenerateInviteToken(String workspaceId) async {
    final response = await ApiClient.post('/api/workspaces/$workspaceId/invite/regenerate');
    return Workspace.fromJson(ApiClient.handleResponse(response));
  }

  /// 멤버 강퇴 (owner만)
  Future<void> removeMember(String workspaceId, String userId) async {
    final response = await ApiClient.delete('/api/workspaces/$workspaceId/members/$userId');
    ApiClient.handleResponse(response);
  }

  /// 워크스페이스 탈퇴
  Future<void> leaveWorkspace(String workspaceId) async {
    final response = await ApiClient.delete('/api/workspaces/$workspaceId/leave');
    ApiClient.handleResponse(response);
  }

  /// 초대 링크 생성 (클라이언트 사이드)
  String buildInviteLink(String inviteToken) {
    // 모바일 딥링크 확장 대비: dora://join/<token>
    // 웹: baseUrl/join/<token>
    return '${ApiClient.baseUrl}/join/$inviteToken';
  }
}
