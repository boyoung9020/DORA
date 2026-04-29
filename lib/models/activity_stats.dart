// 워크스페이스 활동 히트맵 DTO.
// 백엔드의 작업 카드 단위 (distinct task id) 활동 집계 응답과 매핑한다.

class HeatmapDailyEntry {
  final DateTime date;
  final int count;

  const HeatmapDailyEntry({required this.date, required this.count});

  factory HeatmapDailyEntry.fromJson(Map<String, dynamic> json) {
    return HeatmapDailyEntry(
      date: DateTime.parse(json['date'] as String),
      count: (json['count'] as num).toInt(),
    );
  }
}

class HeatmapMember {
  final String userId;
  final String username;
  final String? profileImageUrl;
  final int total;
  final List<HeatmapDailyEntry> daily;

  const HeatmapMember({
    required this.userId,
    required this.username,
    required this.profileImageUrl,
    required this.total,
    required this.daily,
  });

  factory HeatmapMember.fromJson(Map<String, dynamic> json) {
    final daily = (json['daily'] as List<dynamic>? ?? [])
        .map((e) => HeatmapDailyEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return HeatmapMember(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      total: (json['total'] as num? ?? 0).toInt(),
      daily: daily,
    );
  }
}

class ActivityHeatmap {
  final DateTime fromDate;
  final DateTime toDate;
  final int weeks;
  final List<HeatmapMember> members;

  const ActivityHeatmap({
    required this.fromDate,
    required this.toDate,
    required this.weeks,
    required this.members,
  });

  factory ActivityHeatmap.fromJson(Map<String, dynamic> json) {
    return ActivityHeatmap(
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      weeks: (json['weeks'] as num? ?? 12).toInt(),
      members: (json['members'] as List<dynamic>? ?? [])
          .map((e) => HeatmapMember.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

