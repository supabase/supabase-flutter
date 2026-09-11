import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_test/supabase_test.dart';

/// Fake [FlutterWebAuth2Platform] that records the authentication request and
/// returns a preconfigured callback URL, standing in for the system web auth
/// session in tests.
class FakeFlutterWebAuth2 extends FlutterWebAuth2Platform
    with MockPlatformInterfaceMixin {
  FakeFlutterWebAuth2(this.callbackUrl);

  /// The callback URL the fake session resolves with.
  final String callbackUrl;

  String? authenticatedUrl;
  String? capturedCallbackUrlScheme;
  Map<String, dynamic>? capturedOptions;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required Map<String, dynamic> options,
  }) async {
    authenticatedUrl = url;
    capturedCallbackUrlScheme = callbackUrlScheme;
    capturedOptions = options;
    return callbackUrl;
  }

  @override
  Future<void> clearAllDanglingCalls() async {}
}

class MockAsyncStorage extends MemoryAuthAsyncStorage {}

/// A mock HTTP client that answers the PKCE token exchange with a fresh
/// session, so the code returned by the fake web auth session can be
/// exchanged.
MockSupabaseHttpClient createPkceHttpClient() =>
    MockSupabaseHttpClient()..stubHandler(
      (_) => jsonResponse(
        testSessionResponseJson(
          accessToken: signedTestJwt({
            'exp': (DateTime.now().millisecondsSinceEpoch / 1000).round() + 60,
            'sub': testUserId,
          }, secret: '37c304f8-51aa-419a-a1af-06154e63707a'),
        ),
        statusCode: 201,
      ),
    );
