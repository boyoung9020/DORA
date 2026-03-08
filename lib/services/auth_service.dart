import 'dart:convert';
import 'dart:io' show HttpRequest, HttpServer, InternetAddress;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user.dart';
import '../utils/api_client.dart';

class AuthService {
  static const String _currentUserKey = 'current_user';
  static const String _pendingWebSocialAuthKey = 'pending_web_social_auth';
  static const String _pendingSocialRegisterDataKey = 'pending_social_register_data';

  // ?? PKCE helpers (Google Desktop?? ??????????????????????????????????????

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

  String _generateStateToken() {
    final random = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(40, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _currentWebRedirectUri() {
    const configuredRedirectUri = String.fromEnvironment(
      'WEB_SOCIAL_REDIRECT_URI',
    );
    if (configuredRedirectUri.isNotEmpty) {
      // Use the configured URI exactly as-is so it matches what is
      // registered in Google Cloud Console / Kakao Developers.
      return configuredRedirectUri;
    }
    final current = Uri.base;
    return current.replace(path: '/', query: null, fragment: null).toString();
  }

  Future<void> _savePendingWebSocialAuth({
    required String provider,
    required String mode,
    required String state,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingWebSocialAuthKey,
      jsonEncode({
        'provider': provider,
        'mode': mode,
        'state': state,
        'code_verifier': codeVerifier,
        'redirect_uri': redirectUri,
      }),
    );
  }

  Future<Map<String, dynamic>?> _loadPendingWebSocialAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingWebSocialAuthKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      await prefs.remove(_pendingWebSocialAuthKey);
      return null;
    }
  }

  Future<void> _clearPendingWebSocialAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingWebSocialAuthKey);
  }

  Future<void> _startGoogleWebRedirectFlow({required String mode}) async {
    const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    if (googleClientId.isEmpty) {
      throw Exception('Google OAuth client id is not configured for web.');
    }
    final redirectUri = _currentWebRedirectUri();

    final state = _generateStateToken();
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    await _savePendingWebSocialAuth(
      provider: 'google',
      mode: mode,
      state: state,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
    );

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': googleClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'prompt': 'select_account',
    });

    final launched = await launchUrl(authUri, webOnlyWindowName: '_self');
    if (!launched) {
      await _clearPendingWebSocialAuth();
      throw Exception('Failed to open Google authentication page.');
    }
  }

  Future<void> _startKakaoWebRedirectFlow({required String mode}) async {
    const restApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');
    if (restApiKey.isEmpty) {
      throw Exception('Kakao REST API key is not configured for web.');
    }
    final redirectUri = _currentWebRedirectUri();

    final state = _generateStateToken();
    final codeVerifier = _generateCodeVerifier();

    await _savePendingWebSocialAuth(
      provider: 'kakao',
      mode: mode,
      state: state,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
    );

    final authUri = Uri.https('kauth.kakao.com', '/oauth/authorize', {
      'client_id': restApiKey,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'state': state,
    });

    final launched = await launchUrl(authUri, webOnlyWindowName: '_self');
    if (!launched) {
      await _clearPendingWebSocialAuth();
      throw Exception('Failed to open Kakao authentication page.');
    }
  }

  Future<User?> completePendingWebSocialLogin() async {
    if (!kIsWeb) return null;

    final pending = await _loadPendingWebSocialAuth();
    if (pending == null) return null;

    final query = Uri.base.queryParameters;
    final code = query['code'];
    final state = query['state'];
    final error = query['error'];
    final errorDescription = query['error_description'];
    if (code == null && error == null) {
      return null;
    }

    if (error != null) {
      await _clearPendingWebSocialAuth();
      if (error == 'access_denied') return null;
      throw Exception(errorDescription ?? 'Social login failed.');
    }

    final expectedState = pending['state'] as String?;
    if (state == null || expectedState == null || state != expectedState) {
      await _clearPendingWebSocialAuth();
      throw Exception('Invalid social login state.');
    }
    if (code == null || code.isEmpty) {
      await _clearPendingWebSocialAuth();
      throw Exception('Missing social login authorization code.');
    }

    final provider = pending['provider'] as String?;
    final mode = (pending['mode'] as String?) ?? 'login';
    final codeVerifier = pending['code_verifier'] as String?;
    final redirectUri = pending['redirect_uri'] as String?;
    if (provider == null || codeVerifier == null || redirectUri == null) {
      await _clearPendingWebSocialAuth();
      throw Exception('Invalid pending social login state.');
    }

    await _clearPendingWebSocialAuth();

    // For register mode: save the OAuth data and wait for username input.
    if (mode == 'register') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingSocialRegisterDataKey,
        jsonEncode({
          'provider': provider,
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': codeVerifier,
        }),
      );
      return null;
    }

    final endpoint = provider == 'google'
        ? '/api/auth/social/google/code'
        : '/api/auth/social/kakao/code';

    final response = await ApiClient.post(
      endpoint,
      body: {
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
        'mode': mode,
      },
      includeAuth: false,
    );

    // 신규 유저: 백엔드가 202 + registration_token 반환 → 유저이름 입력 화면으로
    if (response.statusCode == 202) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final registrationToken = body['registration_token'] as String?;
      if (registrationToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _pendingSocialRegisterDataKey,
          jsonEncode({
            'provider': provider,
            'registration_token': registrationToken,
          }),
        );
      }
      return null;
    }

    return _consumeLoginTokenResponse(response);
  }

  Future<bool> hasPendingSocialRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pendingSocialRegisterDataKey);
  }

  Future<String?> getPendingSocialRegistrationProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingSocialRegisterDataKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data['provider'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingSocialRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSocialRegisterDataKey);
  }

  Future<User?> completeSocialRegistration(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingSocialRegisterDataKey);
    if (raw == null) throw Exception('진행 중인 소셜 회원가입이 없습니다.');

    final data = jsonDecode(raw) as Map<String, dynamic>;
    await prefs.remove(_pendingSocialRegisterDataKey);

    // 신규 유저 경로: registration_token 방식 (login 버튼 → 신규 유저)
    final registrationToken = data['registration_token'] as String?;
    if (registrationToken != null) {
      final response = await ApiClient.post(
        '/api/auth/social/complete_registration',
        body: {'registration_token': registrationToken, 'username': username},
        includeAuth: false,
      );
      return _consumeLoginTokenResponse(response);
    }

    // 기존 경로: code 방식 (register 버튼으로 온 경우)
    final provider = data['provider'] as String;
    final code = data['code'] as String;
    final redirectUri = data['redirect_uri'] as String;
    final codeVerifier = data['code_verifier'] as String;

    final endpoint = provider == 'google'
        ? '/api/auth/social/google/code'
        : '/api/auth/social/kakao/code';

    final response = await ApiClient.post(
      endpoint,
      body: {
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
        'mode': 'register',
        'username': username,
      },
      includeAuth: false,
    );
    return _consumeLoginTokenResponse(response);
  }

  // ?? loopback HTTP ?쒕쾭 ?묐떟 ?ы띁 ??????????????????????????????????????????

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
        '<title>$provider Login</title><style>$style</style></head>'
        '<body><div class="card"><h2>$provider Login Complete</h2>'
        '<p>You can close this window and return to the app.</p>'
        '<script>window.close();</script></div></body></html>';
    request.response
      ..statusCode = 200
      ..headers.set('Content-Type', 'text/html; charset=utf-8')
      ..write(html);
    request.response.close();
  }

  // ?? Google Desktop OAuth (PKCE + authorization code flow) ????????????????

  Future<User?> _loginWithGoogleDesktop({
    String mode = 'login',
    Future<String?> Function()? usernameCallback,
  }) async {
    const clientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
    const clientSecret = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

    if (clientId.isEmpty || clientSecret.isEmpty) {
      throw Exception(
        'Google Desktop OAuth ?ㅼ젙???놁뒿?덈떎.\n'
        '--dart-define=GOOGLE_DESKTOP_CLIENT_ID=...\n'
        '--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=... 瑜?異붽??섏꽭??',
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
      throw Exception('釉뚮씪?곗?瑜??????놁뒿?덈떎.');
    }

    String? authCode;
    String? error;
    try {
      final request = await server.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('Google 濡쒓렇???쒓컙??珥덇낵?섏뿀?듬땲??'),
      );
      authCode = request.uri.queryParameters['code'];
      error = request.uri.queryParameters['error'];
      _respondToOAuthCallback(request, provider: 'Google');
    } finally {
      await server.close(force: true);
    }

    if (error != null) {
      if (error == 'access_denied') return null;
      throw Exception('Google ?몄쬆 ?ㅻ쪟: $error');
    }
    if (authCode == null || authCode.isEmpty) {
      throw Exception('Google ?몄쬆 肄붾뱶瑜?諛쏆? 紐삵뻽?듬땲??');
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
        'Google ?좏겙 援먰솚 ?ㅽ뙣: ${body['error_description'] ?? body['error']}',
      );
    }

    final idToken =
        (jsonDecode(tokenResp.body) as Map<String, dynamic>)['id_token']
            as String?;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google ID ?좏겙??諛쏆? 紐삵뻽?듬땲??');
    }

    String? username;
    if (mode == 'register' && usernameCallback != null) {
      username = await usernameCallback();
      if (username == null) return null; // user cancelled
    }

    final reqBody = <String, String>{'id_token': idToken, 'mode': mode};
    if (username != null) reqBody['username'] = username;

    final response = await ApiClient.post(
      '/api/auth/social/google',
      body: reqBody,
      includeAuth: false,
    );
    return _consumeLoginTokenResponse(response);
  }

  // ?? Kakao Desktop OAuth (authorization code flow) ????????????????????????

  Future<User?> _loginWithKakaoDesktop({
    String mode = 'login',
    Future<String?> Function()? usernameCallback,
  }) async {
    const restApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');

    if (restApiKey.isEmpty) {
      throw Exception(
        'Kakao REST API ?ㅺ? ?ㅼ젙?섏? ?딆븯?듬땲??\n'
        '--dart-define=KAKAO_REST_API_KEY=... 瑜?異붽??섏꽭??',
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
      throw Exception('釉뚮씪?곗?瑜??????놁뒿?덈떎.');
    }

    String? authCode;
    String? error;
    try {
      final request = await server.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('移댁뭅??濡쒓렇???쒓컙??珥덇낵?섏뿀?듬땲??'),
      );
      authCode = request.uri.queryParameters['code'];
      error = request.uri.queryParameters['error'];
      _respondToOAuthCallback(request, provider: 'Kakao');
    } finally {
      await server.close(force: true);
    }

    if (error != null) {
      if (error == 'access_denied') return null;
      throw Exception('移댁뭅???몄쬆 ?ㅻ쪟: $error');
    }
    if (authCode == null || authCode.isEmpty) {
      throw Exception('移댁뭅???몄쬆 肄붾뱶瑜?諛쏆? 紐삵뻽?듬땲??');
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
        '移댁뭅???좏겙 援먰솚 ?ㅽ뙣: ${body['error_description'] ?? body['error']}',
      );
    }

    final accessToken =
        (jsonDecode(tokenResp.body) as Map<String, dynamic>)['access_token']
            as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('移댁뭅???≪꽭???좏겙??諛쏆? 紐삵뻽?듬땲??');
    }

    String? username;
    if (mode == 'register' && usernameCallback != null) {
      username = await usernameCallback();
      if (username == null) return null; // user cancelled
    }

    final reqBody = <String, String>{'access_token': accessToken, 'mode': mode};
    if (username != null) reqBody['username'] = username;

    final response = await ApiClient.post(
      '/api/auth/social/kakao',
      body: reqBody,
      includeAuth: false,
    );
    return _consumeLoginTokenResponse(response);
  }

  Future<User?> _consumeLoginTokenResponse(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = errorBody['detail'] ?? '濡쒓렇?몄뿉 ?ㅽ뙣?덉뒿?덈떎.';
        throw Exception(detail);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('濡쒓렇?몄뿉 ?ㅽ뙣?덉뒿?덈떎.');
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
      throw Exception('?뚯썝媛???ㅽ뙣: $e');
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

  Future<User?> loginWithGoogle({
    String mode = 'login',
    Future<String?> Function()? usernameCallback,
  }) async {
    try {
      if (!kIsWeb) {
        return await _loginWithGoogleDesktop(
          mode: mode,
          usernameCallback: usernameCallback,
        );
      }

      await _startGoogleWebRedirectFlow(mode: mode);
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginWithKakao({
    String mode = 'login',
    Future<String?> Function()? usernameCallback,
  }) async {
    try {
      if (!kIsWeb) {
        return await _loginWithKakaoDesktop(
          mode: mode,
          usernameCallback: usernameCallback,
        );
      }

      await _startKakaoWebRedirectFlow(mode: mode);
      return null;
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
      throw Exception('?ъ슜??紐⑸줉 媛?몄삤湲??ㅽ뙣: $e');
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
      throw Exception('?뱀씤 ?湲??ъ슜??紐⑸줉 媛?몄삤湲??ㅽ뙣: $e');
    }
  }

  Future<void> approveUser(String userId) async {
    try {
      final response = await ApiClient.patch('/api/users/$userId/approve');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('?ъ슜???뱀씤 ?ㅽ뙣: $e');
    }
  }

  Future<void> rejectUser(String userId) async {
    try {
      final response = await ApiClient.delete('/api/users/$userId/reject');
      ApiClient.handleResponse(response);
    } catch (e) {
      throw Exception('?ъ슜??嫄곗젅 ?ㅽ뙣: $e');
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
      throw Exception('?뱀씤???ъ슜??紐⑸줉 媛?몄삤湲??ㅽ뙣: $e');
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
      throw Exception('?꾨줈???대?吏 ?낅뜲?댄듃 ?ㅽ뙣: $e');
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
      throw Exception('?뚰겕?ㅽ럹?댁뒪 ?ъ슜??紐⑸줉 媛?몄삤湲??ㅽ뙣: $e');
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
      throw Exception('PM 沅뚰븳 遺???ㅽ뙣: $e');
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
      throw Exception('PM 沅뚰븳 ?쒓굅 ?ㅽ뙣: $e');
    }
  }

  Future<void> initializeAdmin() async {}
}
