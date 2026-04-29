import 'dart:typed_data';

import 'clipboard_image_stub.dart'
    if (dart.library.html) 'clipboard_image_web.dart'
    if (dart.library.io) 'clipboard_image_io.dart' as impl;

/// 플랫폼별 클립보드 이미지 읽기.
/// - Web: navigator.clipboard.read() 사용
/// - 네이티브: 별도 MethodChannel (현재 Windows 만 지원, 호출부에서 처리)
Future<Uint8List?> readClipboardImageBytes() => impl.readClipboardImageBytes();
