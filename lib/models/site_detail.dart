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
