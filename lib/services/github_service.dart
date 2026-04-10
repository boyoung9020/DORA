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

  /// GitHub 원격 저장소 요약 (설명·스타·기본 브랜치 등)
  Future<GitHubRepoRemoteDetails> getRepoDetails(String projectId) async {
    final response =
        await ApiClient.get('/api/github/$projectId/repo-details');
    final data = ApiClient.handleResponse(response);
    return GitHubRepoRemoteDetails.fromJson(data);
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

  /// 전체 브랜치 커밋 그래프 조회
  Future<({List<GitHubCommit> commits, bool hasMore})> getGraph(
    String projectId, {
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      final query = 'page=$page&per_page=$perPage';
      final response = await ApiClient.get('/api/github/$projectId/graph?$query');
      final data = ApiClient.handleResponse(response);
      final commits = (data['commits'] as List<dynamic>)
          .map((json) => GitHubCommit.fromJson(json as Map<String, dynamic>))
          .toList();
      final hasMore = (data['has_more'] ?? false) as bool;
      return (commits: commits, hasMore: hasMore);
    } catch (e) {
      throw Exception('그래프 조회 실패: $e');
    }
  }

  /// 두 커밋 비교 (base...head)
  Future<GitHubCompareResult> compareCommits(
    String projectId, {
    required String base,
    required String head,
  }) async {
    final query = 'base=$base&head=$head';
    final response =
        await ApiClient.get('/api/github/$projectId/compare?$query');
    final data = ApiClient.handleResponse(response);
    return GitHubCompareResult.fromJson(data);
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

  /// Issue 목록 조회
  Future<List<GitHubIssue>> getIssues(
    String projectId, {
    String state = 'open',
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final query = 'state=$state&page=$page&per_page=$perPage';
      final response = await ApiClient.get('/api/github/$projectId/issues?$query');
      final data = ApiClient.handleListResponse(response);
      return data.map((json) => GitHubIssue.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Issue 목록 조회 실패: $e');
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

  /// Releases 목록 조회 (published_at 기준 최신순)
  Future<List<GitHubRelease>> getReleases(String projectId) async {
    try {
      final response = await ApiClient.get('/api/github/$projectId/releases');
      final data = ApiClient.handleListResponse(response);
      return data.map((json) => GitHubRelease.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('릴리즈 목록 조회 실패: $e');
    }
  }

  /// 태그 목록 조회
  Future<List<GitHubTag>> getTags(String projectId) async {
    try {
      final response = await ApiClient.get('/api/github/$projectId/tags');
      final data = ApiClient.handleListResponse(response);
      return data.map((json) => GitHubTag.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('태그 목록 조회 실패: $e');
    }
  }

  /// 경량 태그 생성 (지정 커밋 SHA)
  Future<GitHubTag> createTag(
    String projectId, {
    required String tagName,
    required String commitSha,
  }) async {
    final response = await ApiClient.post(
      '/api/github/$projectId/tags',
      body: {
        'tag_name': tagName,
        'commit_sha': commitSha,
      },
    );
    final data = ApiClient.handleResponse(response);
    return GitHubTag.fromJson(data);
  }

  /// 저장소 언어 비율 (기술 스택)
  Future<List<GitHubLanguage>> getLanguages(String projectId) async {
    try {
      final response = await ApiClient.get('/api/github/$projectId/languages');
      final data = ApiClient.handleListResponse(response);
      return data
          .map((json) => GitHubLanguage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('언어 정보 조회 실패: $e');
    }
  }

  /// 내 GitHub 레포 목록 조회 (PAT 기반)
  Future<List<Map<String, dynamic>>> getMyRepos() async {
    final resp = await ApiClient.get('/api/github/my-repos');
    final data = ApiClient.handleListResponse(resp);
    return data.cast<Map<String, dynamic>>();
  }

  /// (계정) GitHub 토큰 연결 여부
  Future<bool> getMyTokenStatus() async {
    final resp = await ApiClient.get('/api/github-token/me');
    final data = ApiClient.handleResponse(resp);
    return (data['has_token'] ?? false) == true;
  }

  /// (계정) GitHub PAT 저장/갱신
  Future<void> upsertMyToken(String token) async {
    final resp = await ApiClient.put(
      '/api/github-token/me',
      body: {'access_token': token},
    );
    ApiClient.handleResponse(resp);
  }

  /// (계정) GitHub PAT 삭제
  Future<void> deleteMyToken() async {
    final resp = await ApiClient.delete('/api/github-token/me');
    ApiClient.handleResponse(resp);
  }
}
