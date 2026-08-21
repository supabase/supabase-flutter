import 'dart:convert';
import 'dart:typed_data';

import 'package:postgrest/postgrest.dart';
import 'package:supabase_testing/supabase_testing.dart';
import 'package:test/test.dart';

void main() {
  group('jsonCodec', () {
    test('decodes responses through a supplied codec', () async {
      final jsonCodec = _RecordingJsonCodec();
      final postgrest = PostgrestClient(
        'https://example.com',
        httpClient: JsonResponseMockClient(
          body: [
            {'id': 1},
          ],
        ),
        jsonCodec: jsonCodec,
      );
      addTearDown(postgrest.dispose);

      final response = await postgrest.from('users').select();

      expect(response, [
        {'id': 1},
      ]);
      expect(jsonCodec.decodedPayloads, 1);
    });

    test('leaves a supplied codec for the caller to dispose', () async {
      final jsonCodec = _RecordingJsonCodec();
      final postgrest = PostgrestClient(
        'https://example.com',
        httpClient: JsonResponseMockClient(body: const []),
        jsonCodec: jsonCodec,
      );

      await postgrest.dispose();

      expect(jsonCodec.isDisposed, isFalse);
      expect(await postgrest.from('users').select(), isEmpty);
    });

    test('disposes the codec it created for itself', () async {
      final postgrest = PostgrestClient(
        'https://example.com',
        httpClient: JsonResponseMockClient(body: const []),
      );

      await postgrest.dispose();

      await expectLater(
        () => postgrest.from('users').select(),
        throwsStateError,
      );
    });
  });
}

/// An [AsyncJsonCodec] that works inline and records what it was asked to
/// process, so a test can assert that the client routes its JSON through the
/// codec it was given and leaves its disposal to the caller.
class _RecordingJsonCodec implements AsyncJsonCodec {
  final List<Object?> encodedValues = [];
  int decodedPayloads = 0;
  bool isDisposed = false;

  @override
  Future<dynamic> decode(String json) async {
    decodedPayloads++;
    return jsonDecode(json);
  }

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) async {
    decodedPayloads++;
    return jsonDecode(utf8.decode(encodedJson));
  }

  @override
  Future<String> encode(Object? json) async {
    encodedValues.add(json);
    return jsonEncode(json);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}
