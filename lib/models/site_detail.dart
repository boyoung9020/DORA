class ServerInfo {
  String ip;
  String username;
  String note;

  ServerInfo({this.ip = '', this.username = '', this.note = ''});

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        ip: (json['ip'] ?? '') as String,
        username: (json['username'] ?? '') as String,
        note: (json['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'username': username,
        'note': note,
      };

  ServerInfo copyWith({String? ip, String? username, String? note}) =>
      ServerInfo(
        ip: ip ?? this.ip,
        username: username ?? this.username,
        note: note ?? this.note,
      );
}

class DatabaseInfo {
  String name;
  String type;
  String note;

  DatabaseInfo({this.name = '', this.type = '', this.note = ''});

  factory DatabaseInfo.fromJson(Map<String, dynamic> json) => DatabaseInfo(
        name: (json['name'] ?? '') as String,
        type: (json['type'] ?? '') as String,
        note: (json['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'note': note,
      };

  DatabaseInfo copyWith({String? name, String? type, String? note}) =>
      DatabaseInfo(
        name: name ?? this.name,
        type: type ?? this.type,
        note: note ?? this.note,
      );
}

class ServiceInfo {
  String name;
  String version;
  String note;

  ServiceInfo({this.name = '', this.version = '', this.note = ''});

  factory ServiceInfo.fromJson(Map<String, dynamic> json) => ServiceInfo(
        name: (json['name'] ?? '') as String,
        version: (json['version'] ?? '') as String,
        note: (json['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'note': note,
      };

  ServiceInfo copyWith({String? name, String? version, String? note}) =>
      ServiceInfo(
        name: name ?? this.name,
        version: version ?? this.version,
        note: note ?? this.note,
      );
}

class SiteDetail {
  final String id;
  final List<String> projectIds;
  final String name;
  final String description;
  final List<ServerInfo> servers;
  final List<DatabaseInfo> databases;
  final List<ServiceInfo> services;
  final DateTime createdAt;
  final DateTime updatedAt;

  SiteDetail({
    required this.id,
    required this.projectIds,
    required this.name,
    required this.description,
    required this.servers,
    required this.databases,
    required this.services,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteDetail.fromJson(Map<String, dynamic> json) {
    List<ServerInfo> parseServers(dynamic raw) {
      if (raw == null) return [];
      return (raw as List)
          .map((e) => ServerInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<DatabaseInfo> parseDatabases(dynamic raw) {
      if (raw == null) return [];
      return (raw as List)
          .map((e) => DatabaseInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<ServiceInfo> parseServices(dynamic raw) {
      if (raw == null) return [];
      return (raw as List)
          .map((e) => ServiceInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // project_ids (새 필드) 또는 project_id (구 필드) 모두 지원
    List<String> parseProjectIds(dynamic raw, dynamic fallback) {
      if (raw != null && raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      if (fallback != null) return [fallback.toString()];
      return [];
    }

    return SiteDetail(
      id: json['id'] as String,
      projectIds: parseProjectIds(
        json['project_ids'] ?? json['projectIds'],
        json['project_id'] ?? json['projectId'],
      ),
      name: (json['name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      servers: parseServers(json['servers']),
      databases: parseDatabases(json['databases']),
      services: parseServices(json['services']),
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt']),
    );
  }
}
