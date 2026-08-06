/// Parses the ISO 8601 timestamp stored under [key] in [json] as a UTC
/// [DateTime].
///
/// Throws a [FormatException] when the value is missing, is not a string, or
/// is not a valid ISO 8601 timestamp.
DateTime parseIso8601(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException(
      'Expected $key to be a string, got ${value.runtimeType}',
      json.toString(),
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException(
      'Invalid date format for $key: $value',
      json.toString(),
    );
  }
  return parsed.toUtc();
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

/// The number of whole seconds between [dateTime] and the Unix epoch.
int unixSecondsFromDateTime(DateTime dateTime) {
  return dateTime.millisecondsSinceEpoch ~/ 1000;
}
