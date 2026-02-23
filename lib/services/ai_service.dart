import '../utils/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _summaryTextKey = 'ai_summary_text';
  static const String _summaryDateKey = 'ai_summary_date';
  static const String _summaryGeneratedAtKey = 'ai_summary_generated_at';

  Future<AiSummaryResult> getSummary({
    String? workspaceId,
    String? userId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _getCachedSummary(
        userId: userId,
        workspaceId: workspaceId,
      );
      if (cached != null) return cached;
    }

    final queryParams = <String, String>{};
    if (workspaceId != null && workspaceId.isNotEmpty) {
      queryParams['workspace_id'] = workspaceId;
    }

    final response = await ApiClient.get(
      '/api/ai/summary',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
    final data = ApiClient.handleResponse(response);

    final result = AiSummaryResult(
      summary: (data['summary']?.toString() ?? '').trim(),
      generatedAt: data['generated_at'] != null
          ? DateTime.tryParse(data['generated_at'].toString())?.toLocal()
          : null,
    );
    await _saveSummaryToCache(result, userId: userId, workspaceId: workspaceId);
    return result;
  }

  Future<void> clearCache({String? userId, String? workspaceId}) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = _scopeSuffix(userId: userId, workspaceId: workspaceId);
    await prefs.remove('$_summaryDateKey$suffix');
    await prefs.remove('$_summaryTextKey$suffix');
    await prefs.remove('$_summaryGeneratedAtKey$suffix');
  }

  Future<AiSummaryResult?> _getCachedSummary({
    String? userId,
    String? workspaceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = _scopeSuffix(userId: userId, workspaceId: workspaceId);
    final cachedDate = prefs.getString('$_summaryDateKey$suffix');
    if (cachedDate != _todayString()) return null;

    final text = prefs.getString('$_summaryTextKey$suffix');
    if (text == null || text.isEmpty) return null;

    final generatedAtRaw = prefs.getString('$_summaryGeneratedAtKey$suffix');
    final generatedAt = generatedAtRaw != null
        ? DateTime.tryParse(generatedAtRaw)?.toLocal()
        : DateTime.now();

    return AiSummaryResult(
      summary: text,
      generatedAt: generatedAt,
      fromCache: true,
    );
  }

  Future<void> _saveSummaryToCache(
    AiSummaryResult result, {
    String? userId,
    String? workspaceId,
  }) async {
    if (result.summary.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final suffix = _scopeSuffix(userId: userId, workspaceId: workspaceId);
    await prefs.setString('$_summaryDateKey$suffix', _todayString());
    await prefs.setString('$_summaryTextKey$suffix', result.summary);
    await prefs.setString(
      '$_summaryGeneratedAtKey$suffix',
      (result.generatedAt ?? DateTime.now()).toIso8601String(),
    );
  }

  String _todayString() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _scopeSuffix({String? userId, String? workspaceId}) {
    final userScope = (userId != null && userId.isNotEmpty)
        ? userId
        : '__anonymous__';
    final workspaceScope = (workspaceId != null && workspaceId.isNotEmpty)
        ? workspaceId
        : '__no_workspace__';
    return '_${userScope}_$workspaceScope';
  }
}
