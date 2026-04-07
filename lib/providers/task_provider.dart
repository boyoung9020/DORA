import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_service.dart';

/// 태스크 상태 관리 Provider
///
/// 칸반 보드의 태스크 상태를 관리합니다.
class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  List<Task> _tasks = [];
  List<Task> _allTasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  // 작업 필터: null=모든 작업, 'mine'=내 작업, userId=특정 멤버
  String? _taskOwnerFilter;

  // 실시간 댓글 갱신 콜백 (열린 태스크 다이얼로그에서 등록)
  final Map<String, List<void Function()>> _commentListeners = {};

  List<Task> get tasks => _tasks;
  List<Task> get allTasks => _allTasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get showMyTasksOnly => _taskOwnerFilter == 'mine';
  String? get taskOwnerFilter => _taskOwnerFilter;

  void toggleMyTasksOnly() {
    _taskOwnerFilter = _taskOwnerFilter == 'mine' ? null : 'mine';
    notifyListeners();
  }

  void setTaskOwnerFilter(String? filter) {
    _taskOwnerFilter = filter;
    notifyListeners();
  }

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
      filteredTasks = filteredTasks.where(
        (task) => task.projectId == projectId,
      );
    }
    final result = filteredTasks.toList();
    result.sort((a, b) {
      final orderCompare = a.displayOrder.compareTo(b.displayOrder);
      if (orderCompare != 0) return orderCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  /// 현재 태스크 목록을 주어진 프로젝트 ID 목록으로 필터링
  void filterByProjectIds(List<String> projectIds) {
    if (projectIds.isEmpty) return;
    final idSet = projectIds.toSet();
    _tasks = _tasks.where((t) => idSet.contains(t.projectId)).toList();
    notifyListeners();
  }

  /// 초기화 및 태스크 로드
  Future<void> loadTasks({String? projectId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final scopedTasks = await _taskService.getAllTasks(projectId: projectId);

      // 일부 환경에서 project_id 필터 조회가 비정상적으로 0건을 반환하는 경우가 있어
      // 전체 조회로 한 번 더 확인해 실제 데이터 누락 표시를 방지한다.
      if (projectId != null && scopedTasks.isEmpty) {
        final allTasks = await _taskService.getAllTasks();
        final hasProjectTasks = allTasks.any(
          (task) => task.projectId == projectId,
        );
        _tasks = hasProjectTasks ? allTasks : scopedTasks;
      } else {
        _tasks = scopedTasks;
      }
      _errorMessage = null;
    } catch (e) {
      _tasks = [];
      _errorMessage = '태스크를 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 대시보드용 전체 태스크 로드
  /// [projectIds]가 주어지면 해당 프로젝트의 태스크만 유지 (워크스페이스 범위 제한)
  Future<void> loadAllTasks({List<String>? projectIds}) async {
    try {
      final all = await _taskService.getAllTasks();
      if (projectIds != null && projectIds.isNotEmpty) {
        final idSet = projectIds.toSet();
        _allTasks = all.where((t) => idSet.contains(t.projectId)).toList();
      } else {
        _allTasks = all;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = '전체 태스크를 불러오는 중 오류가 발생했습니다: $e';
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
    String? sprintId,
    String? parentTaskId,
    List<String> siteTags = const [],
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
        sprintId: sprintId,
        parentTaskId: parentTaskId,
        siteTags: siteTags,
      );
      _tasks.add(task);
      _allTasks.add(task);
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
      final allIndex = _allTasks.indexWhere((t) => t.id == task.id);

      // 백엔드에 업데이트 요청 (히스토리는 백엔드에서 자동으로 추가됨)
      final updatedTask = await _taskService.updateTask(task);

      if (index != -1) {
        // 백엔드에서 반환된 히스토리를 포함한 태스크로 업데이트
        _tasks[index] = updatedTask;
      } else {
        // 태스크가 목록에 없으면 추가
        _tasks.add(updatedTask);
      }
      if (allIndex != -1) {
        _allTasks[allIndex] = updatedTask;
      } else {
        _allTasks.add(updatedTask);
      }
      notifyListeners();
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
      _allTasks.removeWhere((task) => task.id == taskId);
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
        final allIndex = _allTasks.indexWhere((t) => t.id == taskIds[i]);
        if (index != -1) {
          _tasks[index] = _tasks[index].copyWith(displayOrder: i);
        }
        if (allIndex != -1) {
          _allTasks[allIndex] = _allTasks[allIndex].copyWith(displayOrder: i);
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
  Future<bool> changeTaskStatus(
    String taskId,
    TaskStatus newStatus, {
    String? userId,
    String? username,
  }) async {
    try {
      // 백엔드에 상태 변경 요청 (히스토리는 백엔드에서 자동으로 추가됨)
      final updatedTask = await _taskService.changeTaskStatus(
        taskId,
        newStatus,
      );

      final index = _tasks.indexWhere((t) => t.id == taskId);
      final allIndex = _allTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        // 백엔드에서 반환된 히스토리를 포함한 태스크로 업데이트
        _tasks[index] = updatedTask;
      } else {
        // 태스크가 목록에 없으면 추가
        _tasks.add(updatedTask);
      }
      if (allIndex != -1) {
        _allTasks[allIndex] = updatedTask;
      } else {
        _allTasks.add(updatedTask);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '태스크 상태 변경 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// 댓글 삭제 후 로컬 상태만 업데이트
  /// 백엔드 comment DELETE 엔드포인트가 comment_ids를 DB에서 처리하므로 PATCH는 생략
  void removeCommentId(String taskId, String commentId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(
        commentIds: task.commentIds.where((id) => id != commentId).toList(),
      );
    }

    final allIndex = _allTasks.indexWhere((t) => t.id == taskId);
    if (allIndex != -1) {
      final task = _allTasks[allIndex];
      _allTasks[allIndex] = task.copyWith(
        commentIds: task.commentIds.where((id) => id != commentId).toList(),
      );
    }

    notifyListeners();
  }
}
