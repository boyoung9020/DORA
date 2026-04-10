import '../models/site_detail.dart';
import '../utils/api_client.dart';

class SiteDetailService {
  Future<List<SiteDetail>> listSites({String? projectId}) async {
    final resp = await ApiClient.get(
      '/api/site-details/',
      queryParams: projectId != null ? {'project_id': projectId} : {},
    );
    final data = ApiClient.handleListResponse(resp);
    return data
        .map((e) => SiteDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SiteDetail> createSite({
    required String projectId,
    required String name,
    String description = '',
    List<ServerRole>? serverRoles,
    List<DatabaseInfo>? databases,
    List<ServiceInfo>? services,
  }) async {
    final resp = await ApiClient.post(
      '/api/site-details/',
      body: {
        'project_id': projectId,
        'name': name,
        'description': description,
        'servers': (serverRoles ?? []).map((e) => e.toJson()).toList(),
        'databases': (databases ?? []).map((e) => e.toJson()).toList(),
        'services': (services ?? []).map((e) => e.toJson()).toList(),
      },
    );
    final data = ApiClient.handleResponse(resp);
    return SiteDetail.fromJson(data);
  }

  Future<SiteDetail> updateSite({
    required String siteId,
    String? name,
    String? description,
    List<ServerRole>? serverRoles,
    List<DatabaseInfo>? databases,
    List<ServiceInfo>? services,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (serverRoles != null) body['servers'] = serverRoles.map((e) => e.toJson()).toList();
    if (databases != null) body['databases'] = databases.map((e) => e.toJson()).toList();
    if (services != null) body['services'] = services.map((e) => e.toJson()).toList();

    final resp = await ApiClient.patch('/api/site-details/$siteId', body: body);
    final data = ApiClient.handleResponse(resp);
    return SiteDetail.fromJson(data);
  }

  Future<void> deleteSite({required String siteId}) async {
    await ApiClient.delete('/api/site-details/$siteId');
  }
}
