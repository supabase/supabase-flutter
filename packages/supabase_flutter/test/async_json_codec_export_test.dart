import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InlineJsonCodec implements AsyncJsonCodec {
  @override
  Future<dynamic> decode(String json) async => jsonDecode(json);

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) async =>
      jsonDecode(utf8.decode(encodedJson));

  @override
  Future<String> encode(Object? json) async => jsonEncode(json);

  @override
  Future<void> dispose() async {}
}

void main() {
  test(
    'AsyncJsonCodec is implementable through the supabase_flutter export',
    () async {
      final AsyncJsonCodec jsonCodec = _InlineJsonCodec();
      final client = FunctionsClient(
        'https://example.com',
        const {},
        jsonCodec: jsonCodec,
      );
      addTearDown(client.dispose);

      expect(await jsonCodec.encode({'a': 1}), '{"a":1}');
    },
  );
}
