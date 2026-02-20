import '../utils/date_utils.dart';

/// 워크스페이스 모델
class Workspace {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final String inviteToken;
  final int memberCount;
  final DateTime createdAt;

  Workspace({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.inviteToken,
    this.memberCount = 0,
    required this.createdAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    final ownerIdKey = json.containsKey('owner_id') ? 'owner_id' : 'ownerId';
    final inviteTokenKey = json.containsKey('invite_token') ? 'invite_token' : 'inviteToken';
    final memberCountKey = json.containsKey('member_count') ? 'member_count' : 'memberCount';
    final createdAtKey = json.containsKey('created_at') ? 'created_at' : 'createdAt';

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return parseUtcToLocalOrNull(v) ?? DateTime.now();
      return DateTime.now();
    }

    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      ownerId: json[ownerIdKey] as String,
      inviteToken: json[inviteTokenKey] as String,
      memberCount: (json[memberCountKey] as num?)?.toInt() ?? 0,
      createdAt: parseDate(json[createdAtKey]),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'ownerId': ownerId,
        'inviteToken': inviteToken,
        'memberCount': memberCount,
        'createdAt': createdAt.toIso8601String(),
      };

  Workspace copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    String? inviteToken,
    int? memberCount,
    DateTime? createdAt,
  }) =>
      Workspace(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        ownerId: ownerId ?? this.ownerId,
        inviteToken: inviteToken ?? this.inviteToken,
        memberCount: memberCount ?? this.memberCount,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// 워크스페이스 멤버 모델
class WorkspaceMember {
  final String userId;
  final String username;
  final String? profileImageUrl;
  final String role; // "owner" | "member"
  final DateTime joinedAt;

  WorkspaceMember({
    required this.userId,
    required this.username,
    this.profileImageUrl,
    required this.role,
    required this.joinedAt,
  });

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    final userIdKey = json.containsKey('user_id') ? 'user_id' : 'userId';
    final profileKey = json.containsKey('profile_image_url') ? 'profile_image_url' : 'profileImageUrl';
    final joinedAtKey = json.containsKey('joined_at') ? 'joined_at' : 'joinedAt';

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return parseUtcToLocalOrNull(v) ?? DateTime.now();
      return DateTime.now();
    }

    return WorkspaceMember(
      userId: json[userIdKey] as String,
      username: json['username'] as String,
      profileImageUrl: json[profileKey] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: parseDate(json[joinedAtKey]),
    );
  }

  bool get isOwner => role == 'owner';
}
