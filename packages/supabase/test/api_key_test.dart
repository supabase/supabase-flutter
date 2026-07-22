import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:supabase/src/api_key.dart';
import 'package:supabase/src/auth_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('isNewApiKey', () {
    test('detects publishable and secret keys', () {
      expect(isNewApiKey('sb_publishable_abc123'), isTrue);
      expect(isNewApiKey('sb_secret_abc123'), isTrue);
    });

    test('legacy JWT and anon keys are not new format', () {
      expect(isNewApiKey('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'), isFalse);
      expect(isNewApiKey('anon-key'), isFalse);
      expect(isNewApiKey('sb_something'), isFalse);
    });
  });

  group('warnOnUnrecognizedApiKey', () {
    test('warns once per unrecognized sb_ subtype without logging the key', () {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      final log = Logger('test.api_key');

      warnOnUnrecognizedApiKey('sb_weirdtype_supersecretvalue', log);
      warnOnUnrecognizedApiKey('sb_weirdtype_anothersecretvalue', log);

      unawaited(subscription.cancel());

      expect(records, hasLength(1));
      expect(records.first.level, Level.WARNING);
      expect(records.first.message, isNot(contains('weirdtype')));
      expect(records.first.message, isNot(contains('supersecretvalue')));
    });

    test('does not log the key when there is no second underscore', () {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      final log = Logger('test.api_key');

      warnOnUnrecognizedApiKey('sb_sensitivevalue', log);

      unawaited(subscription.cancel());

      expect(records, hasLength(1));
      expect(records.first.level, Level.WARNING);
      expect(records.first.message, isNot(contains('sensitivevalue')));
    });

    test('does not warn on recognized or legacy keys', () {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      final log = Logger('test.api_key');

      warnOnUnrecognizedApiKey('sb_publishable_abc', log);
      warnOnUnrecognizedApiKey('sb_secret_abc', log);
      warnOnUnrecognizedApiKey('eyJhbGciOiJIUzI1NiJ9', log);

      unawaited(subscription.cancel());

      expect(records, isEmpty);
    });
  });

  group('AuthHttpClient bearer suppression', () {
    late Map<String, String> capturedHeaders;

    http.Client buildClient({
      required String key,
      required String? session,
      required bool omitNewApiKeyAsBearer,
    }) {
      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response('', 200);
      });
      return AuthHttpClient(
        key,
        mockClient,
        () async => session,
        omitNewApiKeyAsBearer: omitNewApiKeyAsBearer,
      );
    }

    test('omits new-format key as Bearer when there is no session', () async {
      final client = buildClient(
        key: 'sb_publishable_abc',
        session: null,
        omitNewApiKeyAsBearer: true,
      );
      await client.get(Uri.parse('https://example.com'));

      expect(capturedHeaders.containsKey('authorization'), isFalse);
      expect(capturedHeaders['apikey'], 'sb_publishable_abc');
    });

    test('sends session JWT as Bearer even with a new-format key', () async {
      final client = buildClient(
        key: 'sb_publishable_abc',
        session: 'jwt-token',
        omitNewApiKeyAsBearer: true,
      );
      await client.get(Uri.parse('https://example.com'));

      expect(capturedHeaders['authorization'], 'Bearer jwt-token');
      expect(capturedHeaders['apikey'], 'sb_publishable_abc');
    });

    test('sends legacy key as Bearer when there is no session', () async {
      final client = buildClient(
        key: 'legacy-anon-key',
        session: null,
        omitNewApiKeyAsBearer: true,
      );
      await client.get(Uri.parse('https://example.com'));

      expect(capturedHeaders['authorization'], 'Bearer legacy-anon-key');
    });

    test(
      'without the flag, a new-format key is still sent as Bearer',
      () async {
        final client = buildClient(
          key: 'sb_publishable_abc',
          session: null,
          omitNewApiKeyAsBearer: false,
        );
        await client.get(Uri.parse('https://example.com'));

        expect(capturedHeaders['authorization'], 'Bearer sb_publishable_abc');
      },
    );
  });
}
