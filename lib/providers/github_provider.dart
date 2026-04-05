import 'package:flutter/foundation.dart';

import '../models/github.dart';
import '../services/github_service.dart';

class GitHubProvider extends ChangeNotifier {
  final GitHubService _service = GitHubService();

  GitHubRepo? _connectedRepo;
  List<GitHubCommit> _commits = [];
  List<GitHubBranch> _branches = [];
  List<GitHubTag> _tags = [];
  List<GitHubRelease> _releases = [];
  List<GitHubPullRequest> _pullRequests = [];
  List<GitHubLanguage> _languages = [];
  bool _languagesLoading = false;
  GitHubRepoRemoteDetails? _repoRemoteDetails;
  /// 로컬 날짜 키 `yyyy-MM-dd` → 해당 일 커밋 수 (잔디용, 기본 브랜치 히스토리 기준)
  final Map<String, int> _commitActivityByDay = {};
  bool _commitHeatmapLoading = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedBranch;
  int _commitsPage = 1;
  int _prPage = 1;
  String _prState = 'open';
  bool _hasMoreCommits = true;
  bool _hasMorePRs = true;
  bool _repoInfoLoaded = false;
  bool _hasUserToken = false;
  bool _userTokenStatusLoaded = false;
  List<Map<String, dynamic>> _myRepos = [];
  bool _myReposLoading = false;
  String? _repoInfoProjectId;

  GitHubRepo? get connectedRepo => _connectedRepo;
  bool get repoInfoLoaded => _repoInfoLoaded;
  bool get hasUserToken => _hasUserToken;
  bool get userTokenStatusLoaded => _userTokenStatusLoaded;
  List<Map<String, dynamic>> get myRepos => _myRepos;
  bool get myReposLoading => _myReposLoading;
  List<GitHubCommit> get commits => _commits;
  List<GitHubBranch> get branches => _branches;
  List<GitHubTag> get tags => _tags;
  List<GitHubRelease> get releases => _releases;
  List<GitHubPullRequest> get pullRequests => _pullRequests;
  List<GitHubLanguage> get languages => _languages;
  bool get languagesLoading => _languagesLoading;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedBranch => _selectedBranch;
  String get prState => _prState;
  bool get hasMoreCommits => _hasMoreCommits;
  bool get hasMorePRs => _hasMorePRs;
  GitHubRepoRemoteDetails? get repoRemoteDetails => _repoRemoteDetails;
  Map<String, int> get commitActivityByDay =>
      Map.unmodifiable(_commitActivityByDay);
  bool get commitHeatmapLoading => _commitHeatmapLoading;

  void clear() {
    _connectedRepo = null;
    _commits = [];
    _branches = [];
    _tags = [];
    _releases = [];
    _pullRequests = [];
    _languages = [];
    _languagesLoading = false;
    _selectedBranch = null;
    _commitsPage = 1;
    _prPage = 1;
    _prState = 'open';
    _hasMoreCommits = true;
    _hasMorePRs = true;
    _errorMessage = null;
    _repoInfoLoaded = false;
    _repoInfoProjectId = null;
    _repoRemoteDetails = null;
    _commitActivityByDay.clear();
    _commitHeatmapLoading = false;
    _hasUserToken = false;
    _userTokenStatusLoaded = false;
    notifyListeners();
  }

  Future<void> loadMyTokenStatus() async {
    if (_userTokenStatusLoaded) return;
    try {
      _hasUserToken = await _service.getMyTokenStatus();
    } catch (_) {
      _hasUserToken = false;
    }
    _userTokenStatusLoaded = true;
    notifyListeners();
  }

  Future<void> upsertMyToken(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.upsertMyToken(token);
      _hasUserToken = true;
      _userTokenStatusLoaded = true;
    } catch (e) {
      _errorMessage = 'GitHub 토큰 저장 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMyToken() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.deleteMyToken();
      _hasUserToken = false;
      _userTokenStatusLoaded = true;
    } catch (e) {
      _errorMessage = 'GitHub 토큰 삭제 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 내 GitHub 레포 목록 로드
  Future<void> loadMyRepos() async {
    _myReposLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _myRepos = await _service.getMyRepos();
    } catch (e) {
      _errorMessage = '레포 목록 조회 실패: $e';
      _myRepos = [];
    } finally {
      _myReposLoading = false;
      notifyListeners();
    }
  }

  /// 연결 정보 로드
  Future<void> loadRepoInfo(String projectId) async {
    if (_repoInfoProjectId != projectId) {
      _repoInfoProjectId = projectId;
      _connectedRepo = null;
      _commits = [];
      _branches = [];
      _tags = [];
      _releases = [];
      _pullRequests = [];
      _languages = [];
      _languagesLoading = false;
      _repoRemoteDetails = null;
      _commitActivityByDay.clear();
      _selectedBranch = null;
      _commitsPage = 1;
      _prPage = 1;
      _hasMoreCommits = true;
      _hasMorePRs = true;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _connectedRepo = await _service.getRepoInfo(projectId);
    } catch (e) {
      _connectedRepo = null;
    } finally {
      _isLoading = false;
      _repoInfoLoaded = true;
      if (_connectedRepo == null) {
        _languages = [];
        _languagesLoading = false;
      }
      notifyListeners();
    }
  }

  /// 레포 연결
  Future<bool> connectRepo({
    required String projectId,
    required String repoOwner,
    required String repoName,
    String? accessToken,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _connectedRepo = await _service.connectRepo(
        projectId: projectId,
        repoOwner: repoOwner,
        repoName: repoName,
        accessToken: accessToken,
      );
      return true;
    } catch (e) {
      _errorMessage = '레포 연결 실패: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 레포 연결 해제
  Future<bool> disconnectRepo(String projectId) async {
    try {
      await _service.disconnectRepo(projectId);
      clear();
      return true;
    } catch (e) {
      _errorMessage = '연결 해제 실패: $e';
      notifyListeners();
      return false;
    }
  }

  /// 브랜치 목록 로드
  Future<void> loadBranches(String projectId) async {
    try {
      _branches = await _service.getBranches(projectId);
      notifyListeners();
    } catch (e) {
      _errorMessage = '브랜치 목록 조회 실패: $e';
      notifyListeners();
    }
  }

  /// 브랜치 선택 변경
  void selectBranch(String? branch) {
    _selectedBranch = branch;
    notifyListeners();
  }

  /// 커밋 목록 로드 (초기화)
  Future<void> loadCommits(
    String projectId, {
    String? branch,
    bool showGlobalLoading = true,
  }) async {
    if (showGlobalLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    } else {
      _errorMessage = null;
    }
    _commitsPage = 1;
    _hasMoreCommits = true;
    if (!showGlobalLoading) notifyListeners();
    try {
      final result = await _service.getCommits(
          projectId, branch: branch ?? _selectedBranch);
      _commits = result;
      if (result.length < 30) _hasMoreCommits = false;
    } catch (e) {
      _errorMessage = '커밋 목록 조회 실패: $e';
    } finally {
      if (showGlobalLoading) _isLoading = false;
      notifyListeners();
    }
  }

  /// 기본 브랜치 커밋을 여러 페이지 읽어 일별 커밋 수 집계 (기여 잔디)
  Future<void> loadCommitActivityHeatmap(String projectId) async {
    final scope = projectId;
    _commitHeatmapLoading = true;
    notifyListeners();
    final byDay = <String, int>{};
    final cutoff =
        DateTime.now().toLocal().subtract(const Duration(days: 400));
    try {
      var page = 1;
      const perPage = 100;
      while (page <= 30) {
        final batch = await _service.getCommits(
          projectId,
          branch: null,
          page: page,
          perPage: perPage,
        );
        if (_repoInfoProjectId != scope) return;
        if (batch.isEmpty) break;
        for (final c in batch) {
          try {
            final d = DateTime.parse(c.date).toLocal();
            final key =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            byDay[key] = (byDay[key] ?? 0) + 1;
          } catch (_) {}
        }
        if (batch.length < perPage) break;
        DateTime? oldest;
        try {
          oldest = DateTime.parse(batch.last.date).toLocal();
        } catch (_) {
          oldest = null;
        }
        if (oldest != null && oldest.isBefore(cutoff)) break;
        page++;
      }
      if (_repoInfoProjectId != scope) return;
      _commitActivityByDay
        ..clear()
        ..addAll(byDay);
    } catch (_) {
      if (_repoInfoProjectId != scope) return;
      _commitActivityByDay.clear();
    } finally {
      if (_repoInfoProjectId == scope) {
        _commitHeatmapLoading = false;
        notifyListeners();
      }
    }
  }

  /// 커밋 더 불러오기
  Future<void> loadMoreCommits(String projectId) async {
    if (!_hasMoreCommits) return;
    _commitsPage++;
    try {
      final result = await _service.getCommits(
        projectId,
        branch: _selectedBranch,
        page: _commitsPage,
      );
      _commits = [..._commits, ...result];
      if (result.length < 30) _hasMoreCommits = false;
      notifyListeners();
    } catch (e) {
      _commitsPage--;
    }
  }

  /// PR 목록 로드 (초기화)
  Future<void> loadPullRequests(
    String projectId, {
    String? state,
    bool showGlobalLoading = true,
  }) async {
    if (showGlobalLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    } else {
      _errorMessage = null;
    }
    _prPage = 1;
    _hasMorePRs = true;
    if (state != null) _prState = state;
    if (!showGlobalLoading) notifyListeners();
    try {
      final result =
          await _service.getPullRequests(projectId, state: _prState);
      _pullRequests = result;
      if (result.length < 30) _hasMorePRs = false;
    } catch (e) {
      _errorMessage = 'PR 목록 조회 실패: $e';
    } finally {
      if (showGlobalLoading) _isLoading = false;
      notifyListeners();
    }
  }

  /// Releases 목록 로드 (published_at 기준 최신순)
  Future<void> loadReleases(String projectId) async {
    final scope = projectId;
    try {
      final result = await _service.getReleases(projectId);
      if (_repoInfoProjectId != scope) return;
      _releases = result;
      notifyListeners();
    } catch (e) {
      if (_repoInfoProjectId != scope) return;
      _errorMessage = '릴리즈 목록 조회 실패: $e';
      notifyListeners();
    }
  }

  /// 태그 목록 로드 (요청 시점의 프로젝트와 일치할 때만 반영 — 전역 단일 목록 경합 방지)
  Future<void> loadTags(String projectId) async {
    final scope = projectId;
    try {
      final result = await _service.getTags(projectId);
      if (_repoInfoProjectId != scope) return;
      _tags = result;
      notifyListeners();
    } catch (e) {
      if (_repoInfoProjectId != scope) return;
      _errorMessage = '태그 목록 조회 실패: $e';
      notifyListeners();
    }
  }

  /// 경량 태그 생성 후 목록 갱신. 성공 시 true.
  Future<bool> createTag(
    String projectId, {
    required String tagName,
    required String commitSha,
  }) async {
    final scope = projectId;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.createTag(
        projectId,
        tagName: tagName,
        commitSha: commitSha,
      );
      if (_repoInfoProjectId != scope) return false;
      await loadTags(projectId);
      return true;
    } catch (e) {
      if (_repoInfoProjectId != scope) return false;
      _errorMessage = '태그 생성 실패: $e';
      notifyListeners();
      return false;
    }
  }

  /// PR 더 불러오기
  Future<void> loadMorePullRequests(String projectId) async {
    if (!_hasMorePRs) return;
    _prPage++;
    try {
      final result = await _service.getPullRequests(
        projectId,
        state: _prState,
        page: _prPage,
      );
      _pullRequests = [..._pullRequests, ...result];
      if (result.length < 30) _hasMorePRs = false;
      notifyListeners();
    } catch (e) {
      _prPage--;
    }
  }

  /// GitHub 원격 저장소 요약 (설명·스타 등)
  Future<void> loadRepoRemoteDetails(String projectId) async {
    final scope = projectId;
    try {
      final result = await _service.getRepoDetails(projectId);
      if (_repoInfoProjectId != scope) return;
      _repoRemoteDetails = result;
      notifyListeners();
    } catch (_) {
      if (_repoInfoProjectId != scope) return;
      _repoRemoteDetails = null;
      notifyListeners();
    }
  }

  /// 저장소 언어 비율 (개요 기술 스택). 레포 미연결 시 호출하지 않음.
  Future<void> loadLanguages(String projectId) async {
    final scope = projectId;
    _languagesLoading = true;
    notifyListeners();
    try {
      final result = await _service.getLanguages(projectId);
      if (_repoInfoProjectId != scope) return;
      _languages = result;
    } catch (_) {
      if (_repoInfoProjectId != scope) return;
      _languages = [];
    } finally {
      if (_repoInfoProjectId == scope) {
        _languagesLoading = false;
        notifyListeners();
      }
    }
  }
}
