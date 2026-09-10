part of 'postgrest_typed_builder.dart';

/// A Postgres range value, such as an `int4range` or a `tstzrange`, with
/// bounds of type [Bound].
///
/// ```dart
/// PostgrestRange.closedOpen(2, 25).literal       // [2,25)
/// PostgrestRange<int>.closed(2, null).literal    // [2,)
/// PostgrestRange<int>.empty().literal            // empty
/// ```
///
/// A `null` bound is unbounded and always exclusive, the form Postgres
/// canonicalizes an omitted bound to, so a parsed value compares equal to the
/// one that was written. Bounds render through the same rules as filter
/// values, so a `DateTime` bound is sent in ISO 8601.
@experimental
final class PostgrestRange<Bound extends Object> {
  /// A range including [lower] and excluding [upper], `[lower,upper)`, the
  /// canonical form Postgres stores discrete ranges in.
  const PostgrestRange.closedOpen(this.lower, this.upper)
    : lowerInclusive = lower != null,
      upperInclusive = false,
      isEmpty = false;

  /// A range including both bounds, `[lower,upper]`.
  const PostgrestRange.closed(this.lower, this.upper)
    : lowerInclusive = lower != null,
      upperInclusive = upper != null,
      isEmpty = false;

  /// A range excluding both bounds, `(lower,upper)`.
  const PostgrestRange.open(this.lower, this.upper)
    : lowerInclusive = false,
      upperInclusive = false,
      isEmpty = false;

  /// A range excluding [lower] and including [upper], `(lower,upper]`.
  const PostgrestRange.openClosed(this.lower, this.upper)
    : lowerInclusive = false,
      upperInclusive = upper != null,
      isEmpty = false;

  /// The empty range, `empty`.
  const PostgrestRange.empty()
    : lower = null,
      upper = null,
      lowerInclusive = false,
      upperInclusive = false,
      isEmpty = true;

  /// Parses a Postgres range literal such as `[2,25)`, `["2024-01-01
  /// 00:00:00+00",)` or `empty`, reading each bound with [parseBound].
  ///
  /// A missing bound and an unquoted `infinity` or `-infinity` bound are both
  /// unbounded, `null`, so [parseBound] never sees them.
  ///
  /// Throws a [FormatException] when [literal] is not a range.
  factory PostgrestRange.parse(
    String literal,
    Bound Function(String bound) parseBound,
  ) {
    final trimmed = literal.trim();
    if (trimmed.toLowerCase() == 'empty') return PostgrestRange.empty();
    if (trimmed.length < 3 ||
        !'[('.contains(trimmed[0]) ||
        !'])'.contains(trimmed[trimmed.length - 1])) {
      throw FormatException('Not a range literal', literal);
    }
    final bounds = _splitBounds(trimmed.substring(1, trimmed.length - 1));
    if (bounds == null) throw FormatException('Not a range literal', literal);
    final (lower, upper) = bounds;
    final lowerInclusive = trimmed[0] == '[';
    final upperInclusive = trimmed[trimmed.length - 1] == ']';
    final lowerBound = lower == null ? null : parseBound(lower);
    final upperBound = upper == null ? null : parseBound(upper);
    return switch ((lowerInclusive, upperInclusive)) {
      (true, false) => PostgrestRange.closedOpen(lowerBound, upperBound),
      (true, true) => PostgrestRange.closed(lowerBound, upperBound),
      (false, false) => PostgrestRange.open(lowerBound, upperBound),
      (false, true) => PostgrestRange.openClosed(lowerBound, upperBound),
    };
  }

  /// The lower bound, or `null` when unbounded below.
  final Bound? lower;

  /// The upper bound, or `null` when unbounded above.
  final Bound? upper;

  /// Whether [lower] itself is part of the range; always `false` when
  /// unbounded.
  final bool lowerInclusive;

  /// Whether [upper] itself is part of the range; always `false` when
  /// unbounded.
  final bool upperInclusive;

  /// Whether this is the empty range, which contains no value.
  final bool isEmpty;

  /// The Postgres literal, with each bound rendered by [renderBound] and
  /// quoted when the literal requires it.
  String render(String Function(Bound bound) renderBound) {
    if (isEmpty) return 'empty';
    String side(Bound? bound) =>
        bound == null ? '' : _quoteRangeBound(renderBound(bound));
    return '${lowerInclusive ? '[' : '('}'
        '${side(lower)},${side(upper)}'
        '${upperInclusive ? ']' : ')'}';
  }

  /// The Postgres literal with bounds rendered like filter values.
  String get literal => render(_renderFilterValue);

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgrestRange<Bound> &&
      other.isEmpty == isEmpty &&
      other.lower == lower &&
      other.upper == upper &&
      other.lowerInclusive == lowerInclusive &&
      other.upperInclusive == upperInclusive;

  @override
  int get hashCode =>
      Object.hash(isEmpty, lower, upper, lowerInclusive, upperInclusive);
}

/// The unquoted bound spellings Postgres uses for an infinite bound.
const _infiniteBounds = {'infinity', '+infinity', '-infinity'};

/// Splits the inside of a range literal into its two bounds the way Postgres
/// reads them: a backslash escapes the next character, a doubled quote inside
/// a quoted bound is a quote, and a stray `)` or `]` makes the literal
/// malformed. An empty or infinite unquoted bound is `null`.
(String?, String?)? _splitBounds(String inner) {
  final bounds = <String?>[];
  final current = StringBuffer();
  var quoted = false;
  var sawQuotes = false;

  void finishBound() {
    final text = current.toString();
    final unbounded =
        !sawQuotes &&
        (text.isEmpty || _infiniteBounds.contains(text.toLowerCase()));
    bounds.add(unbounded ? null : text);
    current.clear();
    sawQuotes = false;
  }

  for (var index = 0; index < inner.length; index++) {
    final character = inner[index];
    final next = index + 1 < inner.length ? inner[index + 1] : null;
    if (character == r'\' && next != null) {
      current.write(next);
      index++;
    } else if (character == '"') {
      if (quoted && next == '"') {
        current.write('"');
        index++;
      } else {
        quoted = !quoted;
        sawQuotes = true;
      }
    } else if (quoted) {
      current.write(character);
    } else if (character == ',') {
      finishBound();
    } else if (character == ')' || character == ']') {
      return null;
    } else {
      current.write(character);
    }
  }
  if (quoted) return null;
  finishBound();
  if (bounds.length != 2) return null;
  return (bounds[0], bounds[1]);
}

/// Characters that carry structural meaning in a range literal, and therefore
/// require the bound to be quoted.
const _rangeReservedCharacters = ['(', ')', '[', ']', ',', '"', r'\'];

/// Quotes [raw] when it is empty, spells an infinite bound, contains a
/// range-reserved character or whitespace, escaping `\` and `"` inside the
/// quotes.
String _quoteRangeBound(String raw) {
  final needsQuoting =
      raw.isEmpty ||
      _infiniteBounds.contains(raw.toLowerCase()) ||
      _rangeReservedCharacters.any(raw.contains) ||
      raw.contains(RegExp(r'\s'));
  return needsQuoting ? _quote(raw) : raw;
}
