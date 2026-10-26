import 'dart:convert';
import 'dart:typed_data';

import 'async_json_codec.dart';
import 'sliced_json_encoder.dart';

final Converter<List<int>, Object?> _utf8JsonDecoder = const Utf8Decoder().fuse(
  const JsonDecoder(),
);

/// Web variant of [YAJsonIsolate].
///
/// The web platform has no isolates, so all work happens inline on the
/// calling thread. Decoding a large payload blocks it for as long as the work
/// takes, while encoding a top level list is sliced the same way as on other
/// platforms. Decoding from bytes still fuses the UTF-8 and JSON decoding
/// steps, which avoids materializing the intermediate string.
class YAJsonIsolate implements AsyncJsonCodec {
  /// Creates a codec. [debugName] is unused on web, where there are no
  /// isolates to name.
  YAJsonIsolate({
    this.debugName,
  });

  /// The debug name used for the isolates spawned by this instance on other
  /// platforms.
  final String? debugName;

  bool _isDisposed = false;

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('This YAJsonIsolate has already been disposed.');
    }
  }

  /// Dispose the instance.
  ///
  /// Safe to call more than once. Using the instance afterwards throws a
  /// [StateError].
  @override
  Future<void> dispose() {
    _isDisposed = true;
    return Future.value();
  }

  @override
  Future<dynamic> decode(String json) async {
    _throwIfDisposed();
    await null;
    return jsonDecode(json);
  }

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) {
    return Future.sync(() {
      _throwIfDisposed();
      return _utf8JsonDecoder.convert(encodedJson);
    });
  }

  @override
  Future<String> encode(Object? json) => Future.sync(() {
    _throwIfDisposed();
    return encodeJsonString(json);
  });

  @override
  Future<Uint8List> encodeBytes(Object? json) => Future.sync(() {
    _throwIfDisposed();
    return encodeJsonBytes(json);
  });
}
