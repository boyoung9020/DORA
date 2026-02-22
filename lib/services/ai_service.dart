import '../utils/api_client.dart';

class AiSummaryResult {
  final String summary;
  final DateTime? generatedAt;

  const AiSummaryResult({
    required this.summary,
    this.generatedAt,
  });
}

class AiService {
  Future<AiSummaryResult> getSummary({String? workspaceId}) async {
    final queryParams = <String, String>{};
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
    );
  }
}
