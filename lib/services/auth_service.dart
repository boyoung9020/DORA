import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/api_client.dart';
import 'package:http/http.dart' as http;

/// 인증 서비스 클래스
/// 
/// 이 클래스는 사용자 인증과 관련된 모든 기능을 담당합니다:
/// - 회원가입
/// - 로그인
/// - 로그아웃
/// - 사용자 데이터 관리
/// - 관리자 승인 관리
class AuthService {
  static const String _currentUserKey = 'current_user';

  /// 회원가입
  /// 
  /// 새로운 사용자를 생성합니다. 관리자 승인이 필요하므로
  /// isApproved는 false로 시작합니다.
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/auth/register',
        body: {
          'username': username,
          'email': email,
          'password': password,
        },
        includeAuth: false,
      );

      ApiClient.handleResponse(response);
      return true;
    } catch (e) {
      throw Exception('회원가입 실패: $e');
    }
  }

  /// 로그인
  /// 
  /// 사용자 이름과 비밀번호로 로그인합니다.
  /// 승인된 사용자만 로그인할 수 있습니다.
  Future<User?> login({
    required String username,
    required String password,
  }) async {
    print('[AuthService] login 호출: $username');
    try {
      final response = await ApiClient.post(
        '/api/auth/login',
        body: {
          'username': username,
          'password': password,
        },
        includeAuth: false,
      );

      final data = ApiClient.handleResponse(response);
      
      // JWT 토큰 저장
      final token = data['access_token'] as String;
      await ApiClient.saveToken(token);

      // 현재 사용자 정보 가져오기
      final userResponse = await ApiClient.get('/api/auth/me');
      final userData = ApiClient.handleResponse(userResponse);
      
      final user = User.fromJson(userData);
      
      // 현재 사용자 정보 로컬 저장 (오프라인 지원)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
      
      print('[AuthService] 로그인 완료: ${user.username}');
      return user;
    } catch (e) {
      print('[AuthService] 로그인 에러: $e');
      throw Exception('로그인 실패: $e');
    }
  }

  /// 현재 로그인한 사용자 가져오기
  Future<User?> getCurrentUser() async {
    try {
      // 먼저 API에서 최신 정보 가져오기 시도
      try {
        final response = await ApiClient.get('/api/auth/me');
        final userData = ApiClient.handleResponse(response);
        final user = User.fromJson(userData);
        
        // 로컬에도 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
        
        return user;
      } catch (e) {
        // API 호출 실패 시 로컬 저장소에서 가져오기
        print('[AuthService] API 호출 실패, 로컬 데이터 사용: $e');
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString(_currentUserKey);
        if (userJson == null) return null;
        return User.fromJson(jsonDecode(userJson));
      }
    } catch (e) {
      return null;
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    print('[AuthService] logout 호출');
    await ApiClient.clearToken();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    print('[AuthService] 로그아웃 완료');
  }

  /// 모든 사용자 목록 가져오기 (관리자만)
  Future<List<User>> getAllUsers() async {
    try {
      final response = await ApiClient.get('/api/users');
      final usersData = ApiClient.handleListResponse(response);
      return usersData.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('사용자 목록 가져오기 실패: $e');
    }
  }

  /// 승인 대기 중인 사용자 목록 가져오기
  Future<List<User>> getPendingUsers() async {
    try {
      final response = await ApiClient.get('/api/users/pending');
      final usersData = ApiClient.handleListResponse(response);
      return usersData.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('승인 대기 사용자 목록 가져오기 실패: $e');
    }
  }

  /// 사용자 승인
  /// 
  /// 관리자가 회원가입 신청을 승인합니다.
  Future<void> approveUser(String userId) async {
    try {
      final response = await ApiClient.patch('/api/users/$userId/approve');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('사용자 승인 실패: $e');
    }
  }

  /// 사용자 거부
  /// 
  /// 관리자가 회원가입 신청을 거부합니다.
  Future<void> rejectUser(String userId) async {
    try {
      final response = await ApiClient.delete('/api/users/$userId/reject');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('사용자 거부 실패: $e');
    }
  }

  /// 승인된 사용자 목록 가져오기
  Future<List<User>> getApprovedUsers() async {
    try {
      // PM도 사용할 수 있도록 인증 포함
      final response = await ApiClient.get('/api/users/approved');
      final usersData = ApiClient.handleListResponse(response);
      return usersData.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('승인된 사용자 목록 가져오기 실패: $e');
    }
  }

  /// ID로 사용자 가져오기
  Future<User?> getUserById(String userId) async {
    try {
      final response = await ApiClient.get('/api/users/$userId');
      final userData = ApiClient.handleResponse(response);
      return User.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  /// PM 권한 부여
  /// 
  /// 관리자가 사용자에게 PM 권한을 부여합니다.
  Future<void> grantPMPermission(String userId) async {
    try {
      final response = await ApiClient.patch('/api/users/$userId/grant-pm');
      final userData = ApiClient.handleResponse(response);
      
      // 현재 로그인한 사용자가 변경된 경우 현재 사용자 정보도 업데이트
      final prefs = await SharedPreferences.getInstance();
      final currentUserJson = prefs.getString(_currentUserKey);
      if (currentUserJson != null) {
        final currentUser = User.fromJson(jsonDecode(currentUserJson));
        if (currentUser.id == userId) {
          await prefs.setString(_currentUserKey, jsonEncode(userData));
        }
      }
    } catch (e) {
      throw Exception('PM 권한 부여 실패: $e');
    }
  }

  /// PM 권한 제거
  /// 
  /// 관리자가 사용자의 PM 권한을 제거합니다.
  Future<void> revokePMPermission(String userId) async {
    try {
      final response = await ApiClient.patch('/api/users/$userId/revoke-pm');
      final userData = ApiClient.handleResponse(response);
      
      // 현재 로그인한 사용자가 변경된 경우 현재 사용자 정보도 업데이트
      final prefs = await SharedPreferences.getInstance();
      final currentUserJson = prefs.getString(_currentUserKey);
      if (currentUserJson != null) {
        final currentUser = User.fromJson(jsonDecode(currentUserJson));
        if (currentUser.id == userId) {
          await prefs.setString(_currentUserKey, jsonEncode(userData));
        }
      }
    } catch (e) {
      throw Exception('PM 권한 제거 실패: $e');
    }
  }

  /// 초기 관리자 계정 생성
  /// 
  /// 서버에서 자동으로 생성되므로 더 이상 필요 없음
  /// 호환성을 위해 빈 함수로 유지
  Future<void> initializeAdmin() async {
    // 서버에서 자동으로 관리자 계정을 생성하므로
    // 클라이언트에서는 아무 작업도 하지 않음
  }
}
