import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

/// 태스크 서비스 클래스
/// 
/// 이 클래스는 태스크 데이터 관리 기능을 담당합니다:
/// - 태스크 생성
/// - 태스크 수정
/// - 태스크 삭제
/// - 태스크 조회
/// - 로컬 저장소에 저장
class TaskService {
  static const String _tasksKey = 'tasks';

  /// 고유 ID 생성
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 모든 태스크 가져오기
  Future<List<Task>> getAllTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString(_tasksKey);
      
      if (tasksJson == null) {
        return [];
      }

      final List<dynamic> tasksList = json.decode(tasksJson);
      return tasksList.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 태스크 저장
  Future<void> _saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = json.encode(
      tasks.map((task) => task.toJson()).toList(),
    );
    await prefs.setString(_tasksKey, tasksJson);
  }

  /// 새 태스크 생성
  Future<Task> createTask({
    required String title,
    String description = '',
    TaskStatus status = TaskStatus.backlog,
    required String projectId,
    DateTime? startDate,
    DateTime? endDate,
    String detail = '',
    TaskPriority priority = TaskPriority.p2,
    List<String>? assignedMemberIds,
  }) async {
    final now = DateTime.now();
    final task = Task(
      id: _generateId(),
      title: title,
      description: description,
      status: status,
      projectId: projectId,
      startDate: startDate,
      endDate: endDate,
      detail: detail,
      priority: priority,
      assignedMemberIds: assignedMemberIds,
      createdAt: now,
      updatedAt: now,
    );

    final tasks = await getAllTasks();
    tasks.add(task);
    await _saveTasks(tasks);

    return task;
  }

  /// 태스크 업데이트
  Future<void> updateTask(Task task) async {
    final tasks = await getAllTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    
    if (index != -1) {
      tasks[index] = task.copyWith(updatedAt: DateTime.now());
      await _saveTasks(tasks);
    }
  }

  /// 태스크 삭제
  Future<void> deleteTask(String taskId) async {
    final tasks = await getAllTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await _saveTasks(tasks);
  }

  /// 상태별 태스크 가져오기
  Future<List<Task>> getTasksByStatus(TaskStatus status, {String? projectId}) async {
    final tasks = await getAllTasks();
    var filteredTasks = tasks.where((task) => task.status == status);
    if (projectId != null) {
      filteredTasks = filteredTasks.where((task) => task.projectId == projectId);
    }
    return filteredTasks.toList();
  }

  /// 프로젝트별 태스크 가져오기
  Future<List<Task>> getTasksByProject(String projectId) async {
    final tasks = await getAllTasks();
    return tasks.where((task) => task.projectId == projectId).toList();
  }

  /// 태스크 상태 변경
  Future<void> changeTaskStatus(String taskId, TaskStatus newStatus) async {
    final tasks = await getAllTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    
    if (index != -1) {
      tasks[index] = tasks[index].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await _saveTasks(tasks);
    }
  }
}

