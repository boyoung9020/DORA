class ProjectSite {
  final String id;
  final String projectId;
  final String name;

  ProjectSite({
    required this.id,
    required this.projectId,
    required this.name,
  });

  factory ProjectSite.fromJson(Map<String, dynamic> json) {
    return ProjectSite(
      id: json['id'] as String,
      projectId: (json['project_id'] ?? json['projectId']) as String,
      name: (json['name'] ?? '') as String,
    );
  }
}

