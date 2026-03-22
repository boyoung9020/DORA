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

  /// [summaryScope] mine | others | all — 서버 `/api/ai/summary?summary_scope=` 와 동일
  Future<AiSummaryResult> getSummary({
    String? workspaceId,
    String? projectId,
    String? userId,
    String summaryScope = 'all',
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _getCachedSummary(
        userId: userId,
        workspaceId: workspaceId,
        projectId: projectId,
        summaryScope: summaryScope,
      );
      if (cached != null) return cached;
    }

    final queryParams = <String, String>{
      'summary_scope': summaryScope,
    };
    if (workspaceId != null && workspaceId.isNotEmpty) {
      queryParams['workspace_id'] = workspaceId;
    }
    if (projectId != null && projectId.isNotEmpty) {
      queryParams['project_id'] = projectId;
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
    await _saveSummaryToCache(
      result,
      userId: userId,
      workspaceId: workspaceId,
      projectId: projectId,
      summaryScope: summaryScope,
    );
    return result;
  }

  Future<void> clearCache({
    String? userId,
    String? workspaceId,
    String? projectId,
    String summaryScope = 'all',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = _scopeSuffix(
      userId: userId,
      workspaceId: workspaceId,
      projectId: projectId,
      summaryScope: summaryScope,
    );
    await prefs.remove('$_summaryDateKey$suffix');
    await prefs.remove('$_summaryTextKey$suffix');
    await prefs.remove('$_summaryGeneratedAtKey$suffix');
  }

  Future<AiSummaryResult?> getCachedSummary({
    String? userId,
    String? workspaceId,
    String? projectId,
    String summaryScope = 'all',
  }) =>
      _getCachedSummary(
        userId: userId,
        workspaceId: workspaceId,
        projectId: projectId,
        summaryScope: summaryScope,
      );

  Future<AiSummaryResult?> _getCachedSummary({
    String? userId,
    String? workspaceId,
    String? projectId,
    String summaryScope = 'all',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = _scopeSuffix(
      userId: userId,
      workspaceId: workspaceId,
      projectId: projectId,
      summaryScope: summaryScope,
    );
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
    String? projectId,
    String summaryScope = 'all',
  }) async {
    if (result.summary.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final suffix = _scopeSuffix(
      userId: userId,
      workspaceId: workspaceId,
      projectId: projectId,
      summaryScope: summaryScope,
    );
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

  String _scopeSuffix({
    String? userId,
    String? workspaceId,
    String? projectId,
    String summaryScope = 'all',
  }) {
    final userScope =
        (userId != null && userId.isNotEmpty) ? userId : '__anonymous__';
    final workspaceScope = (workspaceId != null && workspaceId.isNotEmpty)
        ? workspaceId
        : '__no_workspace__';
    final projectScope =
        (projectId != null && projectId.isNotEmpty) ? projectId : '__no_project__';
    final scope = summaryScope.isNotEmpty ? summaryScope : 'all';
    return '_${userScope}_${workspaceScope}_${projectScope}_$scope';
  }
}
