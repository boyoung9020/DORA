import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comment.dart';

/// 댓글 서비스 클래스
class CommentService {
  static const String _commentsKey = 'comments';

  /// 고유 ID 생성
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 모든 댓글 가져오기
  Future<List<Comment>> getAllComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentsJson = prefs.getString(_commentsKey);
      
      if (commentsJson == null) {
        return [];
      }

      final List<dynamic> commentsList = json.decode(commentsJson);
      return commentsList.map((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 태스크별 댓글 가져오기
  Future<List<Comment>> getCommentsByTaskId(String taskId) async {
    final allComments = await getAllComments();
    return allComments.where((comment) => comment.taskId == taskId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 댓글 저장
  Future<void> _saveComments(List<Comment> comments) async {
    final prefs = await SharedPreferences.getInstance();
    final commentsJson = json.encode(
      comments.map((comment) => comment.toJson()).toList(),
    );
    await prefs.setString(_commentsKey, commentsJson);
  }

  /// 새 댓글 생성
  Future<Comment> createComment({
    required String taskId,
    required String userId,
    required String username,
    required String content,
  }) async {
    final comment = Comment(
      id: _generateId(),
      taskId: taskId,
      userId: userId,
      username: username,
      content: content,
      createdAt: DateTime.now(),
    );

    final comments = await getAllComments();
    comments.add(comment);
    await _saveComments(comments);

    return comment;
  }

  /// 댓글 업데이트
  Future<void> updateComment(Comment comment) async {
    final comments = await getAllComments();
    final index = comments.indexWhere((c) => c.id == comment.id);
    
    if (index != -1) {
      comments[index] = comment.copyWith(updatedAt: DateTime.now());
      await _saveComments(comments);
    }
  }

  /// 댓글 삭제
  Future<void> deleteComment(String commentId) async {
    final comments = await getAllComments();
    comments.removeWhere((comment) => comment.id == commentId);
    await _saveComments(comments);
  }
}

