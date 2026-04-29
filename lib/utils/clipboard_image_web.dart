import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// 브라우저 navigator.clipboard.read() 로 클립보드 첫 이미지를 바이트로 반환.
/// 사용자 제스처(Ctrl+V) 컨텍스트에서 호출되어야 권한이 허용됨.
/// 권한 거부, 미지원, 이미지 없음 → null.
Future<Uint8List?> readClipboardImageBytes() async {
  try {
    final clipboard = web.window.navigator.clipboard;
    final itemsJs = await clipboard.read().toDart;
    final items = itemsJs.toDart;
    for (final item in items) {
      final types = item.types.toDart;
      for (final t in types) {
        final mime = t.toDart;
        if (mime.startsWith('image/')) {
          final blob = await item.getType(mime).toDart;
          final bufferJs = await blob.arrayBuffer().toDart;
          return bufferJs.toDart.asUint8List();
        }
      }
    }
  } catch (_) {
    // 권한 거부 / 브라우저 미지원 → null
  }
  return null;
}
