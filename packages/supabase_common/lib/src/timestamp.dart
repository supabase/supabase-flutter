/// Parses the ISO 8601 timestamp stored under [key] in [json] as a UTC
/// [DateTime].
///
/// Throws a [FormatException] when the value is missing, is not a string, or
/// is not a valid ISO 8601 timestamp. For the `YYYY-MM-DD` and `YYYYMMDD`
/// forms the servers send, a month or day that is out of range is rejected
/// rather than carried over into the next month or year the way
/// [DateTime.parse] carries it.
///
/// The exception names the key and the offending value but does not carry
/// [json] itself, which holds the caller's payload and so may contain personal
/// data the caller would not expect in an error or a log.
DateTime parseIso8601(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException(
      'Expected $key to be a string, got ${value.runtimeType}',
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !_hasValidCalendarDate(value)) {
    throw FormatException('Invalid date format for $key: $value');
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
///
/// Only the `YYYY-MM-DD` and `YYYYMMDD` forms are checked. Anything else
/// [DateTime.tryParse] accepts, such as the expanded year form
/// `+002023-01-42`, keeps its carrying behaviour; no Supabase service sends
/// those.
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
/// As in [parseIso8601], the exception does not carry [json] itself.
DateTime parseUnixSeconds(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException(
      'Expected $key to be a number, got ${value.runtimeType}',
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

/// Parses the Unix timestamp in milliseconds stored under [key] in [json] as a
/// UTC [DateTime].
///
/// Throws a [FormatException] when the value is missing or is not a number.
/// As in [parseIso8601], the exception does not carry [json] itself.
DateTime parseUnixMilliseconds(Map<String, dynamic> json, String key) {
  return DateTime.fromMillisecondsSinceEpoch(
    _millisecondsUnder(json, key),
    isUtc: true,
  );
}

/// Same as [parseUnixMilliseconds], but returns `null` when the value under
/// [key] is `null` or absent.
DateTime? tryParseUnixMilliseconds(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return parseUnixMilliseconds(json, key);
}

/// Parses the duration in milliseconds stored under [key] in [json].
///
/// Throws a [FormatException] when the value is missing or is not a number.
/// As in [parseIso8601], the exception does not carry [json] itself.
Duration parseMillisecondsDuration(Map<String, dynamic> json, String key) {
  return Duration(milliseconds: _millisecondsUnder(json, key));
}

/// Same as [parseMillisecondsDuration], but returns `null` when the value under
/// [key] is `null` or absent.
Duration? tryParseMillisecondsDuration(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return parseMillisecondsDuration(json, key);
}

int _millisecondsUnder(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException(
      'Expected $key to be a number, got ${value.runtimeType}',
    );
  }
  return value.round();
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
