import '../models/project_site.dart';
import '../utils/api_client.dart';

class ProjectSiteService {
  Future<List<ProjectSite>> listSites({required String projectId}) async {
    final resp = await ApiClient.get(
      '/api/project-sites/',
      queryParams: {'project_id': projectId},
    );
    final data = ApiClient.handleListResponse(resp);
    return data
        .map((e) => ProjectSite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectSite> createSite({
    required String projectId,
    required String name,
  }) async {
    final resp = await ApiClient.post(
      '/api/project-sites/',
      body: {'project_id': projectId, 'name': name},
    );
    final data = ApiClient.handleResponse(resp);
    return ProjectSite.fromJson(data);
  }

  Future<void> deleteSite({required String siteId, String? projectId}) async {
    final qp = <String, String>{};
    if (projectId != null && projectId.isNotEmpty) {
      qp['project_id'] = projectId;
    }
    final resp = await ApiClient.delete(
      '/api/project-sites/$siteId',
      queryParams: qp.isEmpty ? null : qp,
    );
    ApiClient.handleResponse(resp);
  }
}

