// Adapted from epgsql (src/epgsql_binary.erl), this module licensed under
// 3-clause BSD found here: https://raw.githubusercontent.com/epgsql/epgsql/devel/LICENSE

import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;

enum PostgresTypes {
  abstime,
  bool,
  date,
  daterange,
  float4,
  float8,
  int2,
  int4,
  int4range,
  int8,
  int8range,
  json,
  jsonb,
  money,
  numeric,
  oid,
  reltime,
  time,
  text,
  timestamp,
  timestamptz,
  timetz,
  tsrange,
  tstzrange,
}

class PostgresColumn {
  /// the column name. eg: "user_id"
  final String name;

  /// the column type. eg: "uuid"
  final String type;

  /// any special flags for the column. eg: ["key"]
  final List<String>? flags;

  /// the type modifier. eg: 4294967295
  final int? typeModifier;

  const PostgresColumn(
    this.name,
    this.type, {
    this.flags = const [],
    this.typeModifier,
  });
}

/// Takes an array of columns and an object of string values then converts each string value
/// to its mapped type.
///
/// `columns` All of the columns
/// `record` The map of string values
/// `skipTypes` The array of types that should not be converted
///
/// ```dart
/// convertChangeData([{name: 'first_name', type: 'text'}, {name: 'age', type: 'int4'}], {'first_name': 'Paul', 'age':'33'}, {})
/// => { 'first_name': 'Paul', 'age': 33 }
/// ```
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

  record.forEach((key, value) {
    result[key] = convertColumn(key, parsedColumns, record, skipTypes ?? []);
  });
  return result;
}

/// Converts the value of an individual column.
///
/// `columnName` The column that you want to convert
/// `columns` All of the columns
/// `records` The map of string values
/// `skipTypes` An array of types that should not be converted
///
/// ```dart
/// convertColumn('age', [{name: 'first_name', type: 'text'}, {name: 'age', type: 'int4'}], ['Paul', '33'], [])
/// => 33
/// convertColumn('age', [{name: 'first_name', type: 'text'}, {name: 'age', type: 'int4'}], ['Paul', '33'], ['int4'])
/// => "33"
/// ```
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
dynamic convertCell(String type, dynamic value) {
  // if data type is an array
  if (type[0] == '_') {
    final dataType = type.substring(1);
    return toArray(value, dataType);
  }

  final typeEnum = PostgresTypes.values
      .firstWhereOrNull((e) => e.toString() == 'PostgresTypes.$type');
  // If not null, convert to correct type.
  switch (typeEnum) {
    case PostgresTypes.bool:
      return toBoolean(value);
    case PostgresTypes.float4:
    case PostgresTypes.float8:
    case PostgresTypes.numeric:
      return toDouble(value);
    case PostgresTypes.int2:
    case PostgresTypes.int4:
    case PostgresTypes.int8:
    case PostgresTypes.oid:
      return toInt(value);
    case PostgresTypes.json:
    case PostgresTypes.jsonb:
      return toJson(value);
    case PostgresTypes.timestamp:
      return toTimestampString(
        value.toString(),
      ); // Format to be consistent with PostgREST
    case PostgresTypes.abstime: // To allow users to cast it based on Timezone
    case PostgresTypes.date: // To allow users to cast it based on Timezone
    case PostgresTypes.daterange:
    case PostgresTypes.int4range:
    case PostgresTypes.int8range:
    case PostgresTypes.money:
    case PostgresTypes.reltime: // To allow users to cast it based on Timezone
    case PostgresTypes.text:
    case PostgresTypes.time: // To allow users to cast it based on Timezone
    case PostgresTypes
          .timestamptz: // To allow users to cast it based on Timezone
    case PostgresTypes.timetz: // To allow users to cast it based on Timezone
    case PostgresTypes.tsrange:
    case PostgresTypes.tstzrange:
      return noop(value);
    default:
      // Return the value for remaining types
      return noop(value);
  }
}

dynamic noop(dynamic value) {
  return value;
}

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

double? toDouble(dynamic value) {
  if (value is double) {
    return value;
  } else {
    try {
      final temp = value.toString();
      return double.parse(temp);
    } catch (_) {
      return null;
    }
  }
}

int? toInt(dynamic value) {
  if (value is int) {
    return value;
  } else {
    try {
      final temp = value.toString();
      return int.parse(temp);
    } catch (_) {
      return null;
    }
  }
}

dynamic toJson(dynamic value) {
  if (value is String) {
    try {
      return json.decode(value);
    } catch (error) {
      print('JSON parse error: $error');
      return value;
    }
  }
  return value;
}

/// Converts a Postgres Array into a native Dart array
///
///``` dart
/// @example toArray('{"[2021-01-01,2021-12-31)","(2021-01-01,2021-12-32]"}', 'daterange')
/// //=> ['[2021-01-01,2021-12-31)', '(2021-01-01,2021-12-32]']
/// @example toArray([1,2,3,4], 'int4')
/// //=> [1,2,3,4]
///  ```
dynamic toArray(dynamic value, String type) {
  if (value is! String) {
    return value;
  }

  // trim Postgres array curly brackets
  final lastIdx = value.length - 1;
  final closeBrace = value[lastIdx];
  final openBrace = value[0];

  // Confirm value is a Postgres array by checking curly brackets
  if (openBrace == '{' && closeBrace == '}') {
    final valTrim = value.substring(1, lastIdx);
    List arr;

    // TODO: find a better solution to separate Postgres array data
    try {
      arr = json.decode('[$valTrim]') as List;
    } catch (_) {
      // WARNING: splitting on comma does not cover all edge cases
      arr = valTrim != '' ? valTrim.split(',') : [];
    }

    return arr.map((val) => convertCell(type, val)).toList();
  }

  return value;
}

/// Fixes timestamp to be ISO-8601. Swaps the space between the date and time for a 'T'
/// See https://github.com/supabase/supabase/issues/18
///
///```dart
/// @example toTimestampString('2019-09-10 00:00:00')
/// => '2019-09-10T00:00:00'
/// ```
String? toTimestampString(String? value) {
  if (value != null) {
    return value.replaceAll(' ', 'T');
  }
  return null;
}

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

Map<String, Map<String, dynamic>> getPayloadRecords(
    Map<String, dynamic> payload) {
  final records = <String, Map<String, dynamic>>{
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
