import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// 인증 상태 관리 Provider
/// 
/// 이 클래스는 앱 전체에서 사용자 인증 상태를 관리합니다.
/// Provider 패턴을 사용하여 상태를 공유합니다.
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
    // 앱 시작 시 현재 사용자 확인
    _loadCurrentUser();
    // 관리자 계정 초기화
    _authService.initializeAdmin();
  }

  /// 현재 사용자 로드
  Future<void> _loadCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 타임아웃 설정 (5초)
      _currentUser = await _authService.getCurrentUser().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[AuthProvider] 사용자 로드 타임아웃');
          return null;
        },
      );
      _errorMessage = null;
    } catch (e) {
      print('[AuthProvider] 사용자 로드 실패: $e');
      _errorMessage = null; // 에러 메시지는 표시하지 않음 (로그인 화면으로 이동)
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 로그인
  Future<bool> login(String username, String password) async {
    print('[AuthProvider] 로그인 시도: $username');
    // 이전 상태 완전히 초기화
    _currentUser = null;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    print('[AuthProvider] 상태 초기화 완료, isLoading: $_isLoading');

    try {
      print('[AuthProvider] AuthService.login 호출 중...');
      final user = await _authService.login(
        username: username,
        password: password,
      );
      print('[AuthProvider] AuthService.login 결과: ${user != null ? "성공" : "실패"}');

      if (user != null) {
        print('[AuthProvider] 사용자 정보: ${user.username}, isAdmin: ${user.isAdmin}, isApproved: ${user.isApproved}');
        _currentUser = user;
        _errorMessage = null;
        _isLoading = false;
        print('[AuthProvider] 로그인 성공, notifyListeners 호출');
        notifyListeners();
        print('[AuthProvider] isAuthenticated: $isAuthenticated');
        return true;
      }
      _isLoading = false;
      _errorMessage = '로그인에 실패했습니다.';
      print('[AuthProvider] 로그인 실패: 사용자 정보 없음');
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      _errorMessage = e.toString();
      _isLoading = false;
      print('[AuthProvider] 로그인 에러: $e');
      print('[AuthProvider] 스택 트레이스: $stackTrace');
      notifyListeners();
      return false;
    }
  }

  /// 현재 사용자 정보 새로고침 (PM 권한 변경 등 반영)
  Future<void> refreshCurrentUser() async {
    try {
      _currentUser = await _authService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      // 에러 무시
    }
  }

  /// 회원가입
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
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    print('[AuthProvider] 로그아웃 시작');
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
      _errorMessage = null;
      print('[AuthProvider] 로그아웃 완료, _currentUser: $_currentUser, isAuthenticated: $isAuthenticated');
    } catch (e) {
      _errorMessage = e.toString();
      print('[AuthProvider] 로그아웃 에러: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      print('[AuthProvider] 로그아웃 완료, isLoading: $_isLoading');
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

