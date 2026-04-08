import '../utils/api_client.dart';

class ApiTokenInfo {
  final String id;
  final String name;
  final String tokenPrefix;
  final DateTime createdAt;

  const ApiTokenInfo({
    required this.id,
    required this.name,
    required this.tokenPrefix,
    required this.createdAt,
  });

  factory ApiTokenInfo.fromJson(Map<String, dynamic> json) {
    return ApiTokenInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      tokenPrefix: json['token_prefix'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ApiTokenService {
  /// 내 API 토큰 목록 조회
  Future<List<ApiTokenInfo>> listTokens() async {
    final response = await ApiClient.get('/api/tokens');
    final list = ApiClient.handleListResponse(response);
    return list.map((e) => ApiTokenInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 새 API 토큰 발급 — 반환값이 원문 토큰 (이후 복원 불가)
  Future<Map<String, dynamic>> generateToken(String name) async {
    final response = await ApiClient.post('/api/tokens', body: {'name': name});
    return ApiClient.handleResponse(response) as Map<String, dynamic>;
  }

  /// API 토큰 폐기
  Future<void> revokeToken(String id) async {
    await ApiClient.delete('/api/tokens/$id');
  }
}
