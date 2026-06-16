import 'dart:convert';

class YAJsonIsolate {
  YAJsonIsolate({
    String? debugName,
  });

  // Kept returning a Future to match the IO implementation's signature.
  Future<void> initialize() => Future.value();

  Future<void> dispose() => Future.value();

  Future<dynamic> decode(String json) async {
    await null;
    return jsonDecode(json);
  }

  Future<String> encode(Object? json) async {
    await null;
    return jsonEncode(json);
  }
}
