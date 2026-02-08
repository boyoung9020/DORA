import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    if (dart.library.io) 'file_download_io.dart' as impl;

/// 플랫폼별 파일 저장: 웹은 브라우저 다운로드, 데스크톱/모바일은 저장 대화상자
Future<bool> saveFileFromBytes(List<int> bytes, String suggestedFileName) =>
    impl.saveFileFromBytes(bytes, suggestedFileName);
