import 'dart:convert';
import 'dart:io' show HttpRequest, HttpServer, InternetAddress;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user.dart';
import '../utils/api_client.dart';

class AuthService {
  static const String _currentUserKey = 'current_user';

  GoogleSignIn _buildGoogleSignIn() {
    const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    const googleServerClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    );
    return GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: googleClientId.isNotEmpty ? googleClientId : null,
      serverClientId: (!kIsWeb && googleServerClientId.isNotEmpty)
          ? googleServerClientId
          : null,
    );
  }

  // ── PKCE helpers (Google Desktop용) ──────────────────────────────────────

  String _generateCodeVerifier() {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      128,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  // ── loopback HTTP 서버 응답 헬퍼 ──────────────────────────────────────────

  void _respondToOAuthCallback(
    HttpRequest request, {
    required String provider,
  }) {
    const style = '''
body{font-family:sans-serif;display:flex;align-items:center;justify-content:center;
min-height:100vh;margin:0;background:#FFF8F0;color:#3C2A1A}
.card{text-align:center;padding:40px;border-radius:16px;background:white;
box-shadow:0 4px 24px rgba(0,0,0,.08)}h2{color:#D86B27}''';
    final html =
        '<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8">'
        '<title>$provider 로그인</title><style>$style</style></head>'
        '<body><div class="card"><h2>$provider 로그인 완료</h2>'
        '<p>이 창을 닫고 앱으로 돌아가세요.</p>'
        '<script>window.close();</script></div></body></html>';
    request.response
      ..statusCode = 200
      ..headers.set('Content-Type', 'text/html; charset=utf-8')
      ..write(html);
    request.response.close();
  }

  // ── Google Desktop OAuth (PKCE + authorization code flow) ────────────────

  Future<User?> _loginWithGoogleDesktop({String mode = 'login'}) async {
    const clientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
    const clientSecret = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

    if (clientId.isEmpty || clientSecret.isEmpty) {
      throw Exception(
        'Google Desktop OAuth 설정이 없습니다.\n'
        '--dart-define=GOOGLE_DESKTOP_CLIENT_ID=...\n'
        '--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=... 를 추가하세요.',
      );
    }

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://localhost:${server.port}';

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    if (!await launchUrl(authUri, mode: LaunchMode.externalApplication)) {
      await server.close(force: true);
      throw Exception('브라우저를 열 수 없습니다.');
    }

    String? authCode;
    String? error;
    try {
      final request = await server.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('Google 로그인 시간이 초과되었습니다.'),
      );
      authCode = request.uri.queryParameters['code'];
      error = request.uri.queryParameters['error'];
      _respondToOAuthCallback(request, provider: 'Google');
    } finally {
      await server.close(force: true);
    }

    if (error != null) {
      if (error == 'access_denied') return null;
      throw Exception('Google 인증 오류: $error');
    }
    if (authCode == null || authCode.isEmpty) {
      throw Exception('Google 인증 코드를 받지 못했습니다.');
    }

    final tokenResp = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': authCode,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': codeVerifier,
      },
    );

    if (tokenResp.statusCode != 200) {
      final body = jsonDecode(tokenResp.body) as Map<String, dynamic>;
      throw Exception(
        'Google 토큰 교환 실패: ${body['error_description'] ?? body['error']}',
      );
    }

    final idToken =
        (jsonDecode(tokenResp.body) as Map<String, dynamic>)['id_token']
            as String?;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google ID 토큰을 받지 못했습니다.');
    }

    final response = await ApiClient.post(
      '/api/auth/social/google',
      body: {'id_token': idToken, 'mode': mode},
      includeAuth: false,
    );
    return _consumeLoginTokenResponse(response);
  }

  // ── Kakao Desktop OAuth (authorization code flow) ────────────────────────

  Future<User?> _loginWithKakaoDesktop({String mode = 'login'}) async {
    const restApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');

    if (restApiKey.isEmpty) {
      throw Exception(
        'Kakao REST API 키가 설정되지 않았습니다.\n'
        '--dart-define=KAKAO_REST_API_KEY=... 를 추가하세요.',
      );
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://localhost:${server.port}';

    final authUri = Uri.https('kauth.kakao.com', '/oauth/authorize', {
      'client_id': restApiKey,
      'redirect_uri': redirectUri,
      'response_type': 'code',
    });

    if (!await launchUrl(authUri, mode: LaunchMode.externalApplication)) {
      await server.close(force: true);
      throw Exception('브라우저를 열 수 없습니다.');
    }

    String? authCode;
    String? error;
    try {
      final request = await server.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('카카오 로그인 시간이 초과되었습니다.'),
      );
      authCode = request.uri.queryParameters['code'];
      error = request.uri.queryParameters['error'];
      _respondToOAuthCallback(request, provider: '카카오');
    } finally {
      await server.close(force: true);
    }

    if (error != null) {
      if (error == 'access_denied') return null;
      throw Exception('카카오 인증 오류: $error');
    }
    if (authCode == null || authCode.isEmpty) {
      throw Exception('카카오 인증 코드를 받지 못했습니다.');
    }

    final tokenResp = await http.post(
      Uri.parse('https://kauth.kakao.com/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': restApiKey,
        'redirect_uri': redirectUri,
        'code': authCode,
      },
    );

    if (tokenResp.statusCode != 200) {
      final body = jsonDecode(tokenResp.body) as Map<String, dynamic>;
      throw Exception(
        '카카오 토큰 교환 실패: ${body['error_description'] ?? body['error']}',
      );
    }

    final accessToken =
        (jsonDecode(tokenResp.body) as Map<String, dynamic>)['access_token']
            as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('카카오 액세스 토큰을 받지 못했습니다.');
    }

    final response = await ApiClient.post(
      '/api/auth/social/kakao',
      body: {'access_token': accessToken, 'mode': mode},
      includeAuth: false,
    );
    return _consumeLoginTokenResponse(response);
  }

  Future<User?> _consumeLoginTokenResponse(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = errorBody['detail'] ?? '로그인에 실패했습니다.';
        throw Exception(detail);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('로그인에 실패했습니다.');
      }
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    await ApiClient.saveToken(token);

    final userResponse = await ApiClient.get('/api/auth/me');
    final userData = ApiClient.handleResponse(userResponse);
    final user = User.fromJson(userData);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/auth/register',
        body: {'username': username, 'email': email, 'password': password},
        includeAuth: false,
      );

      ApiClient.handleResponse(response);
      return true;
    } catch (e) {
      throw Exception('회원가입 실패: $e');
    }
  }

  Future<User?> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(
        '/api/auth/login',
        body: {'username': username, 'password': password},
        includeAuth: false,
      );
      return _consumeLoginTokenResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginWithGoogle({String mode = 'login'}) async {
    try {
      if (!kIsWeb) {
        // Windows Desktop: loopback HTTP 서버 + PKCE 방식
        return await _loginWithGoogleDesktop(mode: mode);
      }

      // Web: google_sign_in 패키지 사용
      // idToken이 없으면 accessToken으로 폴백 (웹 implicit flow 제한)
      final googleSignIn = _buildGoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final token = (auth.idToken?.isNotEmpty == true)
          ? auth.idToken!
          : (auth.accessToken ?? '');
      if (token.isEmpty) {
        throw Exception('구글 인증 토큰을 가져오지 못했습니다.');
      }

      final response = await ApiClient.post(
        '/api/auth/social/google',
        body: {'id_token': token, 'mode': mode},
        includeAuth: false,
      );
      return _consumeLoginTokenResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginWithKakao({String mode = 'login'}) async {
    try {
      if (!kIsWeb) {
        // Windows Desktop: loopback HTTP 서버 방식
        return await _loginWithKakaoDesktop(mode: mode);
      }

      // Web: kakao_flutter_sdk_user 패키지 사용 (기존 코드 유지)
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (_) {
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      if (token.accessToken.isEmpty) {
        throw Exception('카카오 인증 토큰을 가져오지 못했습니다.');
      }

      final response = await ApiClient.post(
        '/api/auth/social/kakao',
        body: {'access_token': token.accessToken, 'mode': mode},
        includeAuth: false,
      );
      return _consumeLoginTokenResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      try {
        final response = await ApiClient.get('/api/auth/me');
        final userData = ApiClient.handleResponse(response);
        final user = User.fromJson(userData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));

        return user;
      } catch (_) {
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString(_currentUserKey);
        if (userJson == null) return null;
        return User.fromJson(jsonDecode(userJson));
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await ApiClient.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  Future<List<User>> getAllUsers() async {
    try {
      final response = await ApiClient.get('/api/users/');
      final usersData = ApiClient.handleListResponse(response);
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('사용자 목록 가져오기 실패: $e');
    }
  }

  Future<List<User>> getPendingUsers() async {
    try {
      final response = await ApiClient.get('/api/users/pending/');
      final usersData = ApiClient.handleListResponse(response);
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('승인 대기 사용자 목록 가져오기 실패: $e');
    }
  }

  Future<void> approveUser(String userId) async {
    try {
      final response = await ApiClient.patch('/api/users/$userId/approve');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('사용자 승인 실패: $e');
    }
  }

  Future<void> rejectUser(String userId) async {
    try {
      final response = await ApiClient.delete('/api/users/$userId/reject');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('사용자 거절 실패: $e');
    }
  }

  Future<List<User>> getApprovedUsers() async {
    try {
      final response = await ApiClient.get('/api/users/approved/');
      final usersData = ApiClient.handleListResponse(response);
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('승인된 사용자 목록 가져오기 실패: $e');
    }
  }

  Future<User> updateProfileImage(String imageUrl) async {
    try {
      final response = await ApiClient.patch(
        '/api/users/me/profile-image',
        body: {'profile_image_url': imageUrl},
      );
      final userData = ApiClient.handleResponse(response);
      final user = User.fromJson(userData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));

      return user;
    } catch (e) {
      throw Exception('프로필 이미지 업데이트 실패: $e');
    }
  }

  Future<List<User>> getUsersByWorkspace(String workspaceId) async {
    try {
      final response = await ApiClient.get(
        '/api/users/?workspace_id=$workspaceId',
      );
      final usersData = ApiClient.handleListResponse(response);
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('워크스페이스 사용자 목록 가져오기 실패: $e');
    }
  }

  Future<User?> getUserById(String userId) async {
    try {
      final response = await ApiClient.get('/api/users/$userId');
      final userData = ApiClient.handleResponse(response);
      return User.fromJson(userData);
    } catch (_) {
      return null;
    }
  }

  Future<void> grantPMPermission(String userId) async {
    try {
      final response = await ApiClient.patch('/api/users/$userId/grant-pm');
      final userData = ApiClient.handleResponse(response);

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

  Future<void> revokePMPermission(String userId) async {
    try {
      final response = await ApiClient.patch('/api/users/$userId/revoke-pm');
      final userData = ApiClient.handleResponse(response);

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

  Future<void> initializeAdmin() async {}
}
