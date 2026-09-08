@TestOn('!browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter_web_auth/supabase_flutter_web_auth.dart';

import 'test_stubs.dart';

void main() {
  late FakeFlutterWebAuth2 fakeWebAuth;
  late PkceHttpClient pkceHttpClient;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Ignore dispose errors
    }

    fakeWebAuth = FakeFlutterWebAuth2(
      'io.supabase.flutter://callback/?code=my-code-verifier',
    );
    FlutterWebAuth2Platform.instance = fakeWebAuth;

    pkceHttpClient = PkceHttpClient();

    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: '',
      httpClient: pkceHttpClient,
      authOptions: FlutterAuthClientOptions(
        localStorage: const MockEmptyLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
        oauthLauncher: const FlutterWebAuth2OAuthLauncher(),
      ),
    );
  });

  tearDown(() async {
    await Supabase.instance.dispose();
  });

  test(
    'signInWithOAuth runs the web auth session and exchanges the returned code',
    () async {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'io.supabase.flutter://callback',
      );

      // The authorize URL is opened in the web auth session, and the callback
      // scheme is derived from redirectTo.
      expect(fakeWebAuth.authenticatedUrl, contains('/authorize'));
      expect(fakeWebAuth.authenticatedUrl, contains('provider=github'));
      expect(fakeWebAuth.capturedCallbackUrlScheme, 'io.supabase.flutter');

      // The code from the callback URL is exchanged for a session.
      expect(pkceHttpClient.lastRequestBody['auth_code'], 'my-code-verifier');
      expect(
        Supabase.instance.client.auth.currentUser?.email,
        'fake1@email.com',
      );
    },
  );

  test(
    'preferEphemeral is forwarded to the web auth session options',
    () async {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'io.supabase.flutter://callback',
        preferEphemeral: true,
      );

      expect(fakeWebAuth.capturedOptions?['preferEphemeral'], true);
    },
  );

  test('https redirectTo forwards host and path for universal links', () async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'https://myapp.com/auth/callback',
    );

    expect(fakeWebAuth.capturedCallbackUrlScheme, 'https');
    expect(fakeWebAuth.capturedOptions?['httpsHost'], 'myapp.com');
    expect(fakeWebAuth.capturedOptions?['httpsPath'], '/auth/callback');
  });

  test(
    'signInWithOAuth without redirectTo throws on native platforms',
    () async {
      await expectLater(
        Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.github),
        throwsA(isA<AuthException>()),
      );
    },
  );
}
