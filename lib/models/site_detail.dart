class ServerInfo {
  String ip;
  String username;
  String password;
  String gpu;
  String mount;
  String note;

  ServerInfo({
    this.ip = '',
    this.username = '',
    this.password = '',
    this.gpu = '',
    this.mount = '',
    this.note = '',
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        ip: (json['ip'] ?? '') as String,
        username:
            (json['username'] ?? json['id'] ?? json['ID'] ?? '') as String,
        password: (json['password'] ??
            json['passwd'] ??
            json['PASSWD'] ??
            '') as String,
        gpu: (json['gpu'] ?? json['GPU'] ?? '') as String,
        mount: (json['mount'] ?? '') as String,
        note: (json['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'username': username,
        'password': password,
        'gpu': gpu,
        'mount': mount,
        'note': note,
      };

  ServerInfo copyWith({
    String? ip,
    String? username,
    String? password,
    String? gpu,
    String? mount,
    String? note,
  }) =>
      ServerInfo(
        ip: ip ?? this.ip,
        username: username ?? this.username,
        password: password ?? this.password,
        gpu: gpu ?? this.gpu,
        mount: mount ?? this.mount,
        note: note ?? this.note,
      );
}

/// 역할별 서버 그룹 (예: AI서버, 웹서버, DB서버)
class ServerRole {
  String roleName;
  List<ServerInfo> servers;

  ServerRole({
    this.roleName = '',
    List<ServerInfo>? servers,
  }) : servers = servers ?? [];

  factory ServerRole.fromJson(Map<String, dynamic> json) => ServerRole(
        roleName: (json['roleName'] ?? json['role_name'] ?? '') as String,
        servers: ((json['servers'] as List?) ?? [])
            .map((e) => ServerInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'roleName': roleName,
        'servers': servers.map((s) => s.toJson()).toList(),
      };

  ServerRole copyWith({String? roleName, List<ServerInfo>? servers}) =>
      ServerRole(
        roleName: roleName ?? this.roleName,
        servers: servers ?? this.servers,
      );
}

class DatabaseInfo {
  String name;
  String type;
  String user;
  String password;
  String ip;
  String port;
  String note;

  DatabaseInfo({
    this.name = '',
    this.type = '',
    this.user = '',
    this.password = '',
    this.ip = '',
    this.port = '',
    this.note = '',
  });

  factory DatabaseInfo.fromJson(Map<String, dynamic> json) => DatabaseInfo(
        name: (json['name'] ?? json['db_name'] ?? '') as String,
        type: (json['type'] ?? '') as String,
        user: (json['user'] ?? '') as String,
        password: (json['password'] ?? json['pass_word'] ?? '') as String,
        ip: (json['ip'] ?? '') as String,
        port: (json['port'] ?? '') as String,
        note: (json['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'user': user,
        'password': password,
        'ip': ip,
        'port': port,
        'note': note,
      };

  DatabaseInfo copyWith({
    String? name,
    String? type,
    String? user,
    String? password,
    String? ip,
    String? port,
    String? note,
  }) =>
      DatabaseInfo(
        name: name ?? this.name,
        type: type ?? this.type,
        user: user ?? this.user,
        password: password ?? this.password,
        ip: ip ?? this.ip,
        port: port ?? this.port,
        note: note ?? this.note,
      );
}

class ServiceInfo {
  String name;
  String version;
  /// 배포 호스트 IP (예: 10.158.108.111)
  String serverIp;
  String workers;
  String gpuUsage;
  String note;

  ServiceInfo({
    this.name = '',
    this.version = '',
    this.serverIp = '',
    this.workers = '',
    this.gpuUsage = '',
    this.note = '',
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> json) => ServiceInfo(
        name: (json['name'] ?? '') as String,
        version: (json['version'] ?? '') as String,
        serverIp: (json['serverIp'] ?? json['server_ip'] ?? '') as String,
        workers: (json['workers'] ?? '') as String,
        gpuUsage: (json['gpuUsage'] ?? json['gpu_usage'] ?? '') as String,
        note: (json['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'serverIp': serverIp,
        'workers': workers,
        'gpuUsage': gpuUsage,
        'note': note,
      };

  ServiceInfo copyWith({
    String? name,
    String? version,
    String? serverIp,
    String? workers,
    String? gpuUsage,
    String? note,
  }) =>
      ServiceInfo(
        name: name ?? this.name,
        version: version ?? this.version,
        serverIp: serverIp ?? this.serverIp,
        workers: workers ?? this.workers,
        gpuUsage: gpuUsage ?? this.gpuUsage,
        note: note ?? this.note,
      );
}

class SiteDetail {
  final String id;
  final List<String> projectIds;
  final String name;
  final String description;
  final List<ServerRole> serverRoles;
  final List<DatabaseInfo> databases;
  final List<ServiceInfo> services;
  final DateTime createdAt;
  final DateTime updatedAt;

  SiteDetail({
    required this.id,
    required this.projectIds,
    required this.name,
    required this.description,
    required this.serverRoles,
    required this.databases,
    required this.services,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 모든 역할의 서버 IP 목록 (서비스 섹션용)
  List<ServerInfo> get allServers =>
      serverRoles.expand((r) => r.servers).toList();

  factory SiteDetail.fromJson(Map<String, dynamic> json) {
    List<ServerRole> parseServerRoles(dynamic raw) {
      if (raw == null) return [];
      final list = raw as List;
      if (list.isEmpty) return [];
      final first = list.first as Map<String, dynamic>;
      // 새 형식: roleName 키가 있으면 ServerRole 배열
      if (first.containsKey('roleName') || first.containsKey('role_name')) {
        return list
            .map((e) => ServerRole.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      // 구 형식: ServerInfo 배열 → 기본 역할 "AI서버"로 래핑
      final servers = list
          .map((e) => ServerInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      return [ServerRole(roleName: 'AI서버', servers: servers)];
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
      serverRoles: parseServerRoles(json['servers']),
      databases: parseDatabases(json['databases']),
      services: parseServices(json['services']),
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt']),
    );
  }
}
