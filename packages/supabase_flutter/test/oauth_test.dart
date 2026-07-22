@TestOn('!browser')

/// Tests for the native OAuth flow that runs through the system web
/// authentication session.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  late FakeFlutterWebAuth2 fakeWebAuth;
  late PkceHttpClient pkceHttpClient;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    fakeWebAuth = FakeFlutterWebAuth2(
      'io.supabase.flutter://callback/?code=my-code-verifier',
    );
    FlutterWebAuth2Platform.instance = fakeWebAuth;

    pkceHttpClient = PkceHttpClient();

    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: '',
      debug: false,
      httpClient: pkceHttpClient,
      authOptions: FlutterAuthClientOptions(
        localStorage: MockEmptyLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
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
    expect(fakeWebAuth.authenticatedUrl, contains('/auth/v1/authorize'));
    expect(fakeWebAuth.authenticatedUrl, contains('provider=github'));
    expect(fakeWebAuth.callbackUrlScheme, 'io.supabase.flutter');

    // The code from the callback URL is exchanged for a session.
    expect(pkceHttpClient.lastRequestBody['auth_code'], 'my-code-verifier');
    expect(Supabase.instance.client.auth.currentUser?.email, 'fake1@email.com');
  });

  test('preferEphemeral is forwarded to the web auth session options',
      () async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'io.supabase.flutter://callback',
      preferEphemeral: true,
    );

    expect(fakeWebAuth.options?['preferEphemeral'], true);
  });

  test('https redirectTo forwards host and path for universal links', () async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'https://myapp.com/auth/callback',
    );

    expect(fakeWebAuth.callbackUrlScheme, 'https');
    expect(fakeWebAuth.options?['httpsHost'], 'myapp.com');
    expect(fakeWebAuth.options?['httpsPath'], '/auth/callback');
  });

  test('signInWithOAuth without redirectTo throws on native platforms',
      () async {
    await expectLater(
      Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.github),
      throwsA(isA<AuthException>()),
    );
  });
}
