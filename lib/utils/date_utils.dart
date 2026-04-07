/// UTC 날짜 문자열을 로컬 DateTime으로 변환
DateTime parseUtcToLocal(String dateString) {
  DateTime dt = DateTime.parse(dateString);
  // 서버는 UTC 반환. timezone 정보 없으면 UTC로 간주
  if (!dt.isUtc && !dateString.endsWith('Z') && !dateString.contains('+')) {
    dt = DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
  }
  return dt.toLocal();
}

/// nullable 버전
DateTime? parseUtcToLocalOrNull(String? dateString) {
  if (dateString == null || dateString.isEmpty) return null;
  try {
    return parseUtcToLocal(dateString);
  } catch (_) {
    return null;
  }
}

/// 날짜 전용 파싱 (시간대 변환 없이 yyyy-MM-dd 그대로 읽음)
/// start_date / end_date 처럼 시간 의미 없는 날짜에 사용
DateTime? parseDateOnly(String? dateString) {
  if (dateString == null || dateString.isEmpty) return null;
  try {
    // "2026-04-09" 또는 "2026-04-09T..." 형식 모두 처리
    final s = dateString.length >= 10 ? dateString.substring(0, 10) : dateString;
    final parts = s.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  } catch (_) {
    return null;
  }
}

/// DateTime을 날짜 전용 문자열로 직렬화 (yyyy-MM-ddT00:00:00)
/// 백엔드 datetime 필드가 날짜만 있는 문자열을 거부하므로 시간 부분을 포함시킨다.
String? formatDateOnly(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-${d}T00:00:00';
}
