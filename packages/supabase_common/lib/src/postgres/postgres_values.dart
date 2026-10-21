import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' show hex;
import 'package:meta/meta.dart';

part 'postgres_bytea.dart';
part 'postgres_date.dart';
part 'postgres_interval.dart';
part 'postgres_range.dart';
part 'postgres_time.dart';
part 'postgres_vector.dart';

/// A value of a Postgres type that has a literal of its own, such as a
/// [PostgresDate] or a [PostgresRange].
///
/// Filters and writes send the value as its [literal].
@experimental
abstract interface class PostgresValue {
  /// The literal Postgres reads the value from, `2024-02-29` for a date.
  String get literal;
}
