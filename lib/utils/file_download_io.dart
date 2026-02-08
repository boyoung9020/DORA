import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// 데스크톱/모바일: 저장 대화상자 후 파일로 저장
Future<bool> saveFileFromBytes(List<int> bytes, String suggestedFileName) async {
  final ext = suggestedFileName.contains('.')
      ? suggestedFileName.split('.').last.toLowerCase()
      : '';
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: '파일 저장',
    fileName: suggestedFileName,
    type: ext.isNotEmpty ? FileType.custom : FileType.any,
    allowedExtensions: ext.isNotEmpty ? [ext] : null,
  );
  if (savePath == null) return false;
  final file = File(savePath);
  await file.writeAsBytes(bytes);
  return true;
}
