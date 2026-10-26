import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'async_json_codec.dart';
import 'sliced_json_encoder.dart';

/// Payloads smaller than this are decoded directly on the calling isolate.
///
/// Below this size the JSON work takes well under a millisecond even on slow
/// devices, while handing it to another isolate costs more than that in
/// messaging overhead.
const _isolateThresholdBytes = 64 * 1024;

final Converter<List<int>, Object?> _utf8JsonDecoder = const Utf8Decoder().fuse(
  const JsonDecoder(),
);

/// Encodes and decodes JSON without blocking the calling isolate for long.
///
/// Small payloads are decoded inline, because parsing them costs less than an
/// isolate round trip. Large payloads are decoded on a short lived isolate
/// spawned per call: its result is handed back through `Isolate.exit` without
/// copying, and independent calls run in parallel. Encoding stays on the
/// calling isolate and is sliced, see [encode].
class YAJsonIsolate implements AsyncJsonCodec {
  YAJsonIsolate({
    this.debugName,
  });

  /// The debug name used for the isolates spawned by this instance.
  final String? debugName;

  Future<void>? _disposal;
  final Set<Future<void>> _activeWork = {};

  bool get _isDisposed => _disposal != null;

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('This YAJsonIsolate has already been disposed.');
    }
  }

  /// Dispose the instance.
  ///
  /// Rejects new work immediately and completes once the isolate work that
  /// was still in flight has finished. Safe to call more than once, and safe
  /// to call on an instance that was never used. Concurrent calls all await
  /// the same disposal. Using the instance afterwards throws a [StateError].
  @override
  Future<void> dispose() => _disposal ??= _activeWork.isEmpty
      ? Future.value()
      : Future.wait(_activeWork.toList()).then((_) {});

  /// Runs [computation] on a short lived isolate, keeping the call tracked
  /// so [dispose] can await it.
  Future<T> _runTracked<T>(T Function() computation) async {
    final completer = Completer<void>();
    _activeWork.add(completer.future);
    try {
      return await Isolate.run(computation, debugName: debugName);
    } finally {
      _activeWork.remove(completer.future);
      completer.complete();
    }
  }

  /// Decodes [json] into Dart values, like [jsonDecode].
  ///
  /// Small payloads are decoded inline, large ones on a short lived isolate.
  /// The threshold compares the length in UTF-16 code units, which is what
  /// the cost of parsing a string scales with.
  @override
  Future<dynamic> decode(String json) async {
    _throwIfDisposed();
    if (json.length < _isolateThresholdBytes) {
      await null;
      return jsonDecode(json);
    }
    return _runTracked(() => jsonDecode(json));
  }

  /// Decodes UTF-8 encoded JSON in [encodedJson] into Dart values.
  ///
  /// Preferred over [decode] when the payload is available as bytes, such as
  /// an HTTP response body: the bytes are copied once into a buffer that is
  /// handed to the decoding isolate in constant time, and the UTF-8 and JSON
  /// decoding steps are fused, so the calling isolate never pays for
  /// materializing the intermediate string.
  ///
  /// The bytes are read before control returns to the caller, so the buffer
  /// can be reused as soon as the call returns.
  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) async {
    _throwIfDisposed();
    if (encodedJson.length < _isolateThresholdBytes) {
      return _utf8JsonDecoder.convert(encodedJson);
    }
    final transferable = TransferableTypedData.fromList([encodedJson]);
    return await _runTracked(
      () => _utf8JsonDecoder.convert(transferable.materialize().asUint8List()),
    );
  }

  /// Encodes [json] into a JSON string, like [jsonEncode].
  ///
  /// Encoding happens on the calling isolate, because sending the value to
  /// another isolate copies it there first, which costs about as much as
  /// encoding it. A top level list, such as the rows of a bulk insert, is
  /// encoded in batches instead, yielding to the event loop every couple of
  /// milliseconds so that a frame is never blocked for long. The value must
  /// therefore not be mutated until the returned future completes.
  @override
  Future<String> encode(Object? json) => Future.sync(() {
    _throwIfDisposed();
    return encodeJsonString(json);
  });

  /// Encodes [json] into UTF-8 encoded JSON, slicing the work the same way
  /// [encode] does.
  @override
  Future<Uint8List> encodeBytes(Object? json) => Future.sync(() {
    _throwIfDisposed();
    return encodeJsonBytes(json);
  });
}
