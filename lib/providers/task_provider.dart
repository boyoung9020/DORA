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

  // 실시간 댓글 갱신 콜백 (열린 태스크 다이얼로그에서 등록)
  final Map<String, List<void Function()>> _commentListeners = {};

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 댓글 갱신 리스너 등록 (태스크 상세 화면에서 호출)
  void addCommentListener(String taskId, void Function() callback) {
    _commentListeners.putIfAbsent(taskId, () => []);
    _commentListeners[taskId]!.add(callback);
  }

  /// 댓글 갱신 리스너 해제
  void removeCommentListener(String taskId, void Function() callback) {
    _commentListeners[taskId]?.remove(callback);
    if (_commentListeners[taskId]?.isEmpty ?? false) {
      _commentListeners.remove(taskId);
    }
  }

  /// 댓글 생성 이벤트 수신 시 호출 (WebSocket에서 호출)
  void notifyCommentCreated(String taskId) {
    final listeners = _commentListeners[taskId];
    if (listeners != null) {
      for (final listener in List.from(listeners)) {
        listener();
      }
    }
  }

  /// 상태별 태스크 가져오기 (displayOrder로 정렬)
  List<Task> getTasksByStatus(TaskStatus status, {String? projectId}) {
    var filteredTasks = _tasks.where((task) => task.status == status);
    if (projectId != null) {
      filteredTasks = filteredTasks.where((task) => task.projectId == projectId);
    }
    final result = filteredTasks.toList();
    result.sort((a, b) {
      final orderCompare = a.displayOrder.compareTo(b.displayOrder);
      if (orderCompare != 0) return orderCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
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
  /// 히스토리는 백엔드에서 관리하므로 프론트엔드에서는 추가하지 않음
  Future<bool> updateTask(Task task, {String? userId, String? username}) async {
    try {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      
      // 백엔드에 업데이트 요청 (히스토리는 백엔드에서 자동으로 추가됨)
      final updatedTask = await _taskService.updateTask(task);
      
      if (index != -1) {
        // 백엔드에서 반환된 히스토리를 포함한 태스크로 업데이트
        _tasks[index] = updatedTask;
        notifyListeners();
      } else {
        // 태스크가 목록에 없으면 추가
        _tasks.add(updatedTask);
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

  /// 같은 컬럼 내 태스크 순서 변경
  Future<bool> reorderTasks(List<String> taskIds) async {
    try {
      await _taskService.reorderTasks(taskIds);
      // 로컬 리스트에서도 displayOrder 업데이트
      for (int i = 0; i < taskIds.length; i++) {
        final index = _tasks.indexWhere((t) => t.id == taskIds[i]);
        if (index != -1) {
          _tasks[index] = _tasks[index].copyWith(displayOrder: i);
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '태스크 순서 변경 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 태스크 상태 변경
  /// 히스토리는 백엔드에서 관리하므로 프론트엔드에서는 추가하지 않음
  Future<bool> changeTaskStatus(String taskId, TaskStatus newStatus, {String? userId, String? username}) async {
    try {
      // 백엔드에 상태 변경 요청 (히스토리는 백엔드에서 자동으로 추가됨)
      final updatedTask = await _taskService.changeTaskStatus(taskId, newStatus);
      
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        // 백엔드에서 반환된 히스토리를 포함한 태스크로 업데이트
        _tasks[index] = updatedTask;
        notifyListeners();
      } else {
        // 태스크가 목록에 없으면 추가
        _tasks.add(updatedTask);
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

