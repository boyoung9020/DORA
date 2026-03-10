import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/api_client.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasPendingSocialRegistration = false;
  String? _pendingSocialProvider;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isPM => _currentUser?.isPM ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPendingSocialRegistration => _hasPendingSocialRegistration;
  String? get pendingSocialProvider => _pendingSocialProvider;

  AuthProvider() {
    // 토큰 만료(401) 시 자동 로그아웃
    ApiClient.onUnauthorized = _forceLogout;
    _loadCurrentUser();
    _authService.initializeAdmin();
  }

  void _forceLogout() {
    _currentUser = null;
    _errorMessage = '세션이 만료되었습니다. 다시 로그인해주세요.';
    notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final socialUser = await _authService
          .completePendingWebSocialLogin()
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      if (socialUser != null) {
        _currentUser = socialUser;
        _errorMessage = null;
        return;
      }

      // Web register redirect: OAuth code saved, waiting for username input.
      if (await _authService.hasPendingSocialRegistration()) {
        _hasPendingSocialRegistration = true;
        _pendingSocialProvider =
            await _authService.getPendingSocialRegistrationProvider();
        return;
      }

      _currentUser = await _authService.getCurrentUser().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _currentUser = null;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.login(
        username: username,
        password: password,
      );
      if (user != null) {
        _currentUser = user;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = '로그인에 실패했습니다.';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle({
    bool isRegister = false,
    Future<String?> Function()? onNeedUsername,
  }) async {
    // Do NOT set _isLoading/notifyListeners here — that would unmount LoginScreen
    // via AuthWrapper and make mounted=false before errors can be shown.
    // Login screen uses local loading state for button feedback instead.
    _errorMessage = null;

    try {
      final user = await _authService.loginWithGoogle(
        mode: isRegister ? 'register' : 'login',
        usernameCallback: onNeedUsername,
      );
      if (user == null) {
        // User cancelled or web redirect triggered (no user yet).
        notifyListeners();
        return false;
      }

      _currentUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithKakao({
    bool isRegister = false,
    Future<String?> Function()? onNeedUsername,
  }) async {
    // Same reasoning as loginWithGoogle
    _errorMessage = null;

    try {
      final user = await _authService.loginWithKakao(
        mode: isRegister ? 'register' : 'login',
        usernameCallback: onNeedUsername,
      );
      if (user == null) {
        notifyListeners();
        return false;
      }

      _currentUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Finishes web social registration after the user has entered a username.
  Future<bool> completeSocialRegistration(String username) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.completeSocialRegistration(username);
      if (user != null) {
        _currentUser = user;
        _hasPendingSocialRegistration = false;
        _pendingSocialProvider = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _hasPendingSocialRegistration = false;
      _pendingSocialProvider = null;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelSocialRegistration() async {
    await _authService.clearPendingSocialRegistration();
    _hasPendingSocialRegistration = false;
    _pendingSocialProvider = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    try {
      _currentUser = await _authService.getCurrentUser();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.register(
        username: username,
        email: email,
        password: password,
      );
      if (success) {
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfileImage(String imageUrl) async {
    try {
      _currentUser = await _authService.updateProfileImage(imageUrl);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
