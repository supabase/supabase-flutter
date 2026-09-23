part of 'postgrest_typed_builder.dart';

/// A Postgres `interval`: a span of [months], [days] and [microseconds] kept
/// apart, the way Postgres stores it.
///
/// A month is 28 to 31 days and a day is 23 to 25 hours across a daylight
/// saving change, so none of the three converts exactly into the others and
/// Postgres keeps them separate: `date '2024-01-31' + interval '1 month'` is
/// February 29 while `+ interval '30 days'` is March 1. A [Duration] cannot
/// hold that distinction, which is why an `interval` column is not one.
///
/// ```dart
/// const PostgrestInterval(years: 1, months: 2, days: 3, hours: 4).literal
/// // 1 year 2 mons 3 days 04:00:00
/// PostgrestInterval.parse('1 mon').toDuration()   // 30 days
/// PostgrestInterval.parse('P1Y2M3DT4H5M6S')       // the iso_8601 style
/// ```
///
/// [parse] reads every `IntervalStyle` Postgres can emit, `postgres`,
/// `postgres_verbose`, `sql_standard` and `iso_8601`; [literal] renders the
/// `postgres` style, which Postgres accepts whatever its `IntervalStyle` is.
@experimental
final class PostgrestInterval {
  /// The interval of the given components, folded into [months], [days] and
  /// [microseconds]: [years] count as 12 months, [weeks] as 7 days, and the
  /// time components add up into microseconds.
  const PostgrestInterval({
    int years = 0,
    int months = 0,
    int weeks = 0,
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    int milliseconds = 0,
    int microseconds = 0,
  }) : months = years * 12 + months,
       days = weeks * 7 + days,
       microseconds =
           hours * Duration.microsecondsPerHour +
           minutes * Duration.microsecondsPerMinute +
           seconds * Duration.microsecondsPerSecond +
           milliseconds * Duration.microsecondsPerMillisecond +
           microseconds;

  /// The interval of exactly [duration], with no months or days.
  PostgrestInterval.fromDuration(Duration duration)
    : this(microseconds: duration.inMicroseconds);

  /// Parses an interval literal in any of the output styles of Postgres:
  /// `1 year 2 mons 3 days 04:05:06.789` (`postgres`),
  /// `@ 1 year 2 mons 3 days 4 hours 5 mins 6.789 secs` and `@ 1 day ago`
  /// (`postgres_verbose`), `+1-2 +3 +4:05:06.789` (`sql_standard`) and
  /// `P1Y2M3DT4H5M6.789S` (`iso_8601`). The unit words may also be spelled
  /// out, so `3 hours 30 minutes` parses too.
  ///
  /// Throws a [FormatException] when [literal] is not an interval.
  factory PostgrestInterval.parse(String literal) {
    var text = literal.trim();
    if (text.isEmpty) throw FormatException('Not an interval literal', literal);
    if (text[0] == 'P' || text[0] == 'p') return _parseIso8601(text, literal);

    if (text.startsWith('@')) text = text.substring(1).trim();
    var negate = false;
    if (text.toLowerCase().endsWith(' ago')) {
      negate = true;
      text = text.substring(0, text.length - 4).trim();
    }

    var months = 0;
    var days = 0;
    var microseconds = 0;
    var sawUnit = false;
    final tokens = text.split(RegExp(r'\s+'));
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      final time = _timeToken.firstMatch(token);
      if (time != null) {
        final sign = time[1] == '-' ? -1 : 1;
        microseconds +=
            sign *
            (int.parse(time[2]!) * Duration.microsecondsPerHour +
                int.parse(time[3]!) * Duration.microsecondsPerMinute +
                int.parse(time[4] ?? '0') * Duration.microsecondsPerSecond +
                _fractionMicroseconds(time[5]));
        continue;
      }
      final yearMonth = _yearMonthToken.firstMatch(token);
      if (yearMonth != null) {
        final sign = yearMonth[1] == '-' ? -1 : 1;
        months +=
            sign * (int.parse(yearMonth[2]!) * 12 + int.parse(yearMonth[3]!));
        continue;
      }
      final number = _numberToken.firstMatch(token);
      if (number == null) {
        throw FormatException('Not an interval literal', literal);
      }
      final sign = number[1] == '-' ? -1 : 1;
      final whole = int.parse(number[2]!);
      final fraction = number[3];
      final unit = index + 1 < tokens.length
          ? _units[tokens[index + 1].toLowerCase()]
          : null;
      if (unit == null) {
        // The `sql_standard` style writes days as a bare number, and it
        // never mixes with unit words.
        if (fraction != null || sawUnit) {
          throw FormatException('Not an interval literal', literal);
        }
        days += sign * whole;
        continue;
      }
      index++;
      sawUnit = true;
      switch (unit) {
        case _Unit.years:
          months += sign * whole * 12;
        case _Unit.months:
          months += sign * whole;
        case _Unit.weeks:
          days += sign * whole * 7;
        case _Unit.days:
          days += sign * whole;
        case _Unit.hours:
          microseconds += sign * whole * Duration.microsecondsPerHour;
        case _Unit.minutes:
          microseconds += sign * whole * Duration.microsecondsPerMinute;
        case _Unit.seconds:
          microseconds +=
              sign *
              (whole * Duration.microsecondsPerSecond +
                  _fractionMicroseconds(fraction));
        case _Unit.milliseconds:
          microseconds += sign * whole * Duration.microsecondsPerMillisecond;
        case _Unit.microseconds:
          microseconds += sign * whole;
      }
      if (fraction != null && unit != _Unit.seconds) {
        throw FormatException('Not an interval literal', literal);
      }
    }
    return PostgrestInterval(
      months: negate ? -months : months,
      days: negate ? -days : days,
      microseconds: negate ? -microseconds : microseconds,
    );
  }

  /// The interval of no length at all.
  static const zero = PostgrestInterval();

  static final _timeToken = RegExp(
    r'^([+-])?(\d+):(\d{1,2})(?::(\d{1,2})(?:\.(\d+))?)?$',
  );
  static final _yearMonthToken = RegExp(r'^([+-])?(\d+)-(\d+)$');
  static final _numberToken = RegExp(r'^([+-])?(\d+)(?:\.(\d+))?$');
  static final _iso8601Pattern = RegExp(
    r'^P(?:(-?\d+)Y)?(?:(-?\d+)M)?(?:(-?\d+)W)?(?:(-?\d+)D)?'
    r'(?:T(?:(-?\d+)H)?(?:(-?\d+)M)?(?:(-?\d+)(?:\.(\d+))?S)?)?$',
    caseSensitive: false,
  );

  static const _units = {
    'year': _Unit.years,
    'years': _Unit.years,
    'mon': _Unit.months,
    'mons': _Unit.months,
    'month': _Unit.months,
    'months': _Unit.months,
    'week': _Unit.weeks,
    'weeks': _Unit.weeks,
    'day': _Unit.days,
    'days': _Unit.days,
    'hour': _Unit.hours,
    'hours': _Unit.hours,
    'min': _Unit.minutes,
    'mins': _Unit.minutes,
    'minute': _Unit.minutes,
    'minutes': _Unit.minutes,
    'sec': _Unit.seconds,
    'secs': _Unit.seconds,
    'second': _Unit.seconds,
    'seconds': _Unit.seconds,
    'millisecond': _Unit.milliseconds,
    'milliseconds': _Unit.milliseconds,
    'microsecond': _Unit.microseconds,
    'microseconds': _Unit.microseconds,
  };

  /// The calendar months, with 12 to a year.
  final int months;

  /// The calendar days, kept apart from [months] because a month has no
  /// fixed number of them.
  final int days;

  /// The clock time, kept apart from [days] because a day has no fixed
  /// number of hours across daylight saving changes.
  final int microseconds;

  /// The interval as one span of time, counting a year as 365.25 days and a
  /// remaining month as 30, the same convention `extract(epoch from …)`
  /// applies in Postgres.
  ///
  /// The result is an approximation whenever [months] or [days] is not zero,
  /// so write intervals back as they are instead of through this value.
  Duration toDuration() => Duration(
    microseconds:
        (months ~/ 12) * _microsecondsPerYear +
        months.remainder(12) * _microsecondsPerMonth +
        days * Duration.microsecondsPerDay +
        microseconds,
  );

  static const _microsecondsPerYear = 31557600 * Duration.microsecondsPerSecond;
  static const _microsecondsPerMonth = 30 * Duration.microsecondsPerDay;

  /// The literal in the `postgres` output style, which Postgres accepts on
  /// input whatever its `IntervalStyle` is: `1 year 2 mons 3 days
  /// 04:05:06.789`, with a bare `00:00:00` for [zero].
  ///
  /// The spelling follows Postgres exactly, so a value read from a column and
  /// written back is byte for byte what the database sent.
  String get literal {
    final parts = <String>[];
    var previousNegative = false;
    void addPart(int value, String unit) {
      if (value == 0) return;
      final sign = previousNegative && value > 0 ? '+' : '';
      parts.add('$sign$value $unit${value == 1 ? '' : 's'}');
      previousNegative = value < 0;
    }

    addPart(months ~/ 12, 'year');
    addPart(months.remainder(12), 'mon');
    addPart(days, 'day');
    if (parts.isEmpty || microseconds != 0) {
      var remaining = microseconds.abs();
      final hours = remaining ~/ Duration.microsecondsPerHour;
      remaining = remaining.remainder(Duration.microsecondsPerHour);
      final minutes = remaining ~/ Duration.microsecondsPerMinute;
      remaining = remaining.remainder(Duration.microsecondsPerMinute);
      final seconds = remaining ~/ Duration.microsecondsPerSecond;
      final fraction = remaining.remainder(Duration.microsecondsPerSecond);
      final sign = microseconds < 0
          ? '-'
          : previousNegative
          ? '+'
          : '';
      final time = StringBuffer()
        ..write(sign)
        ..write(_twoDigits(hours))
        ..write(':')
        ..write(_twoDigits(minutes))
        ..write(':')
        ..write(_twoDigits(seconds));
      if (fraction != 0) {
        time
          ..write('.')
          ..write(_trimZeros(fraction.toString().padLeft(6, '0')));
      }
      parts.add(time.toString());
    }
    return parts.join(' ');
  }

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgrestInterval &&
      other.months == months &&
      other.days == days &&
      other.microseconds == microseconds;

  @override
  int get hashCode => Object.hash(months, days, microseconds);

  static PostgrestInterval _parseIso8601(String text, String literal) {
    final match = _iso8601Pattern.firstMatch(text);
    if (match == null || text.length < 3 || text.toUpperCase() == 'PT') {
      throw FormatException('Not an interval literal', literal);
    }
    int component(int group) => int.parse(match[group] ?? '0');
    final seconds = component(7);
    final fraction = match[8];
    final fractionMicroseconds =
        (seconds < 0 || (match[7]?.startsWith('-') ?? false) ? -1 : 1) *
        _fractionMicroseconds(fraction);
    return PostgrestInterval(
      years: component(1),
      months: component(2),
      weeks: component(3),
      days: component(4),
      hours: component(5),
      minutes: component(6),
      seconds: seconds,
      microseconds: fractionMicroseconds,
    );
  }

  /// The microseconds of a fraction of a second written as its digits.
  static int _fractionMicroseconds(String? digits) {
    if (digits == null) return 0;
    return int.parse(digits.padRight(6, '0').substring(0, 6));
  }
}

enum _Unit {
  years,
  months,
  weeks,
  days,
  hours,
  minutes,
  seconds,
  milliseconds,
  microseconds,
}
