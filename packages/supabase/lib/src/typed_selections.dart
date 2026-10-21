import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

/// [columns] followed by the columns of [primaryKey] not among them, the
/// columns a partial row of a realtime change is read through.
@experimental
@internal
List<PostgrestStoredColumn<Row, Object>> withPrimaryKey<Row>(
  List<PostgrestStoredColumn<Row, Object>> columns,
  List<PostgrestStoredColumn<Row, Object>> primaryKey,
) => [
  ...columns,
  for (final column in primaryKey)
    if (!columns.any((selected) => selected.name == column.name)) column,
];
