import 'dart:convert';

import 'package:meta/meta.dart';

/// Column description of the `todos` fixture table, as the realtime server
/// reports it in a `postgres_changes` event.
@visibleForTesting
const todoColumns = [
  {'name': 'id', 'type': 'int4', 'type_modifier': 4294967295},
  {'name': 'task', 'type': 'text', 'type_modifier': 4294967295},
  {'name': 'status', 'type': 'bool', 'type_modifier': 4294967295},
];

/// A protocol 2.0.0 `postgres_changes` text frame, which is a positional
/// array of `[join_ref, ref, topic, event, payload]`, encoded as JSON.
@visibleForTesting
String postgresChangesFrame(
  Object? topic, {
  required List<int> ids,
  required Map<String, dynamic> data,
}) => jsonEncode([
  null,
  null,
  topic,
  'postgres_changes',
  {'ids': ids, 'data': data},
]);
