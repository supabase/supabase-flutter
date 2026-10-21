part of 'postgres_values.dart';

/// A Postgres multirange value, such as an `int4multirange` or a
/// `tstzmultirange`: an ordered list of non-overlapping [ranges] with bounds
/// of type [Bound].
///
/// ```dart
/// PostgresMultirange.parse('{[1,3),[5,7)}', int.parse).ranges.length // 2
/// PostgresMultirange<int>(const []).literal                         // {}
/// ```
///
/// Postgres merges overlapping and adjacent ranges and drops empty ones
/// when it stores a multirange, so a value read back can hold fewer ranges
/// than the one written.
@experimental
final class PostgresMultirange<Bound extends Object> implements PostgresValue {
  /// The multirange made of [ranges].
  PostgresMultirange(List<PostgresRange<Bound>> ranges)
    : ranges = List.unmodifiable(ranges);

  /// Parses a Postgres multirange literal such as `{[1,3),[5,7)}` or `{}`,
  /// reading each bound with [parseBound] as [PostgresRange.parse] does.
  ///
  /// Throws a [FormatException] when [literal] is not a multirange.
  factory PostgresMultirange.parse(
    String literal,
    Bound Function(String bound) parseBound,
  ) {
    final text = literal.trim();
    if (text.length < 2 || !text.startsWith('{') || !text.endsWith('}')) {
      throw FormatException('Not a multirange literal', literal);
    }
    final members = _splitRanges(text.substring(1, text.length - 1));
    if (members == null) {
      throw FormatException('Not a multirange literal', literal);
    }
    return PostgresMultirange([
      for (final member in members) PostgresRange.parse(member, parseBound),
    ]);
  }

  /// The ranges, in order.
  final List<PostgresRange<Bound>> ranges;

  /// The Postgres literal, with each bound rendered by [renderBound] as
  /// [PostgresRange.render] does.
  String render(String Function(Bound bound) renderBound) =>
      '{${ranges.map((range) => range.render(renderBound)).join(',')}}';

  /// The Postgres literal, with the bounds rendered as
  /// [PostgresRange.literal] renders them.
  @override
  String get literal => '{${ranges.map((range) => range.literal).join(',')}}';

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) {
    if (other is! PostgresMultirange<Bound> ||
        other.ranges.length != ranges.length) {
      return false;
    }
    for (var index = 0; index < ranges.length; index++) {
      if (other.ranges[index] != ranges[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ranges);
}

/// Splits the inside of a multirange literal into the literals of its
/// ranges, separated by commas, or returns `null` when it is malformed. A
/// bracket inside a quoted bound does not end the range.
List<String>? _splitRanges(String inner) {
  final ranges = <String>[];
  var index = 0;
  void skipWhitespace() {
    while (index < inner.length && inner[index].trim().isEmpty) {
      index++;
    }
  }

  skipWhitespace();
  while (index < inner.length) {
    if (ranges.isNotEmpty) {
      if (inner[index] != ',') return null;
      index++;
      skipWhitespace();
    }
    final start = index;
    if (inner.toLowerCase().startsWith('empty', index)) {
      index += 'empty'.length;
    } else {
      if (index >= inner.length || !'[('.contains(inner[index])) return null;
      var quoted = false;
      index++;
      while (index < inner.length) {
        final character = inner[index];
        if (character == r'\') {
          index += 2;
          continue;
        }
        if (character == '"') quoted = !quoted;
        if (!quoted && (character == ']' || character == ')')) break;
        index++;
      }
      if (index >= inner.length) return null;
      index++;
    }
    ranges.add(inner.substring(start, index));
    skipWhitespace();
  }
  return ranges;
}
