import '../utils/api_client.dart';

class AiSummaryResult {
  final String summary;
  final DateTime? generatedAt;
  final bool fromCache;

  const AiSummaryResult({
    required this.summary,
    this.generatedAt,
    this.fromCache = false,
  });
}

class AiService {
  /// [summaryScope] mine | others | all — 서버 `/api/ai/summary?summary_scope=` 와 동일
  /// 같은 날이면 항상 서버 DB 캐시를 반환 (새로고침해도 Gemini 재호출 없음)
  Future<AiSummaryResult> getSummary({
    String? workspaceId,
    String summaryScope = 'all',
  }) async {
    final queryParams = <String, String>{
      'summary_scope': summaryScope,
    };
    if (workspaceId != null && workspaceId.isNotEmpty) {
      queryParams['workspace_id'] = workspaceId;
    }

    final response = await ApiClient.get(
      '/api/ai/summary',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
    final data = ApiClient.handleResponse(response);

    return AiSummaryResult(
      summary: (data['summary']?.toString() ?? '').trim(),
      generatedAt: data['generated_at'] != null
          ? DateTime.tryParse(data['generated_at'].toString())?.toLocal()
          : null,
      fromCache: data['from_cache'] == true,
    );
  }
}
