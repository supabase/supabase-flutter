import 'dart:convert';
import 'dart:typed_data';

import 'async_json_codec.dart';

final Converter<List<int>, Object?> _utf8JsonDecoder = const Utf8Decoder().fuse(
  const JsonDecoder(),
);

/// Web variant of [YAJsonIsolate].
///
/// The web platform has no isolates, so all work happens inline. Decoding
/// from bytes still fuses the UTF-8 and JSON decoding steps, which avoids
/// materializing the intermediate string.
class YAJsonIsolate implements AsyncJsonCodec {
  const YAJsonIsolate({
    String? debugName,
  });

  Future<void> initialize() => Future.value();

  @override
  Future<void> dispose() => Future.value();

  @override
  Future<dynamic> decode(String json) async {
    await null;
    return jsonDecode(json);
  }

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) {
    return Future.sync(() => _utf8JsonDecoder.convert(encodedJson));
  }

  @override
  Future<String> encode(Object? json) async {
    await null;
    return jsonEncode(json);
  }
}
