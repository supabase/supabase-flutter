import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'utils.dart';
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
  late MockSupabaseHttpClient httpClient;

  setUp(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Ignore dispose errors
    }

    mockAppLink();
    fakeLauncher = FakeOAuthLauncher();
    httpClient = MockSupabaseHttpClient();

    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: '',
      httpClient: httpClient,
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

  test('signInWithSSO delegates to the configured OAuthLauncher', () async {
    httpClient.stub({
      'url': 'https://idp.example.com/sso',
    }, path: '/auth/v1/sso');

    final launched = await Supabase.instance.client.auth.signInWithSSO(
      domain: 'company.com',
      redirectTo: 'io.supabase.flutter://callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
      preferEphemeral: true,
    );

    expect(launched, isTrue);
    expect(
      httpClient.requestsTo('/auth/v1/sso').single.jsonBody['domain'],
      'company.com',
    );
    expect(fakeLauncher.lastUrl, Uri.parse('https://idp.example.com/sso'));
    expect(fakeLauncher.lastProvider, isNull);
    expect(
      fakeLauncher.lastRedirectTo,
      Uri.parse('io.supabase.flutter://callback'),
    );
    expect(fakeLauncher.lastLaunchMode, LaunchMode.externalApplication);
    expect(fakeLauncher.lastPreferEphemeral, isTrue);
  });

  test('linkIdentity delegates to the configured OAuthLauncher', () async {
    await signInTestUser(Supabase.instance.client.auth);
    httpClient.stub({
      'url': 'https://github.com/login/oauth/authorize',
    }, path: '/auth/v1/user/identities/authorize');

    final launched = await Supabase.instance.client.auth.linkIdentity(
      OAuthProvider.github,
      redirectTo: 'io.supabase.flutter://callback',
      authScreenLaunchMode: LaunchMode.inAppBrowserView,
    );

    expect(launched, isTrue);
    expect(
      httpClient
          .requestsTo('/auth/v1/user/identities/authorize')
          .single
          .url
          .queryParameters['provider'],
      'github',
    );
    expect(
      fakeLauncher.lastUrl,
      Uri.parse('https://github.com/login/oauth/authorize'),
    );
    expect(fakeLauncher.lastProvider, OAuthProvider.github);
    expect(fakeLauncher.lastLaunchMode, LaunchMode.inAppBrowserView);
  });

  group('UrlLauncherOAuthLauncher', () {
    late _FakeUrlLauncher urlLauncher;

    setUp(() {
      urlLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = urlLauncher;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    Future<void> launch(OAuthProvider provider) async {
      await const UrlLauncherOAuthLauncher().launch(
        Supabase.instance.client.auth,
        Uri.parse('https://test.supabase.co/auth/v1/authorize'),
        provider: provider,
        redirectTo: null,
        launchMode: LaunchMode.inAppWebView,
      );
    }

    test('opens Google sign-in in an external browser on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await launch(OAuthProvider.google);

      expect(
        urlLauncher.lastOptions?.mode,
        PreferredLaunchMode.externalApplication,
      );
    }, skip: kIsWeb ? 'The rule only applies to native Android' : false);

    test('keeps the launch mode of other providers on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await launch(OAuthProvider.github);

      expect(urlLauncher.lastOptions?.mode, PreferredLaunchMode.inAppWebView);
    });

    test('keeps the launch mode of Google sign-in on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await launch(OAuthProvider.google);

      expect(urlLauncher.lastOptions?.mode, PreferredLaunchMode.inAppWebView);
    });
  });
}

/// Records the launch instead of opening a browser.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  LaunchOptions? lastOptions;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastOptions = options;
    return true;
  }
}
