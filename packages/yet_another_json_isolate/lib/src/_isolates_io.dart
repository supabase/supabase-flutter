import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'async_json_codec.dart';

/// Payloads estimated to be smaller than this are processed directly on the
/// calling isolate.
///
/// Below this size the JSON work takes well under a millisecond even on slow
/// devices, while handing it to another isolate costs more than that in
/// messaging overhead.
const _isolateThresholdBytes = 64 * 1024;

/// Depth guard for [_remainingBudget], so that a cyclic or extremely deep
/// structure is handed to the isolate path instead of overflowing the stack
/// during estimation.
const _maxEstimationDepth = 512;

final Converter<List<int>, Object?> _utf8JsonDecoder = const Utf8Decoder().fuse(
  const JsonDecoder(),
);

/// Encodes and decodes JSON without blocking the calling isolate.
///
/// Small payloads are processed inline, because parsing them costs less than
/// an isolate round trip. Large payloads are processed on a short lived
/// isolate spawned per call: its result is handed back through `Isolate.exit`
/// without copying, and independent calls run in parallel.
class YAJsonIsolate implements AsyncJsonCodec {
  /// Creates a codec with an optional [debugName] for its isolates.
  YAJsonIsolate({
    this.debugName,
  });

  /// The debug name used for the isolates spawned by this instance.
  final String? debugName;

  bool _hasStartedInitialize = false;
  Future<void>? _disposal;
  final Set<Future<void>> _activeWork = {};

  bool get _isDisposed => _disposal != null;

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('This YAJsonIsolate has already been disposed.');
    }
  }

  /// Kept for backwards compatibility.
  ///
  /// There is no persistent isolate anymore, so there is nothing to
  /// initialize: large payloads are processed on short lived isolates spawned
  /// per call.
  Future<void> initialize() {
    return Future.sync(() {
      _throwIfDisposed();
      assert(
        _hasStartedInitialize == false,
        'initialize() can only be called once per isolate.',
      );
      _hasStartedInitialize = true;
    });
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
  /// Payloads estimated to be small are encoded inline, the rest on a short
  /// lived isolate. A value that cannot be sent to an isolate, for example an
  /// object whose `toJson()` result is encodable while the object itself
  /// holds a `ReceivePort`, is encoded inline instead.
  ///
  /// The value is consumed before control returns to the caller, so it can
  /// be mutated as soon as the call returns.
  @override
  Future<String> encode(Object? json) async {
    _throwIfDisposed();
    if (_remainingBudget(json, _isolateThresholdBytes, 0) >= 0) {
      return jsonEncode(json);
    }
    try {
      return await _runTracked(() => jsonEncode(json));
    } on ArgumentError {
      return jsonEncode(json);
    }
  }
}

/// Returns what is left of [budget] after subtracting an estimate of the
/// encoded size of [value], or a negative number as soon as the estimate
/// exceeds the budget.
///
/// The estimate is deliberately rough: it only has to decide whether encoding
/// inline could block the calling isolate for too long, and it must cost far
/// less than the encoding itself. Values of unrecognized types, and structures
/// nested deeper than [_maxEstimationDepth], exhaust the budget immediately so
/// they are encoded on an isolate.
///
/// Numbers are charged at their maximum textual width. Strings are charged
/// one character each, without inspecting them for characters that JSON
/// escaping expands, because such a scan would cost nearly as much as the
/// encoding itself. A string dense in escaped characters can therefore be
/// undercounted by up to a factor of six, which at worst lets a payload a few
/// times [_isolateThresholdBytes] be encoded inline.
int _remainingBudget(Object? value, int budget, int depth) {
  if (budget < 0 || depth > _maxEstimationDepth) {
    return -1;
  }
  switch (value) {
    case null:
      return budget - 4;
    case bool _:
      return budget - 5;
    case num _:
      return budget - 20;
    case String string:
      return budget - string.length - 2;
    case List<dynamic> list:
      budget -= 2;
      for (final element in list) {
        budget = _remainingBudget(element, budget, depth + 1) - 1;
        if (budget < 0) {
          return -1;
        }
      }
      return budget;
    case Map<dynamic, dynamic> map:
      budget -= 2;
      for (final entry in map.entries) {
        budget = _remainingBudget(entry.key, budget, depth + 1);
        budget = _remainingBudget(entry.value, budget, depth + 1) - 2;
        if (budget < 0) {
          return -1;
        }
      }
      return budget;
    default:
      return -1;
  }
}
