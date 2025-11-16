import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';

/// 프로젝트 서비스 클래스
class ProjectService {
  static const String _projectsKey = 'projects';
  static const String _currentProjectKey = 'current_project_id';

  /// 고유 ID 생성
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 모든 프로젝트 가져오기
  Future<List<Project>> getAllProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson = prefs.getString(_projectsKey);
      
      if (projectsJson == null) {
        // 기본 프로젝트 생성
        final defaultProject = Project(
          id: _generateId(),
          name: '기본 프로젝트',
          description: '기본 프로젝트입니다',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _saveProjects([defaultProject]);
        await setCurrentProject(defaultProject.id);
        return [defaultProject];
      }

      final List<dynamic> projectsList = json.decode(projectsJson);
      return projectsList.map((json) => Project.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 프로젝트 저장
  Future<void> _saveProjects(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final projectsJson = json.encode(
      projects.map((project) => project.toJson()).toList(),
    );
    await prefs.setString(_projectsKey, projectsJson);
  }

  /// 새 프로젝트 생성
  Future<Project> createProject({
    required String name,
    String? description,
    Color? color,
  }) async {
    final now = DateTime.now();
    final project = Project(
      id: _generateId(),
      name: name,
      description: description,
      color: color ?? const Color(0xFF2196F3),
      createdAt: now,
      updatedAt: now,
    );

    final projects = await getAllProjects();
    projects.add(project);
    await _saveProjects(projects);

    return project;
  }

  /// 프로젝트 업데이트
  Future<void> updateProject(Project project) async {
    final projects = await getAllProjects();
    final index = projects.indexWhere((p) => p.id == project.id);
    
    if (index != -1) {
      projects[index] = project.copyWith(updatedAt: DateTime.now());
      await _saveProjects(projects);
    }
  }

  /// 프로젝트 삭제
  Future<void> deleteProject(String projectId) async {
    final projects = await getAllProjects();
    projects.removeWhere((project) => project.id == projectId);
    await _saveProjects(projects);
    
    // 현재 프로젝트가 삭제된 프로젝트면 기본 프로젝트로 변경
    final currentProjectId = await getCurrentProjectId();
    if (currentProjectId == projectId && projects.isNotEmpty) {
      await setCurrentProject(projects.first.id);
    }
  }

  /// 현재 프로젝트 ID 가져오기
  Future<String?> getCurrentProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentProjectKey);
  }

  /// 현재 프로젝트 설정
  Future<void> setCurrentProject(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentProjectKey, projectId);
  }

  /// 현재 프로젝트 가져오기
  Future<Project?> getCurrentProject() async {
    final projectId = await getCurrentProjectId();
    if (projectId == null) {
      final projects = await getAllProjects();
      if (projects.isNotEmpty) {
        await setCurrentProject(projects.first.id);
        return projects.first;
      }
      return null;
    }
    
    final projects = await getAllProjects();
    return projects.firstWhere(
      (p) => p.id == projectId,
      orElse: () => projects.isNotEmpty ? projects.first : throw StateError('No projects'),
    );
  }
}

