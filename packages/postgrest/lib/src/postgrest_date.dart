part of 'postgrest_typed_builder.dart';

/// A calendar date without a time of day or a timezone, the value of a
/// Postgres `date` column.
///
/// ```dart
/// PostgrestDate(2024, 2, 29).literal              // 2024-02-29
/// PostgrestDate.parse('2024-02-29').toDateTime()  // DateTime(2024, 2, 29)
/// PostgrestDate.infinity.literal                  // infinity
/// ```
///
/// Years are counted the way [DateTime] counts them: year 0 is 1 BC and
/// negative years go further back, so `PostgrestDate(-43, 3, 15)` is the date
/// Postgres prints as `0044-03-15 BC`.
///
/// Postgres accepts `infinity` and `-infinity` as dates that sort after and
/// before every other date. They are [infinity] and [negativeInfinity] here;
/// [year], [month], [day] and [toDateTime] are not defined for them and throw
/// a [StateError].
@experimental
final class PostgrestDate implements Comparable<PostgrestDate> {
  /// The date [year]-[month]-[day].
  ///
  /// Throws an [ArgumentError] when the components do not name a day of the
  /// proleptic Gregorian calendar, which Postgres uses for every date.
  PostgrestDate(int year, int month, int day)
    : _year = year,
      _month = month,
      _day = day,
      _infinity = 0 {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12');
    }
    final daysInMonth = _daysInMonth(year, month);
    if (day < 1 || day > daysInMonth) {
      throw ArgumentError.value(
        day,
        'day',
        'Must be between 1 and $daysInMonth for $year-$month',
      );
    }
  }

  const PostgrestDate._infinite(this._infinity)
    : _year = 0,
      _month = 0,
      _day = 0;

  /// The calendar date of [dateTime] in the timezone it carries, so a UTC
  /// instant yields its UTC date and a local one its local date.
  PostgrestDate.fromDateTime(DateTime dateTime)
    : this(dateTime.year, dateTime.month, dateTime.day);

  /// Parses the `YYYY-MM-DD` literal Postgres emits for a date, with a ` BC`
  /// suffix for dates before year 1, or `infinity` and `-infinity`.
  ///
  /// Throws a [FormatException] when [literal] is not a date, including a
  /// date that does not exist such as `2023-02-29`.
  factory PostgrestDate.parse(String literal) {
    final text = literal.trim();
    final infinite = switch (text.toLowerCase()) {
      'infinity' || '+infinity' => infinity,
      '-infinity' => negativeInfinity,
      _ => null,
    };
    if (infinite != null) return infinite;
    final match = _datePattern.firstMatch(text);
    if (match == null) throw FormatException('Not a date literal', literal);
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final isBc = match[4] != null;
    if (isBc && year == 0) {
      throw FormatException('Not a date literal', literal);
    }
    try {
      return PostgrestDate(isBc ? 1 - year : year, month, day);
    } on ArgumentError {
      throw FormatException('Not a date literal', literal);
    }
  }

  /// The date after every other date, `infinity`.
  static const infinity = PostgrestDate._infinite(1);

  /// The date before every other date, `-infinity`.
  static const negativeInfinity = PostgrestDate._infinite(-1);

  static final _datePattern = RegExp(r'^(\d{4,})-(\d{2})-(\d{2})( BC)?$');

  final int _year;
  final int _month;
  final int _day;

  /// `1` for [infinity], `-1` for [negativeInfinity], `0` for a finite date.
  final int _infinity;

  /// The year, counted like [DateTime.year]: year 0 is 1 BC.
  int get year => _finite(_year);

  /// The month, 1 to 12.
  int get month => _finite(_month);

  /// The day of the month, 1 to 31.
  int get day => _finite(_day);

  /// Whether this is a calendar date rather than [infinity] or
  /// [negativeInfinity].
  bool get isFinite => _infinity == 0;

  /// Whether this is [infinity] or [negativeInfinity].
  bool get isInfinite => _infinity != 0;

  /// Midnight of this date, in the local timezone or, with [isUtc], in UTC.
  ///
  /// Throws a [StateError] for [infinity] and [negativeInfinity], and an
  /// [ArgumentError] for a date outside the range [DateTime] can represent,
  /// which ends long before the year 5874897 Postgres allows.
  DateTime toDateTime({bool isUtc = false}) =>
      isUtc ? DateTime.utc(year, month, day) : DateTime(year, month, day);

  /// The literal Postgres accepts and emits: `2024-02-29`, `0044-03-15 BC`,
  /// `infinity` or `-infinity`.
  String get literal {
    if (_infinity > 0) return 'infinity';
    if (_infinity < 0) return '-infinity';
    final isBc = _year < 1;
    final displayedYear = isBc ? 1 - _year : _year;
    return '${displayedYear.toString().padLeft(4, '0')}-'
        '${_month.toString().padLeft(2, '0')}-'
        '${_day.toString().padLeft(2, '0')}'
        '${isBc ? ' BC' : ''}';
  }

  @override
  int compareTo(PostgrestDate other) {
    if (_infinity != 0 || other._infinity != 0) {
      return _infinity.compareTo(other._infinity);
    }
    if (_year != other._year) return _year.compareTo(other._year);
    if (_month != other._month) return _month.compareTo(other._month);
    return _day.compareTo(other._day);
  }

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgrestDate &&
      other._infinity == _infinity &&
      other._year == _year &&
      other._month == _month &&
      other._day == _day;

  @override
  int get hashCode => Object.hash(_infinity, _year, _month, _day);

  int _finite(int component) {
    if (_infinity != 0) {
      throw StateError('$literal has no calendar components');
    }
    return component;
  }

  static int _daysInMonth(int year, int month) => switch (month) {
    2 => _isLeapYear(year) ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  static bool _isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}
