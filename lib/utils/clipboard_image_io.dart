import 'dart:typed_data';

/// 네이티브 플랫폼: 별도 MethodChannel 로 처리하므로 여기서는 null.
/// (Windows 데스크톱은 task_detail_screen 의 `com.sync/clipboard` 채널 사용)
Future<Uint8List?> readClipboardImageBytes() async => null;
