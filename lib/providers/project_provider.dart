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
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId; // 현재 사용자 ID
  bool _isAdmin = false; // 관리자 여부
  bool _isPM = false; // PM 여부

  List<Project> get projects => _projects;
  Project? get currentProject => _currentProject;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ProjectProvider() {
    // 사용자 정보가 설정된 후에 loadProjects가 호출되므로 여기서는 호출하지 않음
    // MainLayout의 initState에서 _updateProjectProviderUserInfo()를 통해 호출됨
  }

  /// 사용자 정보 설정 (필터링을 위해 필요)
  void setUserInfo(String? userId, bool isAdmin, bool isPM) {
    // 사용자 정보가 변경되면 이전 프로젝트 정보 초기화
    if (_currentUserId != userId) {
      _currentProject = null;
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

    // 관리자나 PM은 모든 프로젝트를 볼 수 있음
    if (_isAdmin || _isPM) {
      _projects = List.from(_allProjects);
      print('[ProjectProvider] 관리자/PM - 모든 프로젝트 표시: ${_projects.length}개');
    } else {
      // 일반 사용자는 자신이 속한 프로젝트만 볼 수 있음
      _projects = _allProjects.where((project) {
        final isMember = project.teamMemberIds.contains(_currentUserId);
        print('[ProjectProvider] 프로젝트 "${project.name}" - 팀원 여부: $isMember (팀원 수: ${project.teamMemberIds.length})');
        return isMember;
      }).toList();
      print('[ProjectProvider] 일반 사용자 - 필터링된 프로젝트: ${_projects.length}개');
    }

    // 현재 프로젝트가 필터링된 목록에 없으면 첫 번째 프로젝트로 설정
    if (_currentProject != null) {
      final found = _projects.any((p) => p.id == _currentProject!.id);
      if (!found && _projects.isNotEmpty) {
        _currentProject = _projects.first;
      } else if (!found && _projects.isEmpty) {
        _currentProject = null;
      }
    } else if (_projects.isNotEmpty) {
      _currentProject = _projects.first;
    }

    print('[ProjectProvider] 현재 선택된 프로젝트: ${_currentProject?.name ?? "없음"}');
    notifyListeners();
  }

  /// 프로젝트 목록 로드
  Future<void> loadProjects({String? userId, bool isAdmin = false, bool isPM = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allProjects = await _projectService.getAllProjects();
      
      // 사용자 정보 업데이트
      if (userId != null) {
        _currentUserId = userId;
        _isAdmin = isAdmin;
        _isPM = isPM;
      }
      
      // 프로젝트 필터링
      _filterProjects();
      
      // 현재 프로젝트를 다시 가져와서 최신 데이터로 업데이트
      final currentProjectId = _currentProject?.id;
      if (currentProjectId != null && _projects.isNotEmpty) {
        _currentProject = _projects.firstWhere(
          (p) => p.id == currentProjectId,
          orElse: () => _projects.first,
        );
      } else if (_projects.isNotEmpty) {
        _currentProject = _projects.first;
      } else {
        _currentProject = null;
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
      _currentProject = _projects.firstWhere((p) => p.id == projectId);
      notifyListeners();
    } catch (e) {
      _errorMessage = '프로젝트 변경 중 오류가 발생했습니다: $e';
      notifyListeners();
    }
  }

  /// 새 프로젝트 생성
  /// 
  /// PM 권한이 있는 사용자만 프로젝트를 생성할 수 있습니다.
  /// 프로젝트 생성 시 생성자를 자동으로 팀원에 추가합니다.
  Future<bool> createProject({
    required String name,
    String? description,
    Color? color,
    required bool isPM,
    String? creatorUserId, // 프로젝트 생성자 ID
  }) async {
    if (!isPM) {
      _errorMessage = '프로젝트 생성 권한이 없습니다. PM 권한이 필요합니다.';
      notifyListeners();
      return false;
    }
    
    try {
      final project = await _projectService.createProject(
        name: name,
        description: description,
        color: color,
      );
      
      // 프로젝트 생성자를 자동으로 팀원에 추가
      if (creatorUserId != null) {
        await _projectService.addTeamMember(project.id, creatorUserId);
      }
      
      await loadProjects(userId: _currentUserId, isAdmin: _isAdmin, isPM: _isPM);
      await setCurrentProject(project.id);
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
}

