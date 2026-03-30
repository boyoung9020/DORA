import '../models/patch.dart';
import '../utils/api_client.dart';

class PatchService {
  Future<List<Patch>> getPatches({required String projectId}) async {
    final resp = await ApiClient.get(
      '/api/patches/',
      queryParams: {'project_id': projectId},
    );
    final data = ApiClient.handleListResponse(resp);
    return data.map((e) => Patch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Patch> createPatch({
    required String projectId,
    required String site,
    required DateTime patchDate,
    required String version,
    required String content,
  }) async {
    final dateStr =
        '${patchDate.year.toString().padLeft(4, '0')}-${patchDate.month.toString().padLeft(2, '0')}-${patchDate.day.toString().padLeft(2, '0')}';
    final resp = await ApiClient.post(
      '/api/patches/',
      body: {
        'project_id': projectId,
        'site': site,
        'patch_date': dateStr,
        'version': version,
        'content': content,
      },
    );
    final data = ApiClient.handleResponse(resp);
    return Patch.fromJson(data);
  }
}

