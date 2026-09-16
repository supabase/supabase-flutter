import 'dart:convert';

import 'package:supabase_auth/src/types/app_metadata.dart';
import 'package:test/test.dart';

void main() {
  group('AppMetadata', () {
    test('parses the provider fields and keeps the other keys', () {
      final metadata = AppMetadata.fromJson({
        'provider': 'google',
        'providers': ['google', 'email'],
        'roles': ['admin'],
        'tenant': 'acme',
      });

      expect(metadata.provider, 'google');
      expect(metadata.providers, ['google', 'email']);
      expect(metadata['provider'], 'google');
      expect(metadata['providers'], ['google', 'email']);
      expect(metadata['roles'], ['admin']);
      expect(metadata['tenant'], 'acme');
      expect(metadata['missing'], isNull);
    });

    test('parses an empty object', () {
      final metadata = AppMetadata.fromJson({});

      expect(metadata.provider, isNull);
      expect(metadata.providers, isEmpty);
      expect(metadata.toJson(), isEmpty);
    });

    test('is unmodifiable after parsing', () {
      final metadata = AppMetadata.fromJson({
        'providers': ['email'],
      });

      expect(() => metadata.providers.add('google'), throwsUnsupportedError);
    });

    test('round-trips through JSON', () {
      final json = {
        'provider': 'email',
        'providers': ['email', 'google'],
        'nested': {'deep': 'value'},
      };

      final restored = AppMetadata.fromJson(
        jsonDecode(jsonEncode(AppMetadata.fromJson(json).toJson()))
            as Map<String, dynamic>,
      );

      expect(restored.toJson(), json);
      expect(restored, AppMetadata.fromJson(json));
    });

    test('omits the provider keys the server did not send', () {
      const metadata = AppMetadata(additionalProperties: {'tenant': 'acme'});

      expect(metadata.toJson(), {'tenant': 'acme'});
    });

    test('compares by value', () {
      const first = AppMetadata(
        provider: 'email',
        providers: ['email'],
        additionalProperties: {
          'roles': ['admin'],
        },
      );
      const second = AppMetadata(
        provider: 'email',
        providers: ['email'],
        additionalProperties: {
          'roles': ['admin'],
        },
      );
      const different = AppMetadata(provider: 'google', providers: ['google']);

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
      expect(first, isNot(equals(different)));
    });

    test('toString includes the serialized map', () {
      const metadata = AppMetadata(provider: 'email');

      expect(metadata.toString(), 'AppMetadata({provider: email})');
    });
  });
}
