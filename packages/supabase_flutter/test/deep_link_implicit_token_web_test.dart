@TestOn('browser')
/// The link the page was loaded with is only handled once per page, so this
/// test needs a page of its own.
library;

import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart';

import 'widget_test_stubs.dart';

void main() {
  test('the access_token of the URL the page was loaded with is ignored '
      'with the PKCE flow', () async {
    final originalUrl = window.location.href;
    addTearDown(() => window.history.replaceState(null, '', originalUrl));
    final callbackUrl = Uri.parse(originalUrl).replace(
      fragment:
          'access_token=A&refresh_token=R&expires_in=3600&token_type=bearer',
    );
    window.history.replaceState(null, '', callbackUrl.toString());
    AppLinksPlatform.instance = FakeInitialAppLinks(callbackUrl);

    final httpClient = createGetUserHttpClient('attacker@email.com');
    final supabase = await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: '',
      httpClient: httpClient,
      authOptions: FlutterAuthClientOptions(asyncStorage: MockAsyncStorage()),
    );
    addTearDown(supabase.dispose);
    final errors = <Object>[];
    final subscription = supabase.client.auth.onAuthStateChange.listen(
      (_) {},
      onError: errors.add,
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    expect(errors, isEmpty);
    expect(httpClient.requests, isEmpty);
    expect(supabase.client.auth.currentSession, isNull);
    expect(window.location.href, callbackUrl.toString());
  });
}
