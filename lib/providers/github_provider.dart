import 'package:flutter/foundation.dart';

import '../models/github.dart';
import '../services/github_service.dart';

class GitHubProvider extends ChangeNotifier {
  final GitHubService _service = GitHubService();

  GitHubRepo? _connectedRepo;
  List<GitHubCommit> _commits = [];
  List<GitHubBranch> _branches = [];
  List<GitHubTag> _tags = [];
  List<GitHubPullRequest> _pullRequests = [];
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

  GitHubRepo? get connectedRepo => _connectedRepo;
  bool get repoInfoLoaded => _repoInfoLoaded;
  bool get hasUserToken => _hasUserToken;
  bool get userTokenStatusLoaded => _userTokenStatusLoaded;
  List<Map<String, dynamic>> get myRepos => _myRepos;
  bool get myReposLoading => _myReposLoading;
  List<GitHubCommit> get commits => _commits;
  List<GitHubBranch> get branches => _branches;
  List<GitHubTag> get tags => _tags;
  List<GitHubPullRequest> get pullRequests => _pullRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedBranch => _selectedBranch;
  String get prState => _prState;
  bool get hasMoreCommits => _hasMoreCommits;
  bool get hasMorePRs => _hasMorePRs;

  void clear() {
    _connectedRepo = null;
    _commits = [];
    _branches = [];
    _tags = [];
    _pullRequests = [];
    _selectedBranch = null;
    _commitsPage = 1;
    _prPage = 1;
    _prState = 'open';
    _hasMoreCommits = true;
    _hasMorePRs = true;
    _errorMessage = null;
    _repoInfoLoaded = false;
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
  Future<void> loadCommits(String projectId, {String? branch}) async {
    _isLoading = true;
    _errorMessage = null;
    _commitsPage = 1;
    _hasMoreCommits = true;
    notifyListeners();
    try {
      final result = await _service.getCommits(projectId, branch: branch ?? _selectedBranch);
      _commits = result;
      if (result.length < 30) _hasMoreCommits = false;
    } catch (e) {
      _errorMessage = '커밋 목록 조회 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
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
  Future<void> loadPullRequests(String projectId, {String? state}) async {
    _isLoading = true;
    _errorMessage = null;
    _prPage = 1;
    _hasMorePRs = true;
    if (state != null) _prState = state;
    notifyListeners();
    try {
      final result = await _service.getPullRequests(projectId, state: _prState);
      _pullRequests = result;
      if (result.length < 30) _hasMorePRs = false;
    } catch (e) {
      _errorMessage = 'PR 목록 조회 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 태그 목록 로드
  Future<void> loadTags(String projectId) async {
    try {
      _tags = await _service.getTags(projectId);
      notifyListeners();
    } catch (e) {
      _errorMessage = '태그 목록 조회 실패: $e';
      notifyListeners();
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
}
