import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// How long encoding may keep the calling isolate busy before it yields to
/// the event loop, so that a frame is not blocked for longer than this.
const _sliceMicroseconds = 2000;

/// How long encoding one batch of list elements should take, so that a slice
/// fits a couple of batches.
const _batchTargetMicroseconds = 500;

/// The number of elements in the first batch, and the largest list that is
/// encoded in one go without measuring.
const _initialBatchSize = 8;

const _openBracket = 0x5b;
const _comma = 0x2c;
const _closeBracket = 0x5d;

final _utf8JsonEncoder = JsonUtf8Encoder();

/// Encodes [json] into UTF-8 encoded JSON on the calling isolate.
///
/// A top level list is encoded in batches of elements, yielding to the event
/// loop whenever the work since the last yield exceeds two milliseconds.
/// Anything else is encoded in one go.
@internal
Future<Uint8List> encodeJsonBytes(Object? json) async {
  if (json is! List<Object?> || json.length <= _initialBatchSize) {
    return _utf8JsonEncoder.convert(json) as Uint8List;
  }
  final builder = BytesBuilder(copy: false)..addByte(_openBracket);
  await _encodeInBatches(json, (batch, {required isFirst}) {
    final encoded = _utf8JsonEncoder.convert(batch) as Uint8List;
    if (!isFirst) {
      builder.addByte(_comma);
    }
    builder.add(Uint8List.sublistView(encoded, 1, encoded.length - 1));
  });
  builder.addByte(_closeBracket);
  return builder.takeBytes();
}

/// Encodes [json] into a JSON string on the calling isolate, slicing a top
/// level list the same way [encodeJsonBytes] does.
@internal
Future<String> encodeJsonString(Object? json) async {
  if (json is! List<Object?> || json.length <= _initialBatchSize) {
    return jsonEncode(json);
  }
  final buffer = StringBuffer('[');
  await _encodeInBatches(json, (batch, {required isFirst}) {
    final encoded = jsonEncode(batch);
    if (!isFirst) {
      buffer.write(',');
    }
    buffer.write(encoded.substring(1, encoded.length - 1));
  });
  buffer.write(']');
  return buffer.toString();
}

/// Hands [list] to [encodeBatch] in consecutive batches, sized so that each
/// takes about [_batchTargetMicroseconds], and yields to the event loop
/// between batches once a slice is used up.
Future<void> _encodeInBatches(
  List<Object?> list,
  void Function(List<Object?> batch, {required bool isFirst}) encodeBatch,
) async {
  final slice = Stopwatch()..start();
  final batchWatch = Stopwatch();
  var batchSize = _initialBatchSize;
  var start = 0;
  while (start < list.length) {
    final end = math.min(start + batchSize, list.length);
    batchWatch
      ..reset()
      ..start();
    encodeBatch(list.sublist(start, end), isFirst: start == 0);
    final elapsed = batchWatch.elapsedMicroseconds;
    final count = end - start;
    batchSize = elapsed == 0
        ? batchSize * 2
        : math.max(1, count * _batchTargetMicroseconds ~/ elapsed);
    start = end;
    if (start < list.length &&
        slice.elapsedMicroseconds >= _sliceMicroseconds) {
      await Future<void>.delayed(Duration.zero);
      slice.reset();
    }
  }
}
