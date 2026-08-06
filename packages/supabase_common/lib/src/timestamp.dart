/// Parses the ISO 8601 timestamp stored under [key] in [json] as a UTC
/// [DateTime].
///
/// Throws a [FormatException] when the value is missing, is not a string, or
/// is not a valid ISO 8601 timestamp. Unlike [DateTime.parse], a date whose
/// month or day is out of range is rejected rather than carried over into the
/// next month or year.
DateTime parseIso8601(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException(
      'Expected $key to be a string, got ${value.runtimeType}',
      json.toString(),
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !_hasValidCalendarDate(value)) {
    throw FormatException(
      'Invalid date format for $key: $value',
      json.toString(),
    );
  }
  return parsed.toUtc();
}

final _calendarDatePattern = RegExp(
  r'^(?:(\d{4})-(\d{2})-(\d{2})|(\d{4})(\d{2})(\d{2}))',
);

/// Whether the calendar date at the start of [value] is a real date.
///
/// [DateTime.tryParse] carries out-of-range components over into the next
/// larger one instead of rejecting them, so `2020-01-42` parses as 2020-02-11
/// and `2019-02-29` as 2019-03-01. A timestamp that does not name a real date
/// is a malformed payload rather than a timestamp days later.
bool _hasValidCalendarDate(String value) {
  final match = _calendarDatePattern.firstMatch(value);
  if (match == null) return true;
  final year = int.parse(match[1] ?? match[4]!);
  final month = int.parse(match[2] ?? match[5]!);
  final day = int.parse(match[3] ?? match[6]!);
  final carried = DateTime.utc(year, month, day);
  return carried.month == month && carried.day == day;
}

/// Same as [parseIso8601], but returns `null` when the value under [key] is
/// `null` or absent.
DateTime? tryParseIso8601(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return parseIso8601(json, key);
}

/// Parses the Unix timestamp in seconds stored under [key] in [json] as a UTC
/// [DateTime].
///
/// Throws a [FormatException] when the value is missing or is not a number.
DateTime parseUnixSeconds(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException(
      'Expected $key to be a number, got ${value.runtimeType}',
      json.toString(),
    );
  }
  return dateTimeFromUnixSeconds(value);
}

/// Same as [parseUnixSeconds], but returns `null` when the value under [key] is
/// `null` or absent.
DateTime? tryParseUnixSeconds(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return parseUnixSeconds(json, key);
}

/// Converts a Unix timestamp in [seconds] to a UTC [DateTime].
DateTime dateTimeFromUnixSeconds(num seconds) {
  return DateTime.fromMillisecondsSinceEpoch(
    (seconds * 1000).round(),
    isUtc: true,
  );
}

/// The Unix timestamp of [dateTime] in whole seconds.
///
/// Sub-second precision is floored rather than truncated towards zero, so the
/// result stays the second that contains [dateTime] for instants before the
/// Unix epoch too.
int unixSecondsFromDateTime(DateTime dateTime) {
  return (dateTime.millisecondsSinceEpoch / 1000).floor();
}
