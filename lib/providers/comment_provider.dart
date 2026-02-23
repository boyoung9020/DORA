import 'package:flutter/foundation.dart';
import '../models/comment.dart';

/// 댓글 실시간 수신 상태 (작업 상세 화면에서 WebSocket으로 받은 댓글 반영용)
class CommentProvider extends ChangeNotifier {
  /// task_id -> 수신된 댓글 목록 (추가 후 getAndClearIncoming으로 소비)
  final Map<String, List<Comment>> _incomingByTask = {};

  /// WebSocket으로 수신한 댓글 등록 (main_layout에서 comment_created 시 호출)
  void addIncomingComment(String taskId, Comment comment) {
    _incomingByTask.putIfAbsent(taskId, () => []).add(comment);
    notifyListeners();
  }

  /// 해당 태스크의 수신 댓글을 가져오고 목록은 비움 (TaskDetailScreen에서 호출)
  List<Comment> getAndClearIncoming(String taskId) {
    final list = _incomingByTask.remove(taskId);
    if (list != null && list.isNotEmpty) {
      notifyListeners();
      return list;
    }
    return [];
  }
}
