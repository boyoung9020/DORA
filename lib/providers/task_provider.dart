import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';

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
  Future<bool> updateTask(Task task, {String? userId, String? username}) async {
    try {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      Task updatedTask = task;
      
      // 상태 또는 중요도가 변경되었는지 확인하고 히스토리 추가
      if (index != -1) {
        final oldTask = _tasks[index];
        
        // 상태 변경 히스토리
        if (oldTask.status != task.status && userId != null && username != null) {
          print('[TaskProvider] Status changed from ${oldTask.status.displayName} to ${task.status.displayName}');
          
          final newHistory = List<StatusChangeHistory>.from(task.statusHistory);
          newHistory.add(StatusChangeHistory(
            fromStatus: oldTask.status,
            toStatus: task.status,
            userId: userId,
            username: username,
            changedAt: DateTime.now(),
          ));
          
          updatedTask = updatedTask.copyWith(statusHistory: newHistory);
          print('[TaskProvider] Status history added, total: ${newHistory.length}');
        }
        
        // 중요도 변경 히스토리
        if (oldTask.priority != task.priority && userId != null && username != null) {
          print('[TaskProvider] Priority changed from ${oldTask.priority.displayName} to ${task.priority.displayName}');
          
          final newHistory = List<PriorityChangeHistory>.from(task.priorityHistory);
          newHistory.add(PriorityChangeHistory(
            fromPriority: oldTask.priority,
            toPriority: task.priority,
            userId: userId,
            username: username,
            changedAt: DateTime.now(),
          ));
          
          updatedTask = updatedTask.copyWith(priorityHistory: newHistory);
          print('[TaskProvider] Priority history added, total: ${newHistory.length}');
        }
        
        // 할당 변경 히스토리 - 할당된 팀원이 변경된 경우 기록
        if (userId != null && username != null) {
          final oldMemberIds = oldTask.assignedMemberIds.toSet();
          final newMemberIds = task.assignedMemberIds.toSet();
          
          // 할당이 변경되었는지 확인 (추가, 제거, 교체 모두 포함)
          final hasChanged = oldMemberIds.length != newMemberIds.length || 
                            !oldMemberIds.every((id) => newMemberIds.contains(id));
          if (hasChanged) {
            print('[TaskProvider] Assignment changed from $oldMemberIds to $newMemberIds');
            final newHistory = List<AssignmentHistory>.from(task.assignmentHistory);
            
            // 현재 할당된 팀원들(한 명)에 대해 할당 히스토리 추가
            for (final memberId in newMemberIds) {
              // AuthService를 통해 실제 username 가져오기
              try {
                final authService = AuthService();
                final assignedUser = await authService.getUserById(memberId);
                final assignedUsername = assignedUser?.username ?? 'Unknown';
                
                newHistory.add(AssignmentHistory(
                  assignedUserId: memberId,
                  assignedUsername: assignedUsername,
                  assignedBy: userId,
                  assignedByUsername: username,
                  assignedAt: DateTime.now(),
                ));
                print('[TaskProvider] Assignment history added for $assignedUsername');
              } catch (e) {
                print('[TaskProvider] Error loading assigned user: $e');
                newHistory.add(AssignmentHistory(
                  assignedUserId: memberId,
                  assignedUsername: 'User',
                  assignedBy: userId,
                  assignedByUsername: username,
                  assignedAt: DateTime.now(),
                ));
              }
            }
            
            updatedTask = updatedTask.copyWith(assignmentHistory: newHistory);
            print('[TaskProvider] Assignment history updated, total: ${newHistory.length}');
          }
        }
      }
      
      await _taskService.updateTask(updatedTask);
      if (index != -1) {
        _tasks[index] = updatedTask;
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
  Future<bool> changeTaskStatus(String taskId, TaskStatus newStatus, {String? userId, String? username}) async {
    try {
      await _taskService.changeTaskStatus(taskId, newStatus);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final task = _tasks[index];
        final oldStatus = task.status;
        
        // 상태 변경 히스토리 추가
        final newHistory = List<StatusChangeHistory>.from(task.statusHistory);
        if (oldStatus != newStatus && userId != null && username != null) {
          newHistory.add(StatusChangeHistory(
            fromStatus: oldStatus,
            toStatus: newStatus,
            userId: userId,
            username: username,
            changedAt: DateTime.now(),
          ));
        }
        
        _tasks[index] = task.copyWith(
          status: newStatus,
          statusHistory: newHistory,
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

