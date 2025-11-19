import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// 인증 서비스 클래스
/// 
/// 이 클래스는 사용자 인증과 관련된 모든 기능을 담당합니다:
/// - 회원가입
/// - 로그인
/// - 로그아웃
/// - 사용자 데이터 관리
/// - 관리자 승인 관리
class AuthService {
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'current_user';

  /// 비밀번호를 SHA-256으로 해싱
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 고유 ID 생성
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 모든 사용자 가져오기
  Future<List<User>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList(_usersKey) ?? [];
    return usersJson.map((json) => User.fromJson(jsonDecode(json))).toList();
  }

  /// ID로 사용자 가져오기
  Future<User?> getUserById(String userId) async {
    try {
      final users = await getAllUsers();
      return users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  /// 사용자 저장
  Future<void> _saveUsers(List<User> users) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = users.map((user) => jsonEncode(user.toJson())).toList();
    await prefs.setStringList(_usersKey, usersJson);
  }

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
      // 기존 사용자 확인
      final users = await getAllUsers();
      
      // 중복 체크
      if (users.any((user) => user.username == username)) {
        throw Exception('이미 사용 중인 사용자 이름입니다.');
      }
      if (users.any((user) => user.email == email)) {
        throw Exception('이미 사용 중인 이메일입니다.');
      }

      // 새 사용자 생성
      final newUser = User(
        id: _generateId(),
        username: username,
        email: email,
        passwordHash: _hashPassword(password),
        isAdmin: false,
        isApproved: false, // 관리자 승인 대기 상태
        createdAt: DateTime.now(),
      );

      // 사용자 목록에 추가
      users.add(newUser);
      await _saveUsers(users);

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
      final users = await getAllUsers();
      print('[AuthService] 전체 사용자 수: ${users.length}');
      final passwordHash = _hashPassword(password);
      print('[AuthService] 비밀번호 해시 완료');

      // 사용자 찾기
      User? foundUser;
      try {
        foundUser = users.firstWhere(
          (u) => u.username == username && u.passwordHash == passwordHash,
        );
        print('[AuthService] 사용자 찾음: ${foundUser.username}, isApproved: ${foundUser.isApproved}, isAdmin: ${foundUser.isAdmin}');
      } catch (e) {
        print('[AuthService] 사용자를 찾을 수 없음: $e');
        throw Exception('사용자 이름 또는 비밀번호가 잘못되었습니다.');
      }

      // 승인 여부 확인
      if (!foundUser.isApproved) {
        print('[AuthService] 사용자 승인 대기 중');
        throw Exception('관리자 승인 대기 중입니다. 승인 후 로그인할 수 있습니다.');
      }

      // 현재 사용자 저장
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(foundUser.toJson());
      await prefs.setString(_currentUserKey, userJson);
      print('[AuthService] 현재 사용자 저장 완료: $_currentUserKey');

      return foundUser;
    } catch (e) {
      print('[AuthService] 로그인 에러: $e');
      throw Exception('로그인 실패: $e');
    }
  }

  /// 현재 로그인한 사용자 가져오기
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      if (userJson == null) return null;
      return User.fromJson(jsonDecode(userJson));
    } catch (e) {
      return null;
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    print('[AuthService] logout 호출');
    final prefs = await SharedPreferences.getInstance();
    final hadUser = prefs.containsKey(_currentUserKey);
    await prefs.remove(_currentUserKey);
    print('[AuthService] 로그아웃 완료, 이전 사용자 존재: $hadUser');
  }

  /// 승인 대기 중인 사용자 목록 가져오기
  Future<List<User>> getPendingUsers() async {
    final users = await getAllUsers();
    return users.where((user) => !user.isApproved && !user.isAdmin).toList();
  }

  /// 사용자 승인
  /// 
  /// 관리자가 회원가입 신청을 승인합니다.
  Future<void> approveUser(String userId) async {
    final users = await getAllUsers();
    final userIndex = users.indexWhere((u) => u.id == userId);
    
    if (userIndex == -1) {
      throw Exception('사용자를 찾을 수 없습니다.');
    }

    // 사용자 승인
    users[userIndex] = users[userIndex].copyWith(isApproved: true);
    await _saveUsers(users);
  }

  /// 사용자 거부
  /// 
  /// 관리자가 회원가입 신청을 거부합니다.
  Future<void> rejectUser(String userId) async {
    final users = await getAllUsers();
    users.removeWhere((u) => u.id == userId);
    await _saveUsers(users);
  }

  /// 승인된 사용자 목록 가져오기
  Future<List<User>> getApprovedUsers() async {
    final users = await getAllUsers();
    return users.where((user) => user.isApproved).toList();
  }

  /// PM 권한 부여
  /// 
  /// 관리자가 사용자에게 PM 권한을 부여합니다.
  Future<void> grantPMPermission(String userId) async {
    final users = await getAllUsers();
    final userIndex = users.indexWhere((u) => u.id == userId);
    
    if (userIndex == -1) {
      throw Exception('사용자를 찾을 수 없습니다.');
    }

    users[userIndex] = users[userIndex].copyWith(isPM: true);
    await _saveUsers(users);
    
    // 현재 로그인한 사용자가 변경된 경우 현재 사용자 정보도 업데이트
    final prefs = await SharedPreferences.getInstance();
    final currentUserJson = prefs.getString(_currentUserKey);
    if (currentUserJson != null) {
      final currentUser = User.fromJson(jsonDecode(currentUserJson));
      if (currentUser.id == userId) {
        await prefs.setString(_currentUserKey, jsonEncode(users[userIndex].toJson()));
      }
    }
  }

  /// PM 권한 제거
  /// 
  /// 관리자가 사용자의 PM 권한을 제거합니다.
  Future<void> revokePMPermission(String userId) async {
    final users = await getAllUsers();
    final userIndex = users.indexWhere((u) => u.id == userId);
    
    if (userIndex == -1) {
      throw Exception('사용자를 찾을 수 없습니다.');
    }

    users[userIndex] = users[userIndex].copyWith(isPM: false);
    await _saveUsers(users);
    
    // 현재 로그인한 사용자가 변경된 경우 현재 사용자 정보도 업데이트
    final prefs = await SharedPreferences.getInstance();
    final currentUserJson = prefs.getString(_currentUserKey);
    if (currentUserJson != null) {
      final currentUser = User.fromJson(jsonDecode(currentUserJson));
      if (currentUser.id == userId) {
        await prefs.setString(_currentUserKey, jsonEncode(users[userIndex].toJson()));
      }
    }
  }

  /// 초기 관리자 계정 생성
  /// 
  /// 앱을 처음 실행할 때 관리자 계정이 없으면 생성합니다.
  Future<void> initializeAdmin() async {
    final users = await getAllUsers();
    
    // 관리자가 없으면 생성
    if (users.isEmpty || !users.any((u) => u.isAdmin)) {
      final admin = User(
        id: _generateId(),
        username: 'admin',
        email: 'admin@dora.com',
        passwordHash: _hashPassword('admin123'), // 기본 비밀번호
        isAdmin: true,
        isApproved: true,
        createdAt: DateTime.now(),
      );

      users.add(admin);
      await _saveUsers(users);
    }
  }
}

