part of 'postgrest_typed_builder.dart';

/// A time of day, the value of a Postgres `time` column, or with an [offset]
/// the value of a `timetz` column.
///
/// ```dart
/// PostgrestTime(hour: 9, minute: 30).literal                  // 09:30:00
/// PostgrestTime(hour: 9, offset: Duration(hours: 2)).literal  // 09:00:00+02
/// PostgrestTime.parse('04:05:06.789').microsecond             // 789000
/// ```
///
/// Postgres allows `24:00:00`, the end of the day, so [hour] goes up to 24
/// when every other component is zero.
///
/// Two times are equal when all their components are, including the
/// [offset]. [compareTo] orders them by the UTC instant of the day they name,
/// the way Postgres orders `timetz` values, so `09:00:00+01` sorts together
/// with `08:00:00+00` while not being equal to it.
@experimental
final class PostgrestTime implements Comparable<PostgrestTime> {
  /// The time [hour]:[minute]:[second].[microsecond], at the UTC [offset]
  /// for a `timetz` value.
  ///
  /// Throws an [ArgumentError] when a component is out of range or [offset]
  /// is not a whole number of seconds within the 15:59:59 Postgres accepts.
  PostgrestTime({
    required this.hour,
    this.minute = 0,
    this.second = 0,
    this.microsecond = 0,
    this.offset,
  }) {
    _checkRange(hour, 'hour', 0, 24);
    _checkRange(minute, 'minute', 0, 59);
    _checkRange(second, 'second', 0, 59);
    _checkRange(microsecond, 'microsecond', 0, 999999);
    if (hour == 24 && (minute != 0 || second != 0 || microsecond != 0)) {
      throw ArgumentError.value(hour, 'hour', '24:00:00 is the end of the day');
    }
    final offset = this.offset;
    if (offset != null) {
      if (offset.inMicroseconds % Duration.microsecondsPerSecond != 0) {
        throw ArgumentError.value(
          offset,
          'offset',
          'Must be a whole number of seconds',
        );
      }
      if (offset.abs() > _maxOffset) {
        throw ArgumentError.value(
          offset,
          'offset',
          'Must be within 15:59:59 of UTC',
        );
      }
    }
  }

  /// The time of day of [dateTime] in the timezone it carries, without an
  /// [offset].
  PostgrestTime.fromDateTime(DateTime dateTime)
    : this(
        hour: dateTime.hour,
        minute: dateTime.minute,
        second: dateTime.second,
        microsecond:
            dateTime.millisecond * Duration.microsecondsPerMillisecond +
            dateTime.microsecond,
      );

  /// Parses the literal Postgres emits for a `time` or `timetz` value:
  /// `HH:MM:SS`, with up to six fractional digits after the seconds and, for
  /// `timetz`, a UTC offset such as `+02`, `-08:30` or `+05:30:15`. The
  /// seconds may be left out on input.
  ///
  /// Throws a [FormatException] when [literal] is not a time.
  factory PostgrestTime.parse(String literal) {
    final match = _timePattern.firstMatch(literal.trim());
    if (match == null) throw FormatException('Not a time literal', literal);
    final fraction = match[4];
    final microsecond = fraction == null
        ? 0
        : int.parse(fraction.padRight(6, '0'));
    final offsetText = match[5];
    Duration? offset;
    if (offsetText != null) {
      final sign = offsetText[0] == '-' ? -1 : 1;
      final parts = offsetText.substring(1).split(':');
      offset =
          Duration(
            hours: int.parse(parts[0]),
            minutes: parts.length > 1 ? int.parse(parts[1]) : 0,
            seconds: parts.length > 2 ? int.parse(parts[2]) : 0,
          ) *
          sign;
    }
    try {
      return PostgrestTime(
        hour: int.parse(match[1]!),
        minute: int.parse(match[2]!),
        second: int.parse(match[3] ?? '0'),
        microsecond: microsecond,
        offset: offset,
      );
    } on ArgumentError {
      throw FormatException('Not a time literal', literal);
    }
  }

  static final _timePattern = RegExp(
    r'^(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?'
    r'([+-]\d{2}(?::\d{2}(?::\d{2})?)?)?$',
  );

  static const _maxOffset = Duration(hours: 15, minutes: 59, seconds: 59);

  /// The hour, 0 to 24.
  final int hour;

  /// The minute, 0 to 59.
  final int minute;

  /// The second, 0 to 59.
  final int second;

  /// The microsecond within the second, 0 to 999999.
  final int microsecond;

  /// The offset from UTC of a `timetz` value, `null` for a plain `time`.
  final Duration? offset;

  /// The literal Postgres accepts and emits: `09:30:00`, `04:05:06.789` or
  /// `09:30:00+02`.
  String get literal {
    final buffer = StringBuffer()
      ..write(_twoDigits(hour))
      ..write(':')
      ..write(_twoDigits(minute))
      ..write(':')
      ..write(_twoDigits(second));
    if (microsecond != 0) {
      buffer
        ..write('.')
        ..write(_trimZeros(microsecond.toString().padLeft(6, '0')));
    }
    final offset = this.offset;
    if (offset != null) {
      final total = offset.inSeconds.abs();
      final hours = total ~/ Duration.secondsPerHour;
      final minutes =
          total % Duration.secondsPerHour ~/ Duration.secondsPerMinute;
      final seconds = total % Duration.secondsPerMinute;
      buffer
        ..write(offset.isNegative ? '-' : '+')
        ..write(_twoDigits(hours));
      if (minutes != 0 || seconds != 0) {
        buffer
          ..write(':')
          ..write(_twoDigits(minutes));
      }
      if (seconds != 0) {
        buffer
          ..write(':')
          ..write(_twoDigits(seconds));
      }
    }
    return buffer.toString();
  }

  /// The microseconds since midnight UTC of the day, which is how Postgres
  /// orders `timetz` values.
  int get _utcMicroseconds =>
      hour * Duration.microsecondsPerHour +
      minute * Duration.microsecondsPerMinute +
      second * Duration.microsecondsPerSecond +
      microsecond -
      (offset?.inMicroseconds ?? 0);

  @override
  int compareTo(PostgrestTime other) =>
      _utcMicroseconds.compareTo(other._utcMicroseconds);

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgrestTime &&
      other.hour == hour &&
      other.minute == minute &&
      other.second == second &&
      other.microsecond == microsecond &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(hour, minute, second, microsecond, offset);

  static void _checkRange(int value, String name, int min, int max) {
    if (value < min || value > max) {
      throw ArgumentError.value(value, name, 'Must be between $min and $max');
    }
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Drops the trailing zeros of a fraction, so `789000` becomes `789`.
String _trimZeros(String fraction) => fraction.replaceFirst(RegExp(r'0+$'), '');
