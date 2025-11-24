/// API 클라이언트 유틸리티
/// HTTP 요청을 보내고 응답을 처리하는 공통 함수들
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // API 베이스 URL
  // 로컬 개발: http://localhost
  // 프로덕션: 실제 서버 주소로 변경
  static const String baseUrl = 'http://192.168.1.102:8000';
  
  // JWT 토큰 저장 키
  static const String _tokenKey = 'auth_token';

  /// JWT 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// JWT 토큰 저장
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// JWT 토큰 삭제
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// 인증 헤더 생성
  static Future<Map<String, String>> _getHeaders({
    bool includeAuth = true,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// GET 요청
  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(includeAuth: includeAuth),
      );

      return response;
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// POST 요청
  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      
      final response = await http.post(
        uri,
        headers: await _getHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return response;
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// PATCH 요청
  static Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      
      final response = await http.patch(
        uri,
        headers: await _getHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return response;
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// DELETE 요청
  static Future<http.Response> delete(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      
      final response = await http.delete(
        uri,
        headers: await _getHeaders(includeAuth: includeAuth),
      );

      return response;
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 응답 처리 (에러 체크 및 JSON 파싱)
  static Map<String, dynamic> handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      // 인증 오류 - 토큰 삭제
      clearToken();
      throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
    } else {
      // 에러 메시지 파싱 시도
      try {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorBody['detail'] ?? '요청 처리 중 오류가 발생했습니다.';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('서버 오류 (${response.statusCode}): ${response.body}');
      }
    }
  }

  /// 리스트 응답 처리
  static List<dynamic> handleListResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('서버 오류 (${response.statusCode}): ${response.body}');
    }
  }
}

