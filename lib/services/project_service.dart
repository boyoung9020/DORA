import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../utils/api_client.dart';

/// 프로젝트 서비스 클래스
class ProjectService {
  static const String _currentProjectKey = 'current_project_id';

  /// 모든 프로젝트 가져오기
  Future<List<Project>> getAllProjects() async {
    try {
      final response = await ApiClient.get('/api/projects/');
      final projectsData = ApiClient.handleListResponse(response);
      return projectsData.map((json) => Project.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('프로젝트 목록 가져오기 실패: $e');
    }
  }

  /// 새 프로젝트 생성
  Future<Project> createProject({
    required String name,
    String? description,
    Color? color,
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/projects/',
        body: {
          'name': name,
          'description': description,
          'color': color?.value ?? 0xFF2196F3,
        },
      );
      
      final projectData = ApiClient.handleResponse(response);
      return Project.fromJson(projectData);
    } catch (e) {
      throw Exception('프로젝트 생성 실패: $e');
    }
  }

  /// 프로젝트 업데이트
  Future<void> updateProject(Project project) async {
    try {
      final response = await ApiClient.patch(
        '/api/projects/${project.id}',
        body: {
          'name': project.name,
          'description': project.description,
          'color': project.color.value,
          'team_member_ids': project.teamMemberIds,
        },
      );
      
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('프로젝트 업데이트 실패: $e');
    }
  }

  /// 프로젝트 삭제
  Future<void> deleteProject(String projectId) async {
    try {
      final response = await ApiClient.delete('/api/projects/$projectId');
      ApiClient.handleResponse(response);
      
      // 현재 프로젝트가 삭제된 프로젝트면 기본 프로젝트로 변경
      final currentProjectId = await getCurrentProjectId();
      if (currentProjectId == projectId) {
        final projects = await getAllProjects();
        if (projects.isNotEmpty) {
          await setCurrentProject(projects.first.id);
        }
      }
    } catch (e) {
      throw Exception('프로젝트 삭제 실패: $e');
    }
  }

  /// 현재 프로젝트 ID 가져오기
  Future<String?> getCurrentProjectId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentProjectKey);
    } catch (e) {
      return null;
    }
  }

  /// 현재 프로젝트 설정
  Future<void> setCurrentProject(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentProjectKey, projectId);
  }

  /// 현재 프로젝트 가져오기
  Future<Project?> getCurrentProject() async {
    try {
      final projectId = await getCurrentProjectId();
      if (projectId == null) {
        final projects = await getAllProjects();
        if (projects.isNotEmpty) {
          await setCurrentProject(projects.first.id);
          return projects.first;
        }
        return null;
      }
      
      final response = await ApiClient.get('/api/projects/$projectId');
      final projectData = ApiClient.handleResponse(response);
      return Project.fromJson(projectData);
    } catch (e) {
      return null;
    }
  }

  /// 프로젝트에 팀원 추가
  Future<void> addTeamMember(String projectId, String userId) async {
    try {
      final response = await ApiClient.post('/api/projects/$projectId/members/$userId');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('팀원 추가 실패: $e');
    }
  }

  /// 프로젝트에서 팀원 제거
  Future<void> removeTeamMember(String projectId, String userId) async {
    try {
      final response = await ApiClient.delete('/api/projects/$projectId/members/$userId');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('팀원 제거 실패: $e');
    }
  }
}
