import 'dart:html' as html;

/// 웹: Blob + anchor download으로 브라우저 다운로드
Future<bool> saveFileFromBytes(List<int> bytes, String suggestedFileName) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = suggestedFileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
