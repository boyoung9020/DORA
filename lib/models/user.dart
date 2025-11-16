/// 사용자 모델 클래스
/// 
/// 이 클래스는 사용자 정보를 담는 데이터 모델입니다.
/// - id: 고유 식별자
/// - username: 사용자 이름 (로그인 ID)
/// - email: 이메일
/// - passwordHash: 해싱된 비밀번호
/// - isAdmin: 관리자 여부
/// - isApproved: 관리자 승인 여부
/// - createdAt: 생성 시간
class User {
  final String id;
  final String username;
  final String email;
  final String passwordHash;
  final bool isAdmin;
  final bool isApproved;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.isAdmin = false,
    this.isApproved = false,
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
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// JSON에서 User 객체 생성
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      passwordHash: json['passwordHash'],
      isAdmin: json['isAdmin'] ?? false,
      isApproved: json['isApproved'] ?? false,
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
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      isAdmin: isAdmin ?? this.isAdmin,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

