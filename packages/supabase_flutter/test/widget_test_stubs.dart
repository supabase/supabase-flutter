import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';

class MockWidget extends StatefulWidget {
  const MockWidget({super.key});

  @override
  State<MockWidget> createState() => _MockWidgetState();
}

class _MockWidgetState extends State<MockWidget> {
  bool isSignedIn = true;

  @override
  Widget build(BuildContext context) {
    return isSignedIn
        ? TextButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
            },
            child: const Text('Sign out'),
          )
        : const Text('You have signed out');
  }

  @override
  void initState() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          isSignedIn = false;
        });
      }
    });
    super.initState();
  }
}

/// Local storage that returns an expired session
class MockExpiredStorage extends LocalStorage {
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async {
    return getSessionData(DateTime.now().subtract(const Duration(hours: 1)))
        .sessionString;
  }

  @override
  Future<bool> hasAccessToken() async => true;
  @override
  Future<void> persistSession(String persistSessionString) async {}
  @override
  Future<void> removePersistedSession() async {}
}

class MockLocalStorage extends LocalStorage {
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async {
    return getSessionData(DateTime.now().add(const Duration(hours: 1)))
        .sessionString;
  }

  @override
  Future<bool> hasAccessToken() async => true;
  @override
  Future<void> persistSession(String persistSessionString) async {}
  @override
  Future<void> removePersistedSession() async {}
}

class MockEmptyLocalStorage extends LocalStorage {
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

/// Registers the mock handler for app_links
///
/// Returns the [EventChannel] used to mock the incoming links.
void mockAppLink({
  bool mockMethodChannel = false,
  bool mockEventChannel = false,
  String? initialLink,
}) {
  const channel = MethodChannel('com.llfbandit.app_links/messages');
  const eventChannel = MethodChannel('com.llfbandit.app_links/events');

  TestWidgetsFlutterBinding.ensureInitialized();

  // ignore: invalid_null_aware_operator
  TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
      .setMockMethodCallHandler(
          channel, (call) async => mockMethodChannel ? initialLink : null);

  // Mock event channel using method channel, to keep supporting older versions
  // of flutter_test in which setMockStreamHandler is not yet available.
  if (mockEventChannel) {
    // ignore: invalid_null_aware_operator
    TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
        .setMockMethodCallHandler(
      eventChannel,
      (MethodCall methodCall) async {
        // ignore: invalid_null_aware_operator
        TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
            .handlePlatformMessage(
          eventChannel.name,
          const StandardMethodCodec().encodeSuccessEnvelope(initialLink),
          (ByteData? data) {},
        );
        return null;
      },
    );
  }
}

class MockAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> getItem({required String key}) async {
    return _map[key];
  }

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}

/// Custom HTTP client just to test the SSO flow.
class MockSSOHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final uri = request.url;

    // Mock SSO response
    if (uri.path.contains('/sso')) {
      String domain = '';
      String providerId = '';
      String redirectTo = '';

      // Extract parameters from request body if it's a POST request
      if (request is Request && request.body.isNotEmpty) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        domain = body['domain'] ?? '';
        providerId = body['provider_id'] ?? '';
        redirectTo = body['redirect_to'] ?? '';
      }

      // Construct a mock SSO URL with all parameters
      var ssoUrl = 'https://test.supabase.co/auth/v1/sso?';
      if (domain.isNotEmpty) {
        ssoUrl += 'domain=$domain&';
      }
      if (providerId.isNotEmpty) {
        ssoUrl += 'provider_id=$providerId&';
      }
      if (redirectTo.isNotEmpty) {
        ssoUrl += 'redirect_to=${Uri.encodeComponent(redirectTo)}&';
      }
      // Remove trailing & if present
      if (ssoUrl.endsWith('&')) {
        ssoUrl = ssoUrl.substring(0, ssoUrl.length - 1);
      }

      return StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({'url': ssoUrl}),
          ),
        ),
        200,
      );
    }

    // Default response for other requests
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({}))),
      200,
    );
  }
}

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

    final jwt = JWT(
      {'exp': (DateTime.now().millisecondsSinceEpoch / 1000).round() + 60},
      subject: '18bc7a4e-c095-4573-93dc-e0be29bada97',
    );

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode(
            {
              'access_token': jwt.sign(
                SecretKey('37c304f8-51aa-419a-a1af-06154e63707a'),
              ),
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'tDoDnvj5MKLuZOQ65KyVfQ',
              'user': {
                'id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                'aud': '',
                'role': '',
                'email': 'fake1@email.com',
                'email_confirmed_at': '2023-04-01T09:38:59.784028Z',
                'phone': '166600000000',
                'phone_confirmed_at': '2023-04-01T09:38:59.784028Z',
                'confirmed_at': '2023-04-01T09:38:59.784028Z',
                'last_sign_in_at': '2023-04-01T09:38:59.904492805Z',
                'app_metadata': {
                  'provider': 'email',
                  'providers': ['email']
                },
                'user_metadata': {},
                'factors': [
                  {
                    'id': '1d3aa138-da96-4aea-8217-af07daa6b82d',
                    'created_at': '2023-04-01T09:38:59.784028Z',
                    'updated_at': '2023-04-01T09:38:59.784028Z',
                    'status': 'unverified',
                    'friendly_name': 'UnverifiedFactor',
                    'factor_type': 'totp'
                  }
                ],
                'identities': [
                  {
                    'id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                    'user_id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                    'identity_data': {
                      'email': 'fake1@email.com',
                      'sub': '18bc7a4e-c095-4573-93dc-e0be29bada97'
                    },
                    'provider': 'email',
                    'last_sign_in_at': '2023-04-01T09:38:59.784028Z',
                    'created_at': '2023-04-01T09:38:59.784028Z',
                    'updated_at': '2023-04-01T09:38:59.784028Z'
                  }
                ],
                'created_at': '2023-04-01T09:38:59.784028Z',
                'updated_at': '2023-04-01T09:38:59.908816Z'
              }
            },
          ),
        ),
      ),
      201,
      request: request,
    );
  }
}

/// Custom HTTP client to test OAuth and SSO flows.
class MockOAuthHttpClient extends BaseClient {
  int requestCount = 0;
  Map<String, dynamic> lastRequestBody = {};
  String? lastRequestUrl;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requestCount++;
    lastRequestUrl = request.url.toString();

    if (request is Request) {
      if (request.body.isNotEmpty) {
        lastRequestBody = jsonDecode(request.body);
      }
    }

    // Handle OAuth authorize endpoint
    if (request.url.path.endsWith('/authorize')) {
      final queryParams = request.url.queryParameters;
      final provider = queryParams['provider'] ?? '';
      final redirectTo = queryParams['redirect_to'] ?? '';
      final scopes = queryParams['scopes'] ?? '';

      final responseUrl =
          'https://test.supabase.co/auth/v1/authorize?provider=$provider&redirect_to=${Uri.encodeComponent(redirectTo)}&scopes=${Uri.encodeComponent(scopes)}';

      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'url': responseUrl}))),
        200,
        request: request,
      );
    }

    // Handle SSO endpoint
    if (request.url.path.endsWith('/sso')) {
      final body = lastRequestBody;
      final domain = body['domain'] ?? '';
      final providerId = body['provider_id'] ?? '';
      final redirectTo = body['redirect_to'] ?? '';

      var responseUrl = 'https://test.supabase.co/auth/v1/sso?';
      if (providerId.isNotEmpty) {
        responseUrl += 'provider_id=${Uri.encodeComponent(providerId)}';
      } else if (domain.isNotEmpty) {
        responseUrl += 'domain=${Uri.encodeComponent(domain)}';
      }
      if (redirectTo.isNotEmpty) {
        responseUrl += '&redirect_to=${Uri.encodeComponent(redirectTo)}';
      }

      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'url': responseUrl}))),
        200,
        request: request,
      );
    }

    // Default response for other endpoints
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({}))),
      200,
      request: request,
    );
  }
}
