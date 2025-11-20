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
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      passwordHash: json['passwordHash'] ?? '', // API 응답에는 비밀번호 해시가 포함되지 않을 수 있음
      isAdmin: json['isAdmin'] ?? false,
      isApproved: json['isApproved'] ?? false,
      isPM: json['isPM'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
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

