import 'dart:convert';

import 'package:meta/meta.dart';

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
