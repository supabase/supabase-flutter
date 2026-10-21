part of 'postgres_values.dart';

/// A position in the write-ahead log, the value of a Postgres `pg_lsn`
/// column.
///
/// ```dart
/// PostgresLogSequenceNumber.parse('16/B374D848').low  // 0xB374D848
/// PostgresLogSequenceNumber(0x16, 0xB374D848).literal // 16/B374D848
/// ```
///
/// The 64-bit position is kept as its [high] and [low] 32-bit halves, so it
/// stays exact on the web, where an `int` holds 53 bits. Positions compare in
/// log order.
@experimental
final class PostgresLogSequenceNumber
    implements PostgresValue, Comparable<PostgresLogSequenceNumber> {
  /// The position whose upper 32 bits are [high] and lower 32 bits are [low].
  ///
  /// Throws an [ArgumentError] when either half is outside the 32-bit
  /// unsigned range.
  PostgresLogSequenceNumber(this.high, this.low) {
    _checkHalf(high, 'high');
    _checkHalf(low, 'low');
  }

  /// Parses the `high/low` literal Postgres emits for a `pg_lsn`, each half
  /// written as up to eight hexadecimal digits, `16/B374D848`.
  ///
  /// Throws a [FormatException] when [literal] is not a log sequence number.
  factory PostgresLogSequenceNumber.parse(String literal) {
    final match = _logSequenceNumberPattern.firstMatch(literal.trim());
    if (match == null) {
      throw FormatException('Not a log sequence number', literal);
    }
    return PostgresLogSequenceNumber(
      int.parse(match[1]!, radix: 16),
      int.parse(match[2]!, radix: 16),
    );
  }

  /// The upper 32 bits of the position.
  final int high;

  /// The lower 32 bits of the position.
  final int low;

  /// The literal Postgres accepts and emits: both halves in uppercase
  /// hexadecimal without leading zeros, `16/B374D848`.
  @override
  String get literal =>
      '${high.toRadixString(16).toUpperCase()}/'
      '${low.toRadixString(16).toUpperCase()}';

  @override
  int compareTo(PostgresLogSequenceNumber other) {
    if (high != other.high) return high.compareTo(other.high);
    return low.compareTo(other.low);
  }

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgresLogSequenceNumber &&
      other.high == high &&
      other.low == low;

  @override
  int get hashCode => Object.hash(high, low);
}

final _logSequenceNumberPattern = RegExp(
  r'^([0-9A-Fa-f]{1,8})/([0-9A-Fa-f]{1,8})$',
);

void _checkHalf(int half, String name) {
  if (half < 0 || half > 0xFFFFFFFF) {
    throw ArgumentError.value(half, name, 'Must be between 0 and 0xFFFFFFFF');
  }
}
