import 'dart:convert';

class YAJsonIsolate {
  const YAJsonIsolate({
    String? debugName,
  });

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
