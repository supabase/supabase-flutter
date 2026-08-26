import 'dart:typed_data';

/// Encodes and decodes JSON asynchronously, so that a large payload does not
/// block the calling isolate for long.
///
/// `YAJsonIsolate` is the implementation the Supabase clients use when none is
/// supplied. Implement this interface to route their JSON work somewhere else,
/// for example through a native parser or through an instrumented wrapper that
/// records how long each payload takes.
///
/// Every method is asynchronous even when an implementation does the work
/// inline, so that a caller cannot come to depend on the work happening
/// synchronously.
abstract interface class AsyncJsonCodec {
  /// Decodes [json] into Dart values, like `jsonDecode`.
  Future<dynamic> decode(String json);

  /// Decodes UTF-8 encoded JSON in [encodedJson] into Dart values.
  ///
  /// Preferred by the clients over [decode] when the payload is available as
  /// bytes, such as an HTTP response body, because it avoids materializing the
  /// intermediate string.
  ///
  /// An implementation must read the bytes before returning control to the
  /// caller, which is free to reuse the buffer as soon as the call returns.
  Future<dynamic> decodeBytes(Uint8List encodedJson);

  /// Encodes [json] into a JSON string, like `jsonEncode`.
  ///
  /// An implementation must consume the value before returning control to the
  /// caller, which is free to mutate it as soon as the call returns.
  Future<String> encode(Object? json);

  /// Releases whatever the codec holds.
  ///
  /// A client only disposes a codec it created itself. One that is passed to a
  /// client stays owned by whoever created it, and can be shared between
  /// clients and disposed once they are all done with it.
  Future<void> dispose();
}
