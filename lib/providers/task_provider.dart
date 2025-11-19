import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_service.dart';

/// 태스크 상태 관리 Provider
/// 
/// 칸반 보드의 태스크 상태를 관리합니다.
class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 상태별 태스크 가져오기
  List<Task> getTasksByStatus(TaskStatus status, {String? projectId}) {
    var filteredTasks = _tasks.where((task) => task.status == status);
    if (projectId != null) {
      filteredTasks = filteredTasks.where((task) => task.projectId == projectId);
    }
    return filteredTasks.toList();
  }

  /// 초기화 및 태스크 로드
  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _taskService.getAllTasks();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '태스크를 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 새 태스크 생성
  Future<bool> createTask({
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
    try {
      final task = await _taskService.createTask(
        title: title,
        description: description,
        status: status,
        projectId: projectId,
        startDate: startDate,
        endDate: endDate,
        detail: detail,
        priority: priority,
        assignedMemberIds: assignedMemberIds,
      );
      _tasks.add(task);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '태스크 생성 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 태스크 업데이트
  Future<bool> updateTask(Task task) async {
    try {
      await _taskService.updateTask(task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = '태스크 업데이트 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 태스크 삭제
  Future<bool> deleteTask(String taskId) async {
    try {
      await _taskService.deleteTask(taskId);
      _tasks.removeWhere((task) => task.id == taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '태스크 삭제 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 태스크 상태 변경
  Future<bool> changeTaskStatus(String taskId, TaskStatus newStatus) async {
    try {
      await _taskService.changeTaskStatus(taskId, newStatus);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = '태스크 상태 변경 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }
}

