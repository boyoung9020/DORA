import 'package:flutter/foundation.dart';

import '../models/sprint.dart';
import '../services/sprint_service.dart';

class SprintProvider extends ChangeNotifier {
  final SprintService _service = SprintService();

  List<Sprint> _sprints = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Sprint> get sprints => _sprints;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Sprint? get activeSprint {
    for (final sprint in _sprints) {
      if (sprint.status == SprintStatus.active) {
        return sprint;
      }
    }
    return null;
  }

  Future<void> loadSprints({String? projectId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _sprints = await _service.getSprints(projectId: projectId);
    } catch (e) {
      _errorMessage = '스프린트를 불러오지 못했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createSprint({
    required String projectId,
    required String name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final sprint = await _service.createSprint(
        projectId: projectId,
        name: name,
        goal: goal,
        startDate: startDate,
        endDate: endDate,
      );
      _sprints = [sprint, ..._sprints];
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '스프린트 생성 실패: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSprint(Sprint sprint) async {
    try {
      final updated = await _service.updateSprint(sprint);
      final idx = _sprints.indexWhere((s) => s.id == updated.id);
      if (idx >= 0) {
        _sprints[idx] = updated;
      } else {
        _sprints = [updated, ..._sprints];
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '스프린트 수정 실패: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSprint(String sprintId) async {
    try {
      await _service.deleteSprint(sprintId);
      _sprints.removeWhere((s) => s.id == sprintId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '스프린트 삭제 실패: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addTaskToSprint(String sprintId, String taskId) async {
    try {
      final updated = await _service.addTaskToSprint(sprintId, taskId);
      final idx = _sprints.indexWhere((s) => s.id == sprintId);
      if (idx >= 0) {
        _sprints[idx] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '태스크 추가 실패: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeTaskFromSprint(String sprintId, String taskId) async {
    try {
      final updated = await _service.removeTaskFromSprint(sprintId, taskId);
      final idx = _sprints.indexWhere((s) => s.id == sprintId);
      if (idx >= 0) {
        _sprints[idx] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '태스크 제거 실패: $e';
      notifyListeners();
      return false;
    }
  }
}
