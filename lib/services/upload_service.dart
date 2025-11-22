import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/api_client.dart';

/// 이미지 업로드 서비스 클래스
class UploadService {
  /// 이미지 업로드
  Future<String> uploadImage(File imageFile) async {
    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/api/uploads/image');
      
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      
      final token = await ApiClient.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      
      // 파일 추가
      final file = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: imageFile.path.split('/').last,
        contentType: MediaType('image', imageFile.path.split('.').last),
      );
      request.files.add(file);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        final imageUrl = data['url'] as String;
        // 상대 경로를 절대 경로로 변환
        if (imageUrl.startsWith('/')) {
          return '${ApiClient.baseUrl}$imageUrl';
        }
        return imageUrl;
      } else {
        throw Exception('이미지 업로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('이미지 업로드 실패: $e');
    }
  }
  
  /// 여러 이미지 업로드
  Future<List<String>> uploadImages(List<File> imageFiles) async {
    final List<String> urls = [];
    for (final file in imageFiles) {
      final url = await uploadImage(file);
      urls.add(url);
    }
    return urls;
  }
}

