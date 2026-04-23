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

  Future<List<Patch>> getPatchesBySite({required String siteName}) async {
    final resp = await ApiClient.get(
      '/api/patches/',
      queryParams: {'site_name': siteName},
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
    String? assignee,
    String? gitTag,
  }) async {
    final dateStr = _dateStr(patchDate);
    final body = <String, dynamic>{
      'project_id': projectId,
      'site': site,
      'patch_date': dateStr,
      'version': version,
      'content': content,
    };
    if (assignee != null && assignee.isNotEmpty) body['assignee'] = assignee;
    if (gitTag != null && gitTag.isNotEmpty) body['git_tag'] = gitTag;
    final resp = await ApiClient.post('/api/patches/', body: body);
    final data = ApiClient.handleResponse(resp);
    return Patch.fromJson(data);
  }

  Future<Patch> updatePatch({
    required String patchId,
    String? site,
    DateTime? patchDate,
    String? version,
    String? content,
    List<CheckItem>? steps,
    List<CheckItem>? testItems,
    String? status,
    String? notes,
    List<String>? noteImageUrls,
    String? assignee,
  }) async {
    final body = <String, dynamic>{};
    if (site != null) body['site'] = site;
    if (patchDate != null) body['patch_date'] = _dateStr(patchDate);
    if (version != null) body['version'] = version;
    if (content != null) body['content'] = content;
    if (steps != null) body['steps'] = steps.map((e) => e.toJson()).toList();
    if (testItems != null) {
      body['test_items'] = testItems.map((e) => e.toJson()).toList();
    }
    if (status != null) body['status'] = status;
    if (notes != null) body['notes'] = notes;
    if (noteImageUrls != null) body['note_image_urls'] = noteImageUrls;
    if (assignee != null) body['assignee'] = assignee;

    final resp = await ApiClient.patch('/api/patches/$patchId', body: body);
    final data = ApiClient.handleResponse(resp);
    return Patch.fromJson(data);
  }

  Future<void> deletePatch({required String patchId}) async {
    await ApiClient.delete('/api/patches/$patchId');
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
