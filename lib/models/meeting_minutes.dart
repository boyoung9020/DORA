import '../utils/date_utils.dart';

/// 회의록 모델
class MeetingMinutes {
  final String id;
  final String workspaceId;
  final String title;
  final String content;
  final String category;
  final DateTime meetingDate;
  final String creatorId;
  final List<String> attendeeIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  MeetingMinutes({
    required this.id,
    required this.workspaceId,
    required this.title,
    this.content = '',
    this.category = '',
    required this.meetingDate,
    required this.creatorId,
    this.attendeeIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory MeetingMinutes.fromJson(Map<String, dynamic> json) {
    List<String> attendeeIds = [];
    final key = json.containsKey('attendee_ids') ? 'attendee_ids' : 'attendeeIds';
    if (json[key] != null && json[key] is List) {
      attendeeIds = (json[key] as List).map((e) => e.toString()).toList();
    }

    return MeetingMinutes(
      id: json['id'] ?? '',
      workspaceId: json['workspace_id'] ?? json['workspaceId'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? '',
      meetingDate: json['meeting_date'] != null || json['meetingDate'] != null
          ? DateTime.parse(json['meeting_date'] ?? json['meetingDate'])
          : DateTime.now(),
      creatorId: json['creator_id'] ?? json['creatorId'] ?? '',
      attendeeIds: attendeeIds,
      createdAt: json['created_at'] != null
          ? parseUtcToLocal(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? parseUtcToLocal(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'title': title,
      'content': content,
      'category': category,
      'meeting_date': meetingDate.toIso8601String().split('T').first,
      'creator_id': creatorId,
      'attendee_ids': attendeeIds,
    };
  }

  MeetingMinutes copyWith({
    String? title,
    String? content,
    String? category,
    DateTime? meetingDate,
    List<String>? attendeeIds,
  }) {
    return MeetingMinutes(
      id: id,
      workspaceId: workspaceId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      meetingDate: meetingDate ?? this.meetingDate,
      creatorId: creatorId,
      attendeeIds: attendeeIds ?? this.attendeeIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
