// Adapted from epgsql (src/epgsql_binary.erl), this module licensed under
// 3-clause BSD found here:
// https://raw.githubusercontent.com/epgsql/epgsql/devel/LICENSE

import 'dart:convert';
import 'package:meta/meta.dart';

import 'package:collection/collection.dart' show IterableExtension;

/// A PostgreSQL column type, as sent in the `type` field of a column
/// description.
enum PostgresType {
  /// Legacy `abstime` (absolute time).
  abstime,

  bool,

  date,

  /// `daterange`, a range of dates.
  daterange,

  /// `real`, a 4-byte floating point number.
  float4,

  /// `double precision`, an 8-byte floating point number.
  float8,

  /// `smallint`, a 2-byte integer.
  int2,

  /// `integer`, a 4-byte integer.
  int4,

  /// `int4range`, a range of 4-byte integers.
  int4range,

  /// `bigint`, an 8-byte integer.
  int8,

  /// `int8range`, a range of 8-byte integers.
  int8range,

  json,

  jsonb,

  money,

  /// `numeric`/`decimal`.
  numeric,

  /// `oid`, an object identifier.
  oid,

  /// Legacy `reltime` (relative time).
  reltime,

  /// `time`, a time of day without a time zone.
  time,

  text,

  /// `timestamp`, without a time zone.
  timestamp,

  /// `timestamptz`, with a time zone.
  timestamptz,

  /// `timetz`, a time of day with a time zone.
  timetz,

  /// `tsrange`, a range of timestamps.
  tsrange,

  /// `tstzrange`, a range of timestamps with a time zone.
  tstzrange,
}

/// A PostgreSQL column description used to convert a change payload's raw
/// string values to their Dart-typed form.
class PostgresColumn {
  const PostgresColumn(
    this.name,
    this.type, {
    this.flags = const [],
    this.typeModifier,
  });

  /// the column name. eg: "user_id"
  final String name;

  /// the column type. eg: "uuid"
  final String type;

  /// any special flags for the column. eg: ["key"]
  final List<String>? flags;

  /// the type modifier. eg: 4294967295
  final int? typeModifier;
}

/// Takes an array of columns and an object of string values then converts each
/// string value to its mapped type.
///
/// `columns` All of the columns
/// `record` The map of string values
/// `skipTypes` The array of types that should not be converted
///
/// ```dart
/// convertChangeData(
///   [{'name': 'first_name', 'type': 'text'}, {'name': 'age', 'type': 'int4'}],
///   {'first_name': 'Paul', 'age':'33'},
/// )
/// => { 'first_name': 'Paul', 'age': 33 }
/// ```
@internal
Map<String, dynamic> convertChangeData(
  List<Map<String, dynamic>> columns,
  Map<String, dynamic> record, {
  List<String>? skipTypes,
}) {
  final result = <String, dynamic>{};
  final parsedColumns = <PostgresColumn>[];

  for (final element in columns) {
    final name = element['name'] as String?;
    final type = element['type'] as String?;
    if (name != null && type != null) {
      parsedColumns.add(PostgresColumn(name, type));
    }
  }

  for (final key in record.keys) {
    result[key] = convertColumn(key, parsedColumns, record, skipTypes ?? []);
  }
  return result;
}

/// Converts the value of an individual column.
///
/// `columnName` The column that you want to convert
/// `columns` All of the columns
/// `record` The map of string values
/// `skipTypes` An array of types that should not be converted
///
/// ```dart
/// convertColumn(
///   'age',
///   [{'name': 'first_name', 'type': 'text'}, {'name': 'age', 'type': 'int4'}],
///   {'first_name': 'Paul', 'age': '33'},
///   [],
/// )
/// => 33
/// convertColumn(
///   'age',
///   [{'name': 'first_name', 'type': 'text'}, {'name': 'age', 'type': 'int4'}],
///   {'first_name': 'Paul', 'age': '33'},
///   ['int4'],
/// )
/// => "33"
/// ```
@internal
dynamic convertColumn(
  String columnName,
  List<PostgresColumn> columns,
  Map<String, dynamic> record,
  List<String> skipTypes,
) {
  final column = columns.firstWhereOrNull((x) => x.name == columnName);
  final columnValue = record[columnName];

  if (column != null && !skipTypes.contains(column.type)) {
    return convertCell(column.type, columnValue);
  }
  return noop(columnValue);
}

/// If the value of the cell is `null`, returns null.
/// Otherwise converts the string value to the correct type.
///
/// `type` A postgres column type
/// `stringValue` The cell value
///
/// ```dart
/// @example convertCell('bool', 'true')
/// => true
/// @example convertCell('int8', '10')
/// => 10
/// @example convertCell('_int4', '{1,2,3,4}')
/// => [1,2,3,4]
/// ```
@internal
dynamic convertCell(String type, dynamic value) {
  if (value == null) {
    return null;
  }

  // if data type is an array
  if (type[0] == '_') {
    final dataType = type.substring(1);
    return toArray(value, dataType);
  }

  final typeEnum = PostgresType.values.firstWhereOrNull((e) => e.name == type);
  // If not null, convert to correct type.
  switch (typeEnum) {
    case PostgresType.bool:
      return toBoolean(value);
    case PostgresType.float4:
    case PostgresType.float8:
    case PostgresType.numeric:
      return toDouble(value);
    case PostgresType.int2:
    case PostgresType.int4:
    case PostgresType.int8:
    case PostgresType.oid:
      return toInt(value);
    case PostgresType.json:
    case PostgresType.jsonb:
      return toJson(value);
    case PostgresType.timestamp:
      return toTimestampString(
        value?.toString(),
      ); // Format to be consistent with PostgREST
    case PostgresType.abstime: // To allow users to cast it based on Timezone
    case PostgresType.date: // To allow users to cast it based on Timezone
    case PostgresType.daterange:
    case PostgresType.int4range:
    case PostgresType.int8range:
    case PostgresType.money:
    case PostgresType.reltime: // To allow users to cast it based on Timezone
    case PostgresType.text:
    case PostgresType.time: // To allow users to cast it based on Timezone
    case PostgresType
        .timestamptz: // To allow users to cast it based on Timezone
    case PostgresType.timetz: // To allow users to cast it based on Timezone
    case PostgresType.tsrange:
    case PostgresType.tstzrange:
    case null:
      return noop(value);
  }
}

@internal
dynamic noop(dynamic value) {
  return value;
}

@internal
bool? toBoolean(dynamic value) {
  switch (value) {
    case 't':
    case 'true':
      return true;
    case 'f':
    case 'false':
      return false;
    default:
      if (value is bool) return value;
      return null;
  }
}

@internal
double? toDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return double.tryParse(value.toString());
}

@internal
int? toInt(dynamic value) {
  // On the web an integral number satisfies both `is int` and `is double`,
  // so check `double` first to keep the whole-number and range validation
  // in effect on every platform.
  if (value is double) {
    return _wholeDoubleToInt(value);
  }
  if (value is int) {
    return value;
  }
  if (value == null) {
    return null;
  }
  final stringValue = value.toString();
  final parsedInt = int.tryParse(stringValue);
  if (parsedInt != null) {
    return parsedInt;
  }
  final match = _integerWithZeroFraction.firstMatch(stringValue);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!);
}

/// Matches an integer with a decimal fraction of only zeros, such as `10.0`
/// or `-3.000`. Parsing the integer part directly keeps values above 2^53
/// exact, which a round trip through [double] would not.
final _integerWithZeroFraction = RegExp(r'^([+-]?\d+)\.0+$');

/// The lowest and highest [double] values enclosing the native 64-bit
/// integer range, -2^63 and 2^63. Both are exactly representable as doubles.
const _minIntAsDouble = -9223372036854775808.0;
const _maxIntExclusiveAsDouble = 9223372036854775808.0;

int? _wholeDoubleToInt(double value) {
  if (!value.isFinite || value.truncateToDouble() != value) {
    return null;
  }
  if (value < _minIntAsDouble || value >= _maxIntExclusiveAsDouble) {
    return null;
  }
  return value.toInt();
}

@internal
dynamic toJson(dynamic value) {
  if (value is String) {
    try {
      return json.decode(value);
    } catch (error) {
      return value;
    }
  }
  return value;
}

/// Converts a Postgres Array into a native Dart array
///
///``` dart
/// @example toArray('{"[2021-01-01,2021-12-31)","(2021-01-01,2021-12-32]"}',
/// 'daterange')
/// //=> ['[2021-01-01,2021-12-31)', '(2021-01-01,2021-12-32]']
/// @example toArray([1,2,3,4], 'int4')
/// //=> [1,2,3,4]
///  ```
@internal
dynamic toArray(dynamic value, String type) {
  if (value is! String) {
    return value;
  }

  // Postgres prefixes the literal with explicit dimensions, for example
  // `[0:1]={1,2}`, when a dimension's lower bound is not 1.
  final literal = value.replaceFirst(_arrayDimensions, '');

  // Confirm value is a Postgres array by checking curly brackets
  if (literal.length < 2 ||
      !literal.startsWith('{') ||
      !literal.endsWith('}')) {
    return value;
  }

  final elements = _ArrayLiteralParser(
    literal,
    _elementDelimiter(type),
  ).parse();
  if (elements == null) {
    // Not a literal this parser understands, hand the raw value back rather
    // than splitting it into something that looks like data but isn't.
    return value;
  }

  return _convertElements(elements, type);
}

/// The explicit dimension decoration of an array literal, such as
/// `[0:1]=` or `[1:2][3:4]=`.
final _arrayDimensions = RegExp(r'^(\[-?\d+:-?\d+\])+=');

/// The character separating two elements of an array literal, which is the
/// element type's `typdelim`. That is a comma for every built-in type except
/// `box`, whose values use commas internally and are separated by semicolons.
String _elementDelimiter(String type) => type == 'box' ? ';' : ',';

/// Runs [convertCell] over every leaf of a parsed array literal, leaving nulls
/// and the shape of nested arrays intact.
dynamic _convertElements(dynamic element, String type) {
  if (element is List) {
    return element.map((child) => _convertElements(child, type)).toList();
  }
  if (element == null) {
    return null;
  }
  return convertCell(type, element);
}

/// Parses the array literal Postgres sends on the wire, for example
/// `{"a,b",c}` or `{{1,2},{3,4}}`.
///
/// Elements are separated by [_delimiter], may be quoted with `"` (in which
/// case `\` escapes the next character), and unquoted whitespace around an
/// element is not part of its value. An unquoted `NULL` is the null element,
/// while a quoted `"NULL"` is the four character string.
class _ArrayLiteralParser {
  _ArrayLiteralParser(this._literal, this._delimiter);

  final String _literal;
  final String _delimiter;
  int _position = 0;

  bool get _isAtEnd => _position >= _literal.length;

  /// Returns the parsed elements, or null when [_literal] is not a single
  /// well-formed array so the caller can fall back to the raw value instead
  /// of silently returning corrupted data.
  List<dynamic>? parse() {
    try {
      final elements = _parseArray();
      return _isAtEnd ? elements : null;
    } on FormatException {
      return null;
    }
  }

  List<dynamic> _parseArray() {
    _expect('{');
    final elements = <dynamic>[];
    _skipWhitespace();
    if (_consume('}')) {
      return elements;
    }
    while (true) {
      _skipWhitespace();
      elements.add(_parseElement());
      _skipWhitespace();
      if (_consume('}')) {
        return elements;
      }
      _expect(_delimiter);
    }
  }

  dynamic _parseElement() {
    return switch (_peek()) {
      '{' => _parseArray(),
      '"' => _parseQuoted(),
      _ => _parseUnquoted(),
    };
  }

  String _parseQuoted() {
    _expect('"');
    final buffer = StringBuffer();
    while (true) {
      final char = _next();
      if (char == '"') {
        return buffer.toString();
      }
      buffer.write(char == r'\' ? _next() : char);
    }
  }

  dynamic _parseUnquoted() {
    final start = _position;
    while (!_isAtEnd &&
        _literal[_position] != _delimiter &&
        _literal[_position] != '}') {
      _position++;
    }
    final raw = _literal.substring(start, _position).trim();
    return raw.toUpperCase() == 'NULL' ? null : raw;
  }

  void _skipWhitespace() {
    while (!_isAtEnd && _literal[_position].trim().isEmpty) {
      _position++;
    }
  }

  String _peek() {
    if (_isAtEnd) {
      throw const FormatException();
    }
    return _literal[_position];
  }

  String _next() {
    if (_isAtEnd) {
      throw const FormatException();
    }
    return _literal[_position++];
  }

  bool _consume(String char) {
    if (_isAtEnd || _literal[_position] != char) {
      return false;
    }
    _position++;
    return true;
  }

  void _expect(String char) {
    if (!_consume(char)) {
      throw const FormatException();
    }
  }
}

/// Fixes timestamp to be ISO-8601. Swaps the space between the date and time
/// for a 'T' See https://github.com/supabase/supabase/issues/18
///
///```dart
/// @example toTimestampString('2019-09-10 00:00:00')
/// => '2019-09-10T00:00:00'
/// ```
@internal
String? toTimestampString(String? value) {
  if (value != null) {
    return value.replaceAll(' ', 'T');
  }
  return null;
}

@internal
Map<String, dynamic> getEnrichedPayload(Map<String, dynamic> payload) {
  final postgresChanges = payload['data'] ?? payload;
  final schema = postgresChanges['schema'];
  final table = postgresChanges['table'];
  final commitTimestamp = postgresChanges['commit_timestamp'];
  final type = postgresChanges['type'];
  final errors = postgresChanges['errors'];

  final enrichedPayload = {
    'schema': schema,
    'table': table,
    'commit_timestamp': commitTimestamp,
    'eventType': type,
    'new': {},
    'old': {},
    'errors': errors,
  };

  return {
    ...enrichedPayload,
    ...getPayloadRecords(postgresChanges),
  };
}

@internal
Map<String, Map<String, dynamic>> getPayloadRecords(
  Map<String, dynamic> payload,
) {
  final Map<String, Map<String, dynamic>> records = {
    'new': {},
    'old': {},
  };

  if (payload['type'] == 'INSERT' || payload['type'] == 'UPDATE') {
    records['new'] = convertChangeData(
      List<Map<String, dynamic>>.from(payload['columns']),
      Map<String, dynamic>.from(payload['record']),
    );
  }

  if (payload['type'] == 'UPDATE' || payload['type'] == 'DELETE') {
    records['old'] = convertChangeData(
      List<Map<String, dynamic>>.from(payload['columns']),
      Map<String, dynamic>.from(payload['old_record']),
    );
  }

  return records;
}

/// Converts a WebSocket URL to an HTTP URL.
@internal
String httpEndpointUrl(String socketUrl) {
  var url = socketUrl;

  // Replace 'ws' or 'wss' with 'http' or 'https' respectively
  url = url.replaceFirst(RegExp(r'^ws', caseSensitive: false), 'http');

  // Remove WebSocket-specific endings
  url = url.replaceFirst(
    RegExp(r'(/socket/websocket|/socket|/websocket)/?$', caseSensitive: false),
    '',
  );

  // Remove trailing slashes
  return url.replaceAll(RegExp(r'/+$'), '');
}
