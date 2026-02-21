import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isPM => _currentUser?.isPM ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _loadCurrentUser();
    _authService.initializeAdmin();
  }

  Future<void> _loadCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.getCurrentUser().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      _errorMessage = null;
    } catch (_) {
      _errorMessage = null;
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

  Future<bool> loginWithGoogle({bool isRegister = false}) async {
    // Do NOT set _isLoading/notifyListeners here — that would unmount LoginScreen
    // via AuthWrapper and make mounted=false before errors can be shown.
    // Login screen uses local loading state for button feedback instead.
    _errorMessage = null;

    try {
      final user = await _authService.loginWithGoogle(
        mode: isRegister ? 'register' : 'login',
      );
      if (user == null) {
        // User cancelled the OAuth popup
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

  Future<bool> loginWithKakao({bool isRegister = false}) async {
    // Same reasoning as loginWithGoogle
    _errorMessage = null;

    try {
      final user = await _authService.loginWithKakao(
        mode: isRegister ? 'register' : 'login',
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
