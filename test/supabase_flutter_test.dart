import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';
  group("Valid session", () {
    setUp(() async {
      mockAppLink();
      // Initialize the Supabase singleton
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        localStorage: MockLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      );
    });

    tearDown(() => Supabase.instance.dispose());

    test('can access Supabase singleton', () async {
      final client = Supabase.instance.client;
      await expectLater(
          await SupabaseAuth.instance.initialSession, isA<Session>());
      expect(client, isNotNull);
    });

    test('can re-initialize client', () async {
      final client = Supabase.instance.client;
      Supabase.instance.dispose();
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        localStorage: MockLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      );

      final newClient = Supabase.instance.client;
      expect(client, isNot(newClient));
    });
  });

  group("Expired session", () {
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        localStorage: MockExpiredStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      );
    });

    tearDown(() => Supabase.instance.dispose());

    test('initial session contains the error', () async {
      await expectLater(
          SupabaseAuth.instance.initialSession, throwsA(isA<AuthException>()));
    });
  });

  group('Deep Link with PKCE code', () {
    late final PkceHttpClient customHttpClient;
    setUp(() async {
      customHttpClient = PkceHttpClient();
      mockAppLink(
        initialLink: 'com.supabase://callback/?code=my-code-verifier',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        authFlowType: AuthFlowType.pkce,
        httpClient: customHttpClient,
        localStorage: MockEmptyLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      );
    });

    tearDown(() => Supabase.instance.dispose());

    test(
        'Having `code` as the query parameter triggers `getSessionFromUrl` call on initialize',
        () async {
      expect(customHttpClient.callCount, 1);
      expect(customHttpClient.lastRequestBody['auth_code'], 'my-code-verifier');
    });
  });
}
