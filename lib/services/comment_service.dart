import '../models/comment.dart';
import '../utils/api_client.dart';

/// 댓글 서비스 클래스
class CommentService {
  /// 모든 댓글 가져오기
  Future<List<Comment>> getAllComments() async {
    // API에는 전체 댓글 목록 엔드포인트가 없으므로
    // 태스크별로만 가져올 수 있음
    return [];
  }

  /// 태스크별 댓글 가져오기
  Future<List<Comment>> getCommentsByTaskId(String taskId) async {
    try {
      final response = await ApiClient.get('/api/comments/task/$taskId');
      final commentsData = ApiClient.handleListResponse(response);
      return commentsData.map((json) => Comment.fromJson(json as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      throw Exception('댓글 목록 가져오기 실패: $e');
    }
  }

  /// 새 댓글 생성
  Future<Comment> createComment({
    required String taskId,
    required String userId,
    required String username,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/comments/',
        body: {
          'task_id': taskId,
          'content': content,
          'image_urls': imageUrls,
        },
      );
      
      final commentData = ApiClient.handleResponse(response);
      return Comment.fromJson(commentData);
    } catch (e) {
      throw Exception('댓글 생성 실패: $e');
    }
  }

  /// 댓글 업데이트
  Future<void> updateComment(Comment comment) async {
    try {
      final response = await ApiClient.patch(
        '/api/comments/${comment.id}',
        body: {
          'content': comment.content,
          'image_urls': comment.imageUrls,
        },
      );
      
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('댓글 업데이트 실패: $e');
    }
  }

  /// 댓글 삭제
  Future<void> deleteComment(String commentId) async {
    try {
      final response = await ApiClient.delete('/api/comments/$commentId');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('댓글 삭제 실패: $e');
    }
  }
}
