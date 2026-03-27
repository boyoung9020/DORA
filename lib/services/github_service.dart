import '../models/github.dart';
import '../utils/api_client.dart';

/// GitHub 연동 서비스
class GitHubService {
  /// 프로젝트에 GitHub 레포 연결
  Future<GitHubRepo> connectRepo({
    required String projectId,
    required String repoOwner,
    required String repoName,
    String? accessToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'repo_owner': repoOwner,
        'repo_name': repoName,
      };
      if (accessToken != null && accessToken.isNotEmpty) {
        body['access_token'] = accessToken;
      }
      final response = await ApiClient.post('/api/github/$projectId/connect', body: body);
      final data = ApiClient.handleResponse(response);
      return GitHubRepo.fromJson(data);
    } catch (e) {
      throw Exception('GitHub 레포 연결 실패: $e');
    }
  }

  /// 프로젝트의 GitHub 레포 연결 해제
  Future<void> disconnectRepo(String projectId) async {
    try {
      await ApiClient.delete('/api/github/$projectId/disconnect');
    } catch (e) {
      throw Exception('GitHub 레포 연결 해제 실패: $e');
    }
  }

  /// 연결된 GitHub 레포 정보 조회
  Future<GitHubRepo?> getRepoInfo(String projectId) async {
    try {
      final response = await ApiClient.get('/api/github/$projectId/repo');
      if (response.statusCode == 404) return null;
      final data = ApiClient.handleResponse(response);
      return GitHubRepo.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// 커밋 목록 조회
  Future<List<GitHubCommit>> getCommits(
    String projectId, {
    String? branch,
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (branch != null) params['branch'] = branch;
      final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await ApiClient.get('/api/github/$projectId/commits?$query');
      final data = ApiClient.handleListResponse(response);
      return data.map((json) => GitHubCommit.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('커밋 목록 조회 실패: $e');
    }
  }

  /// 브랜치 목록 조회
  Future<List<GitHubBranch>> getBranches(String projectId) async {
    try {
      final response = await ApiClient.get('/api/github/$projectId/branches');
      final data = ApiClient.handleListResponse(response);
      return data.map((json) => GitHubBranch.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('브랜치 목록 조회 실패: $e');
    }
  }

  /// Pull Request 목록 조회
  Future<List<GitHubPullRequest>> getPullRequests(
    String projectId, {
    String state = 'open',
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final query = 'state=$state&page=$page&per_page=$perPage';
      final response = await ApiClient.get('/api/github/$projectId/pulls?$query');
      final data = ApiClient.handleListResponse(response);
      return data.map((json) => GitHubPullRequest.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('PR 목록 조회 실패: $e');
    }
  }
}
