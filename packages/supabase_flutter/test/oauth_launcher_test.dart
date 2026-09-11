import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

/// Fake [OAuthLauncher] that records the arguments it was called with instead
/// of launching a browser.
class FakeOAuthLauncher extends OAuthLauncher {
  AuthClient? lastClient;
  Uri? lastUrl;
  OAuthProvider? lastProvider;
  Uri? lastRedirectTo;
  LaunchMode? lastLaunchMode;
  bool? lastPreferEphemeral;

  @override
  Future<bool> launch(
    AuthClient client,
    Uri url, {
    required OAuthProvider? provider,
    required Uri? redirectTo,
    required LaunchMode launchMode,
    bool preferEphemeral = false,
  }) async {
    lastClient = client;
    lastUrl = url;
    lastProvider = provider;
    lastRedirectTo = redirectTo;
    lastLaunchMode = launchMode;
    lastPreferEphemeral = preferEphemeral;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeOAuthLauncher fakeLauncher;

  setUp(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Ignore dispose errors
    }

    mockAppLink();
    fakeLauncher = FakeOAuthLauncher();

    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: '',
      authOptions: FlutterAuthClientOptions(
        asyncStorage: MockAsyncStorage(),
        oauthLauncher: fakeLauncher,
      ),
    );
  });

  tearDown(() async {
    await Supabase.instance.dispose();
  });

  test(
    'signInWithOAuth delegates to the configured OAuthLauncher',
    () async {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'io.supabase.flutter://callback',
        preferEphemeral: true,
      );

      expect(fakeLauncher.lastClient, Supabase.instance.client.auth);
      expect(fakeLauncher.lastUrl?.queryParameters['provider'], 'github');
      expect(fakeLauncher.lastProvider, OAuthProvider.github);
      expect(
        fakeLauncher.lastRedirectTo,
        Uri.parse('io.supabase.flutter://callback'),
      );
      expect(fakeLauncher.lastLaunchMode, LaunchMode.platformDefault);
      expect(fakeLauncher.lastPreferEphemeral, isTrue);
    },
  );

  test(
    'signInWithOAuth with no redirectTo passes a null redirectTo through',
    () async {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github,
      );

      expect(fakeLauncher.lastRedirectTo, isNull);
      expect(fakeLauncher.lastPreferEphemeral, isFalse);
    },
  );
}
