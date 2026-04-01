class CheckItem {
  final String text;
  final bool checked;

  const CheckItem({required this.text, required this.checked});

  factory CheckItem.fromJson(Map<String, dynamic> json) => CheckItem(
        text: (json['text'] ?? '') as String,
        checked: (json['checked'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {'text': text, 'checked': checked};

  CheckItem copyWith({String? text, bool? checked}) =>
      CheckItem(text: text ?? this.text, checked: checked ?? this.checked);
}

class Patch {
  final String id;
  final String projectId;
  final String site;
  final DateTime patchDate;
  final String version;
  final String content;
  final List<CheckItem> steps;
  final List<CheckItem> testItems;
  final String status; // pending | in_progress | done
  final String notes;
  final List<String> noteImageUrls;

  Patch({
    required this.id,
    required this.projectId,
    required this.site,
    required this.patchDate,
    required this.version,
    required this.content,
    required this.steps,
    required this.testItems,
    required this.status,
    this.notes = '',
    List<String>? noteImageUrls,
  }) : noteImageUrls = noteImageUrls ?? [];

  factory Patch.fromJson(Map<String, dynamic> json) {
    final dateStr = (json['patch_date'] ?? json['patchDate']) as String;
    final parts = dateStr.split('-');
    final dt = parts.length == 3
        ? DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          )
        : DateTime.parse(dateStr);

    List<CheckItem> parseItems(dynamic raw) {
      if (raw == null) return [];
      return (raw as List)
          .map((e) => CheckItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Patch(
      id: json['id'] as String,
      projectId: (json['project_id'] ?? json['projectId']) as String,
      site: (json['site'] ?? '') as String,
      patchDate: dt,
      version: (json['version'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      steps: parseItems(json['steps']),
      testItems: parseItems(json['test_items'] ?? json['testItems']),
      status: (json['status'] ?? 'pending') as String,
      notes: (json['notes'] ?? '') as String,
      noteImageUrls: json['note_image_urls'] != null
          ? List<String>.from(json['note_image_urls'])
          : [],
    );
  }

  String get dateDisplay =>
      '${patchDate.year}.${patchDate.month.toString().padLeft(2, '0')}.${patchDate.day.toString().padLeft(2, '0')}';

  int get totalItems => steps.length + testItems.length;
  int get checkedItems =>
      steps.where((e) => e.checked).length +
      testItems.where((e) => e.checked).length;

  static String computeStatus(
      List<CheckItem> steps, List<CheckItem> testItems) {
    final all = [...steps, ...testItems];
    if (all.isEmpty) return 'pending';
    final checked = all.where((e) => e.checked).length;
    if (checked == 0) return 'pending';
    if (checked == all.length) return 'done';
    return 'in_progress';
  }

  Patch copyWith({
    String? site,
    DateTime? patchDate,
    String? version,
    String? content,
    List<CheckItem>? steps,
    List<CheckItem>? testItems,
    String? status,
    String? notes,
    List<String>? noteImageUrls,
  }) =>
      Patch(
        id: id,
        projectId: projectId,
        site: site ?? this.site,
        patchDate: patchDate ?? this.patchDate,
        version: version ?? this.version,
        content: content ?? this.content,
        steps: steps ?? this.steps,
        testItems: testItems ?? this.testItems,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        noteImageUrls: noteImageUrls ?? this.noteImageUrls,
      );
}
