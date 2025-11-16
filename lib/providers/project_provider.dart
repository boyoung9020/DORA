import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/project_service.dart';

/// 프로젝트 상태 관리 Provider
class ProjectProvider extends ChangeNotifier {
  final ProjectService _projectService = ProjectService();
  List<Project> _projects = [];
  Project? _currentProject;
  bool _isLoading = false;
  String? _errorMessage;

  List<Project> get projects => _projects;
  Project? get currentProject => _currentProject;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ProjectProvider() {
    loadProjects();
  }

  /// 프로젝트 목록 로드
  Future<void> loadProjects() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _projects = await _projectService.getAllProjects();
      _currentProject = await _projectService.getCurrentProject();
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
  Future<bool> createProject({
    required String name,
    String? description,
    Color? color,
  }) async {
    try {
      final project = await _projectService.createProject(
        name: name,
        description: description,
        color: color,
      );
      await loadProjects();
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
      await loadProjects();
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
      await loadProjects();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '프로젝트 삭제 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }
}

