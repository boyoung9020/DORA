import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/project_service.dart';

/// 프로젝트 상태 관리 Provider
class ProjectProvider extends ChangeNotifier {
  final ProjectService _projectService = ProjectService();
  List<Project> _allProjects = []; // 모든 프로젝트 (필터링 전)
  List<Project> _projects = []; // 필터링된 프로젝트 (사용자가 속한 프로젝트)
  Project? _currentProject;
  bool _isAllProjectsMode = false; // '전체' 모드 여부
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId; // 현재 사용자 ID
  bool _isAdmin = false; // 관리자 여부
  bool _isPM = false; // PM 여부
  Set<String> _favoriteIds = {}; // 즐겨찾기 프로젝트 ID

  List<Project> get projects => _projects;
  Project? get currentProject => _currentProject;
  bool get isAllProjectsMode => _isAllProjectsMode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<String> get favoriteIds => _favoriteIds;

  /// 즐겨찾기 여부
  bool isFavorite(String projectId) => _favoriteIds.contains(projectId);

  /// 즐겨찾기 토글 (서버에 저장)
  Future<void> toggleFavorite(String projectId) async {
    if (_favoriteIds.contains(projectId)) {
      _favoriteIds.remove(projectId);
    } else {
      _favoriteIds.add(projectId);
    }
    notifyListeners();
    await _projectService.saveFavorites(_favoriteIds);
  }

  /// 즐겨찾기 목록 서버에서 로드
  Future<void> loadFavorites() async {
    _favoriteIds = await _projectService.fetchFavorites();
    notifyListeners();
  }

  /// 즐겨찾기 우선 정렬된 프로젝트 목록
  List<Project> get sortedProjects {
    final favs = _projects.where((p) => _favoriteIds.contains(p.id)).toList();
    final rest = _projects.where((p) => !_favoriteIds.contains(p.id)).toList();
    return [...favs, ...rest];
  }

  ProjectProvider();
  // loadFavorites()는 loadProjects() 내에서 인증 후 자동 호출됨

  /// 전체 프로젝트 모드 선택
  void selectAllProjects() {
    _isAllProjectsMode = true;
    _currentProject = null;
    notifyListeners();
  }

  /// 사용자 정보 설정 (필터링을 위해 필요)
  void setUserInfo(String? userId, bool isAdmin, bool isPM) {
    // 사용자 정보가 변경되면 이전 프로젝트 정보 초기화
    if (_currentUserId != userId) {
      _currentProject = null;
      _isAllProjectsMode = false;
      _projects = [];
      _allProjects = [];
    }
    _currentUserId = userId;
    _isAdmin = isAdmin;
    _isPM = isPM;
    // 사용자 정보가 변경되면 프로젝트 다시 필터링
    _filterProjects();
  }

  /// 프로젝트 필터링 (사용자가 속한 프로젝트만 표시)
  void _filterProjects() {
    if (_currentUserId == null) {
      _projects = [];
      return;
    }

    print('[ProjectProvider] 프로젝트 필터링 시작');
    print('[ProjectProvider] 사용자 ID: $_currentUserId');
    print('[ProjectProvider] 관리자: $_isAdmin, PM: $_isPM');
    print('[ProjectProvider] 전체 프로젝트 수: ${_allProjects.length}');

    // 관리자는 모든 프로젝트를 볼 수 있음
    if (_isAdmin) {
      _projects = List.from(_allProjects);
      print('[ProjectProvider] 관리자 - 모든 프로젝트 표시: ${_projects.length}개');
    } else {
      // PM 및 일반 사용자는 자신이 속한 프로젝트만 볼 수 있음
      _projects = _allProjects.where((project) {
        final isCreator = project.creatorId == _currentUserId;
        final isMember = project.teamMemberIds.contains(_currentUserId);
        print('[ProjectProvider] 프로젝트 "${project.name}" - 생성자: $isCreator, 팀원 여부: $isMember (팀원 수: ${project.teamMemberIds.length})');
        return isCreator || isMember;
      }).toList();
      print('[ProjectProvider] 사용자 - 필터링된 프로젝트: ${_projects.length}개');
    }

    // '전체' 모드면 currentProject는 항상 null 유지
    if (_isAllProjectsMode) {
      _currentProject = null;
    } else if (_currentProject != null) {
      // 현재 프로젝트가 필터링된 목록에 없으면 첫 번째 프로젝트로 설정
      final found = _projects.any((p) => p.id == _currentProject!.id);
      if (!found && _projects.isNotEmpty) {
        _currentProject = _projects.first;
      } else if (!found) {
        _currentProject = null;
      }
    } else if (_projects.isNotEmpty) {
      _currentProject = _projects.first;
    }

    print('[ProjectProvider] 현재 선택된 프로젝트: ${_currentProject?.name ?? "없음"}');
    notifyListeners();
  }

  /// 프로젝트 목록 로드
  Future<void> loadProjects({String? userId, bool isAdmin = false, bool isPM = false, String? workspaceId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 즐겨찾기와 프로젝트 목록을 병렬로 가져옴
      final results = await Future.wait([
        _projectService.getAllProjects(workspaceId: workspaceId),
        _projectService.fetchFavorites(),
      ]);
      _allProjects = results[0] as List<Project>;
      _favoriteIds = results[1] as Set<String>;

      // 사용자 정보 업데이트
      if (userId != null) {
        _currentUserId = userId;
        _isAdmin = isAdmin;
        _isPM = isPM;
      }
      
      // 프로젝트 필터링
      _filterProjects();
      
      // '전체' 모드면 currentProject는 null 유지, 아니면 최신 데이터로 업데이트
      if (!_isAllProjectsMode) {
        final currentProjectId = _currentProject?.id;
        if (currentProjectId != null && _projects.isNotEmpty) {
          _currentProject = _projects.firstWhere(
            (p) => p.id == currentProjectId,
            orElse: () => _projects.first,
          );
        } else if (_projects.isNotEmpty) {
          _currentProject = _projects.first;
        } else {
          // 속한 프로젝트가 없으면 자동으로 '전체' 모드로 전환
          _currentProject = null;
          _isAllProjectsMode = true;
        }
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '프로젝트를 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 현재 프로젝트 설정
  Future<void> setCurrentProject(String projectId) async {
    try {
      await _projectService.setCurrentProject(projectId);
      _isAllProjectsMode = false;
      _currentProject = _projects.firstWhere((p) => p.id == projectId);
      notifyListeners();
    } catch (e) {
      _errorMessage = '프로젝트 변경 중 오류가 발생했습니다: $e';
      notifyListeners();
    }
  }

  /// 새 프로젝트 생성
  ///
  /// 워크스페이스 멤버 누구나 생성 가능. 생성자가 자동으로 PM이 됨.
  Future<bool> createProject({
    required String name,
    String? description,
    Color? color,
    String? workspaceId,
    // 하위 호환 파라미터 (무시됨)
    bool isPM = true,
    String? creatorUserId,
  }) async {
    try {
      final project = await _projectService.createProject(
        name: name,
        description: description,
        color: color,
        workspaceId: workspaceId,
      );

      await loadProjects(userId: _currentUserId, isAdmin: _isAdmin, isPM: _isPM);
      await setCurrentProject(project.id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '프로젝트 생성 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 프로젝트 업데이트
  Future<bool> updateProject(Project project) async {
    try {
      await _projectService.updateProject(project);
      await loadProjects(userId: _currentUserId, isAdmin: _isAdmin, isPM: _isPM);
      if (_currentProject?.id == project.id) {
        _currentProject = project;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '프로젝트 업데이트 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 프로젝트 삭제
  Future<bool> deleteProject(String projectId) async {
    try {
      await _projectService.deleteProject(projectId);
      await loadProjects(userId: _currentUserId, isAdmin: _isAdmin, isPM: _isPM);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '프로젝트 삭제 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 프로젝트에 팀원 추가
  Future<bool> addTeamMember(String projectId, String userId) async {
    try {
      await _projectService.addTeamMember(projectId, userId);
      // 프로젝트 목록 다시 로드
      await loadProjects(userId: _currentUserId, isAdmin: _isAdmin, isPM: _isPM);
      // 현재 프로젝트 업데이트 (최신 데이터로)
      if (_currentProject?.id == projectId) {
        final updatedProject = _projects.firstWhere(
          (p) => p.id == projectId,
          orElse: () => _currentProject!,
        );
        _currentProject = updatedProject;
        print('[ProjectProvider] 팀원 추가 후 현재 프로젝트 업데이트: ${_currentProject?.name}, 팀원 수: ${_currentProject?.teamMemberIds.length}');
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '팀원 추가 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 프로젝트에서 팀원 제거
  Future<bool> removeTeamMember(String projectId, String userId) async {
    try {
      await _projectService.removeTeamMember(projectId, userId);
      await loadProjects(userId: _currentUserId, isAdmin: _isAdmin, isPM: _isPM);
      // 현재 프로젝트 업데이트
      if (_currentProject?.id == projectId) {
        final updatedProject = _projects.firstWhere(
          (p) => p.id == projectId,
          orElse: () => _currentProject!,
        );
        _currentProject = updatedProject;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '팀원 제거 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }
}

