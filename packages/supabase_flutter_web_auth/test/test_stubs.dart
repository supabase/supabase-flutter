import 'dart:convert';

import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:http/http.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_testing/supabase_testing.dart';

/// Fake [FlutterWebAuth2Platform] that records the authentication request and
/// returns a preconfigured callback URL, standing in for the system web auth
/// session in tests.
class FakeFlutterWebAuth2 extends FlutterWebAuth2Platform
    with MockPlatformInterfaceMixin {
  FakeFlutterWebAuth2(this.callbackUrl);

  /// The callback URL the fake session resolves with.
  final String callbackUrl;

  String? authenticatedUrl;
  String? callbackUrlScheme;
  Map<String, dynamic>? options;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required Map<String, dynamic> options,
  }) async {
    authenticatedUrl = url;
    this.callbackUrlScheme = callbackUrlScheme;
    this.options = options;
    return callbackUrl;
  }

  @override
  Future<void> clearAllDanglingCalls() async {}
}

class MockEmptyLocalStorage extends LocalStorage {
  const MockEmptyLocalStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<bool> hasAccessToken() async => false;
  @override
  Future<void> persistSession(String persistSessionString) async {}
  @override
  Future<void> removePersistedSession() async {}
}

class MockAsyncStorage extends MemoryAuthAsyncStorage {}

/// Custom HTTP client just to test the PKCE flow.
class PkceHttpClient extends BaseClient {
  int requestCount = 0;
  Map<String, dynamic> lastRequestBody = {};

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requestCount++;

    if (request is Request) {
      lastRequestBody = jsonDecode(request.body);
    }

    final accessToken = signedTestJwt({
      'exp': (DateTime.now().millisecondsSinceEpoch / 1000).round() + 60,
      'sub': testUserId,
    }, secret: '37c304f8-51aa-419a-a1af-06154e63707a');

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode(testSessionResponseJson(accessToken: accessToken)),
        ),
      ),
      201,
      request: request,
    );
  }
}
