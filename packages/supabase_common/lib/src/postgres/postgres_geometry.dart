part of 'postgres_values.dart';

/// A point in the plane, the value of a Postgres `point` column.
///
/// ```dart
/// PostgresPoint.parse('(1.5,-2)').x  // 1.5
/// const PostgresPoint(1.5, -2).literal // (1.5,-2)
/// ```
///
/// Postgres has no `=` operator for `point`, so an `eq` filter on a `point`
/// column fails on the server.
@experimental
final class PostgresPoint implements PostgresValue {
  /// The point at [x] and [y].
  const PostgresPoint(this.x, this.y);

  /// Parses the `(x,y)` literal Postgres emits for a `point`.
  ///
  /// Throws a [FormatException] when [literal] is not a point.
  factory PostgresPoint.parse(String literal) =>
      _parseGeometry(literal, '^$_pointPattern\$', 'point', _points).single;

  /// The horizontal coordinate.
  final double x;

  /// The vertical coordinate.
  final double y;

  /// The literal Postgres accepts and emits, `(1.5,-2)`.
  @override
  String get literal => '(${_coordinate(x)},${_coordinate(y)})';

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgresPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// An infinite line `a·x + b·y + c = 0`, the value of a Postgres `line`
/// column.
///
/// ```dart
/// PostgresLine.parse('{1,-1,0}').b    // -1
/// const PostgresLine(1, -1, 0).literal // {1,-1,0}
/// ```
@experimental
final class PostgresLine implements PostgresValue {
  /// The line `a·x + b·y + c = 0`; Postgres rejects one where [a] and [b]
  /// are both zero.
  const PostgresLine(this.a, this.b, this.c);

  /// Parses the `{a,b,c}` literal Postgres emits for a `line`.
  ///
  /// Throws a [FormatException] when [literal] is not a line.
  factory PostgresLine.parse(String literal) {
    final numbers = _parseGeometry(
      literal,
      '^\\{$_numberPattern,$_numberPattern,$_numberPattern\\}\$',
      'line',
      (numbers) => numbers,
    );
    return PostgresLine(numbers[0], numbers[1], numbers[2]);
  }

  /// The coefficient of `x`.
  final double a;

  /// The coefficient of `y`.
  final double b;

  /// The constant term.
  final double c;

  /// The literal Postgres accepts and emits, `{1,-1,0}`.
  @override
  String get literal =>
      '{${_coordinate(a)},${_coordinate(b)},${_coordinate(c)}}';

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgresLine && other.a == a && other.b == b && other.c == c;

  @override
  int get hashCode => Object.hash(a, b, c);
}

/// A finite line segment between two points, the value of a Postgres `lseg`
/// column.
///
/// ```dart
/// PostgresLineSegment.parse('[(0,0),(1,1)]').end // (1,1)
/// ```
@experimental
final class PostgresLineSegment implements PostgresValue {
  /// The segment from [start] to [end].
  const PostgresLineSegment(this.start, this.end);

  /// Parses the `[(x1,y1),(x2,y2)]` literal Postgres emits for an `lseg`.
  ///
  /// Throws a [FormatException] when [literal] is not a line segment.
  factory PostgresLineSegment.parse(String literal) {
    final points = _parseGeometry(
      literal,
      '^\\[$_pointPattern,$_pointPattern\\]\$',
      'line segment',
      _points,
    );
    return PostgresLineSegment(points[0], points[1]);
  }

  /// The first end point.
  final PostgresPoint start;

  /// The second end point.
  final PostgresPoint end;

  /// The literal Postgres accepts and emits, `[(0,0),(1,1)]`.
  @override
  String get literal => '[${start.literal},${end.literal}]';

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgresLineSegment && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// A rectangle with sides parallel to the axes, the value of a Postgres
/// `box` column.
///
/// ```dart
/// PostgresBox(PostgresPoint(0, 0), PostgresPoint(2, 3)).literal // (2,3),(0,0)
/// ```
///
/// Postgres compares boxes by their area, so an `eq` filter on a `box`
/// column matches every box of the same area.
@experimental
final class PostgresBox implements PostgresValue {
  /// The box with [corner] and [oppositeCorner] at two opposite corners,
  /// stored as its [upperRight] and [lowerLeft] corners the way Postgres
  /// stores it.
  PostgresBox(PostgresPoint corner, PostgresPoint oppositeCorner)
    : upperRight = PostgresPoint(
        math.max(corner.x, oppositeCorner.x),
        math.max(corner.y, oppositeCorner.y),
      ),
      lowerLeft = PostgresPoint(
        math.min(corner.x, oppositeCorner.x),
        math.min(corner.y, oppositeCorner.y),
      );

  /// Parses the `(x1,y1),(x2,y2)` literal Postgres emits for a `box`, with
  /// the corners in either order.
  ///
  /// Throws a [FormatException] when [literal] is not a box.
  factory PostgresBox.parse(String literal) {
    final points = _parseGeometry(
      literal,
      '^$_pointPattern,$_pointPattern\$',
      'box',
      _points,
    );
    return PostgresBox(points[0], points[1]);
  }

  /// The corner with the larger coordinates.
  final PostgresPoint upperRight;

  /// The corner with the smaller coordinates.
  final PostgresPoint lowerLeft;

  /// The literal Postgres accepts and emits, the upper right corner first,
  /// `(2,3),(0,0)`.
  @override
  String get literal => '${upperRight.literal},${lowerLeft.literal}';

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgresBox &&
      other.upperRight == upperRight &&
      other.lowerLeft == lowerLeft;

  @override
  int get hashCode => Object.hash(upperRight, lowerLeft);
}

/// A sequence of connected points, open or closed, the value of a Postgres
/// `path` column.
///
/// ```dart
/// PostgresPath.parse('[(0,0),(1,1)]').isClosed // false
/// PostgresPath.parse('((0,0),(1,1))').isClosed // true
/// ```
@experimental
final class PostgresPath implements PostgresValue {
  /// The path through [points], which joins its last point back to its
  /// first when [isClosed].
  PostgresPath(List<PostgresPoint> points, {required this.isClosed})
    : points = List.unmodifiable(points) {
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'Must not be empty');
    }
  }

  /// Parses the literal Postgres emits for a `path`, `[(x1,y1),…]` when open
  /// and `((x1,y1),…)` when closed.
  ///
  /// Throws a [FormatException] when [literal] is not a path.
  factory PostgresPath.parse(String literal) {
    final text = literal.trim();
    final isClosed = text.startsWith('(');
    final points = _parseGeometry(
      text,
      isClosed ? '^\\($_pointListPattern\\)\$' : '^\\[$_pointListPattern\\]\$',
      'path',
      _points,
    );
    return PostgresPath(points, isClosed: isClosed);
  }

  /// The points of the path, in order.
  final List<PostgresPoint> points;

  /// Whether the path joins its last point back to its first.
  final bool isClosed;

  /// The literal Postgres accepts and emits, `[(0,0),(1,1)]` when open and
  /// `((0,0),(1,1))` when closed.
  @override
  String get literal {
    final inner = points.map((point) => point.literal).join(',');
    return isClosed ? '($inner)' : '[$inner]';
  }

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgresPath &&
      other.isClosed == isClosed &&
      _samePoints(other.points, points);

  @override
  int get hashCode => Object.hash(isClosed, Object.hashAll(points));
}

/// A closed shape bounded by straight edges between its points, the value
/// of a Postgres `polygon` column.
///
/// ```dart
/// PostgresPolygon.parse('((0,0),(1,1),(1,0))').points.length // 3
/// ```
///
/// Postgres has no `=` operator for `polygon`, so an `eq` filter on a
/// `polygon` column fails on the server.
@experimental
final class PostgresPolygon implements PostgresValue {
  /// The polygon with the corners [points], in order.
  PostgresPolygon(List<PostgresPoint> points)
    : points = List.unmodifiable(points) {
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'Must not be empty');
    }
  }

  /// Parses the `((x1,y1),…)` literal Postgres emits for a `polygon`.
  ///
  /// Throws a [FormatException] when [literal] is not a polygon.
  factory PostgresPolygon.parse(String literal) => PostgresPolygon(
    _parseGeometry(
      literal,
      '^\\($_pointListPattern\\)\$',
      'polygon',
      _points,
    ),
  );

  /// The corners of the polygon, in order.
  final List<PostgresPoint> points;

  /// The literal Postgres accepts and emits, `((0,0),(1,1),(1,0))`.
  @override
  String get literal => '(${points.map((point) => point.literal).join(',')})';

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgresPolygon && _samePoints(other.points, points);

  @override
  int get hashCode => Object.hashAll(points);
}

/// A circle, the value of a Postgres `circle` column.
///
/// ```dart
/// PostgresCircle.parse('<(1,2),3>').radius                 // 3
/// const PostgresCircle(PostgresPoint(1, 2), 3).literal     // <(1,2),3>
/// ```
@experimental
final class PostgresCircle implements PostgresValue {
  /// The circle around [center] with [radius]; Postgres rejects a negative
  /// radius.
  const PostgresCircle(this.center, this.radius);

  /// Parses the `<(x,y),r>` literal Postgres emits for a `circle`.
  ///
  /// Throws a [FormatException] when [literal] is not a circle.
  factory PostgresCircle.parse(String literal) {
    final numbers = _parseGeometry(
      literal,
      '^<$_pointPattern,$_numberPattern>\$',
      'circle',
      (numbers) => numbers,
    );
    return PostgresCircle(PostgresPoint(numbers[0], numbers[1]), numbers[2]);
  }

  /// The center of the circle.
  final PostgresPoint center;

  /// The radius of the circle.
  final double radius;

  /// The literal Postgres accepts and emits, `<(1,2),3>`.
  @override
  String get literal => '<${center.literal},${_coordinate(radius)}>';

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) =>
      other is PostgresCircle &&
      other.center == center &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(center, radius);
}

/// A coordinate as Postgres spells it: `NaN`, `Infinity`, an exponent, or a
/// plain decimal number.
const _numberPattern =
    r'\s*[-+]?(?:NaN|Infinity|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s*';

const _pointPattern = '\\s*\\($_numberPattern,$_numberPattern\\)\\s*';

const _pointListPattern = '$_pointPattern(?:,$_pointPattern)*';

final _numberToken = RegExp(
  r'[-+]?(?:NaN|Infinity|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)',
);

/// Checks [literal] against [pattern] and hands the numbers it holds, in
/// order, to [build].
T _parseGeometry<T>(
  String literal,
  String pattern,
  String name,
  T Function(List<double> numbers) build,
) {
  final text = literal.trim();
  if (!RegExp(pattern).hasMatch(text)) {
    throw FormatException('Not a $name', literal);
  }
  return build([
    for (final match in _numberToken.allMatches(text)) double.parse(match[0]!),
  ]);
}

List<PostgresPoint> _points(List<double> numbers) => [
  for (var index = 0; index < numbers.length; index += 2)
    PostgresPoint(numbers[index], numbers[index + 1]),
];

bool _samePoints(List<PostgresPoint> first, List<PostgresPoint> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

/// Renders [value] the way Postgres reads it back exactly, a whole number
/// without a fraction.
String _coordinate(double value) {
  if (value.isFinite &&
      value == value.truncateToDouble() &&
      value.abs() < 1e15) {
    return value.toInt().toString();
  }
  return value.toString();
}
