import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/api_client.dart';

/// 이미지 업로드 서비스 (웹/데스크톱 공통 - dart:io 미사용)
class UploadService {
  /// 바이트로 이미지 업로드 (웹·데스크톱 모두 동작)
  Future<String> uploadImageBytes(Uint8List bytes, String fileName) async {
    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/api/uploads/image');
      final token = await ApiClient.getToken();

      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final responseBody = response.body;

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        return data['url'] as String;
      } else {
        throw Exception('HTTP ${response.statusCode}: $responseBody');
      }
    } catch (e) {
      throw Exception('이미지 업로드 실패: $e');
    }
  }

  /// XFile로 이미지 업로드 (피커 선택 시 웹·모바일·데스크톱 공통)
  Future<String> uploadImageFromXFile(XFile xfile) async {
    final bytes = await xfile.readAsBytes();
    final name = xfile.name;
    return uploadImageBytes(bytes, name);
  }

  /// XFile 리스트 일괄 업로드
  Future<List<String>> uploadImagesFromXFiles(List<XFile> xfiles) async {
    final urls = <String>[];
    for (final xfile in xfiles) {
      final url = await uploadImageFromXFile(xfile);
      urls.add(url);
    }
    return urls;
  }

  /// 일반 파일 업로드 (바이트 기반)
  Future<Map<String, dynamic>> uploadFileBytes(Uint8List bytes, String fileName) async {
    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/api/uploads/file');
      final token = await ApiClient.getToken();

      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('파일 업로드 실패: $e');
    }
  }
}
