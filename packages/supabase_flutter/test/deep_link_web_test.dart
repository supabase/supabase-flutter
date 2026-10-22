@TestOn('browser')
library;

import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';

  test('the URL the page was loaded with is exchanged after initialize and '
      'cleared from the address bar', () async {
    final originalUrl = window.location.href;
    addTearDown(() => window.history.replaceState(null, '', originalUrl));
    final callbackUrl = Uri.parse(originalUrl).replace(
      queryParameters: {'code': 'my-code-verifier', 'tab': 'settings'},
    );
    window.history.replaceState(null, '', callbackUrl.toString());
    AppLinksPlatform.instance = _FakeAppLinks(callbackUrl);

    final httpClient = createPkceHttpClient();
    final asyncStorage = MockAsyncStorage();
    await asyncStorage.setItem(
      '${defaultPersistSessionKey(supabaseUrl)}-code-verifier',
      'raw-code-verifier',
    );

    final supabase = await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: '',
      httpClient: httpClient,
      authOptions: FlutterAuthClientOptions(asyncStorage: asyncStorage),
    );
    addTearDown(supabase.dispose);
    await supabase.client.auth.onAuthStateChange
        .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
        .timeout(const Duration(seconds: 5));
    await pumpEventQueue();

    expect(
      httpClient.requests.single.jsonBody['auth_code'],
      'my-code-verifier',
    );
    expect(Uri.parse(window.location.href).queryParameters, {
      'tab': 'settings',
    });
  });
}

/// Reports [initialLink] as the URL the page was loaded with.
class _FakeAppLinks extends AppLinksPlatform {
  _FakeAppLinks(this.initialLink);

  final Uri initialLink;

  @override
  Future<Uri?> getInitialLink() async => initialLink;
}
