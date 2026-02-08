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
