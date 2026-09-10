import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('AuthClient.mfa.enroll', () {
    late MockSupabaseHttpClient http;
    late AuthClient client;

    setUp(() {
      // A minimal enroll payload, so the call the test inspects succeeds.
      http = MockSupabaseHttpClient()
        ..stub({
          'id': '3f1e2d4c-1111-2222-3333-444455556666',
          'type': 'totp',
          'totp': {
            'qr_code': 'svg',
            'secret': 'ABC123',
            'uri': 'otpauth://totp/Example?secret=ABC123',
          },
        });
      client = AuthClient(
        url: 'http://localhost',
        headers: {'apikey': 'anon-key'},
        httpClient: http,
        asyncStorage: TestAsyncStorage(),
      );
    });

    test('a TOTP factor enrolls without an issuer', () async {
      // `issuer` is optional for TOTP, so this must reach the network instead
      // of throwing ArgumentError before the request is sent.
      await client.mfa.enroll();

      expect(
        (http.requests.single.jsonBody as Map).containsKey('issuer'),
        isFalse,
      );
      expect(http.requests.single.jsonBody['factor_type'], 'totp');
    });

    test('a TOTP factor forwards the issuer when provided', () async {
      await client.mfa.enroll(issuer: 'MyApp');

      expect(http.requests.single.jsonBody['issuer'], 'MyApp');
    });

    test('a phone factor still requires a phone number', () async {
      expect(
        () => client.mfa.enroll(factorType: FactorType.phone),
        throwsArgumentError,
      );
    });

    test(
      'a webauthn factor is rejected instead of reaching the network',
      () async {
        expect(
          () => client.mfa.enroll(factorType: FactorType.webauthn),
          throwsArgumentError,
        );
        expect(http.requests, isEmpty);
      },
    );
  });
}
