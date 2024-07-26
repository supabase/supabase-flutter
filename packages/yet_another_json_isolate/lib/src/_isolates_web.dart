import 'dart:convert';

class YAJsonIsolate {
  Future<void> initialize() async {}

  Future<void> dispose() async {}

  Future<dynamic> decode(String json) async {
    await null;
    return jsonDecode(json);
  }

  Future<String> encode(Object? json) async {
    await null;
    return jsonEncode(json);
  }
}
