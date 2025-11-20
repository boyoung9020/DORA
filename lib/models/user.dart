/// 사용자 모델 클래스
/// 
/// 이 클래스는 사용자 정보를 담는 데이터 모델입니다.
/// - id: 고유 식별자
/// - username: 사용자 이름 (로그인 ID)
/// - email: 이메일
/// - passwordHash: 해싱된 비밀번호
/// - isAdmin: 관리자 여부
/// - isApproved: 관리자 승인 여부
/// - isPM: 프로젝트 매니저 권한 여부
/// - createdAt: 생성 시간
class User {
  final String id;
  final String username;
  final String email;
  final String passwordHash;
  final bool isAdmin;
  final bool isApproved;
  final bool isPM;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.isAdmin = false,
    this.isApproved = false,
    this.isPM = false,
    required this.createdAt,
  });

  /// JSON으로 변환 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'passwordHash': passwordHash,
      'isAdmin': isAdmin,
      'isApproved': isApproved,
      'isPM': isPM,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// JSON에서 User 객체 생성
  factory User.fromJson(Map<String, dynamic> json) {
    // API는 snake_case를 사용하지만 Flutter는 camelCase를 사용
    // 두 가지 형식 모두 지원
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';
    final isAdminKey = json.containsKey('is_admin') ? 'is_admin' : 'isAdmin';
    final isApprovedKey = json.containsKey('is_approved') ? 'is_approved' : 'isApproved';
    final isPMKey = json.containsKey('is_pm') ? 'is_pm' : 'isPM';
    
    // 날짜 파싱 (ISO 8601 형식 또는 다른 형식 지원)
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) {
        return DateTime.now();
      }
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          // ISO 8601 형식이 아닌 경우 시도
          try {
            // "2025-11-20T04:30:00.123456+00:00" 형식 처리
            return DateTime.parse(dateValue.replaceAll(' ', 'T'));
          } catch (e2) {
            print('[User.fromJson] 날짜 파싱 실패: $dateValue, 오류: $e2');
            return DateTime.now();
          }
        }
      }
      return DateTime.now();
    }
    
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      passwordHash: json['passwordHash'] ?? json['password_hash'] ?? '', // API 응답에는 비밀번호 해시가 포함되지 않을 수 있음
      isAdmin: json[isAdminKey] ?? false,
      isApproved: json[isApprovedKey] ?? false,
      isPM: json[isPMKey] ?? false,
      createdAt: parseDate(json[createdAtKey]),
    );
  }

  /// 승인된 사용자 복사본 생성
  User copyWith({
    String? id,
    String? username,
    String? email,
    String? passwordHash,
    bool? isAdmin,
    bool? isApproved,
    bool? isPM,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      isAdmin: isAdmin ?? this.isAdmin,
      isApproved: isApproved ?? this.isApproved,
      isPM: isPM ?? this.isPM,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

