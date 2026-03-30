class Patch {
  final String id;
  final String projectId;
  final String site;
  final DateTime patchDate; // date-only (00:00 local)
  final String version;
  final String content;

  Patch({
    required this.id,
    required this.projectId,
    required this.site,
    required this.patchDate,
    required this.version,
    required this.content,
  });

  factory Patch.fromJson(Map<String, dynamic> json) {
    final dateStr = (json['patch_date'] ?? json['patchDate']) as String;
    // API는 YYYY-MM-DD
    final parts = dateStr.split('-');
    final dt = parts.length == 3
        ? DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          )
        : DateTime.parse(dateStr);

    return Patch(
      id: json['id'] as String,
      projectId: (json['project_id'] ?? json['projectId']) as String,
      site: (json['site'] ?? '') as String,
      patchDate: dt,
      version: (json['version'] ?? '') as String,
      content: (json['content'] ?? '') as String,
    );
  }

  String get dateDisplay =>
      '${patchDate.year}.${patchDate.month}.${patchDate.day}';
}

