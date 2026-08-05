import 'dart:async';
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:http/http.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';

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
            onPressed: () {
              unawaited(
                Supabase.instance.client.auth.signOut().catchError((_) {}),
              );
            },
            child: const Text('Sign out'),
          )
        : const Text('You have signed out');
  }

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          isSignedIn = false;
        });
      }
    });
  }
}

/// Local storage that returns an expired session
class MockExpiredStorage extends LocalStorage {
  const MockExpiredStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async {
    return getSessionData(
      DateTime.now().subtract(const Duration(hours: 1)),
    ).sessionString;
  }

  @override
  Future<bool> hasAccessToken() async => true;
  @override
  Future<void> persistSession(String persistSessionString) async {}
  @override
  Future<void> removePersistedSession() async {}
}

class MockLocalStorage extends LocalStorage {
  const MockLocalStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async {
    return getSessionData(
      DateTime.now().add(const Duration(hours: 1)),
    ).sessionString;
  }

  @override
  Future<bool> hasAccessToken() async => true;
  @override
  Future<void> persistSession(String persistSessionString) async {}
  @override
  Future<void> removePersistedSession() async {}
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
        channel,
        (call) async => mockMethodChannel ? initialLink : null,
      );

  // Mock event channel using method channel, to keep supporting older versions
  // of flutter_test in which setMockStreamHandler is not yet available.
  if (mockEventChannel) {
    // ignore: invalid_null_aware_operator
    TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
        .setMockMethodCallHandler(
          eventChannel,
          // ignore: function-always-returns-null
          (MethodCall methodCall) async {
            await TestDefaultBinaryMessengerBinding
                .instance
                // ignore: invalid_null_aware_operator
                ?.defaultBinaryMessenger
                .handlePlatformMessage(
                  eventChannel.name,
                  const StandardMethodCodec().encodeSuccessEnvelope(
                    initialLink,
                  ),
                  (ByteData? data) {},
                );
            return null;
          },
        );
  }
}

class GetUserHttpClient extends BaseClient {
  GetUserHttpClient(this.email);

  final String email;
  int requestCount = 0;
  Uri? lastRequestUrl;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requestCount++;
    lastRequestUrl = request.url;

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode(
            {
              'id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
              'aud': '',
              'role': '',
              'email': email,
              'app_metadata': {
                'provider': 'email',
                'providers': ['email'],
              },
              'user_metadata': {},
              'created_at': '2023-04-01T09:38:59.784028Z',
              'updated_at': '2023-04-01T09:38:59.908816Z',
            },
          ),
        ),
      ),
      200,
      request: request,
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
                  'providers': ['email'],
                },
                'user_metadata': {},
                'factors': [
                  {
                    'id': '1d3aa138-da96-4aea-8217-af07daa6b82d',
                    'created_at': '2023-04-01T09:38:59.784028Z',
                    'updated_at': '2023-04-01T09:38:59.784028Z',
                    'status': 'unverified',
                    'friendly_name': 'UnverifiedFactor',
                    'factor_type': 'totp',
                  },
                ],
                'identities': [
                  {
                    'id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                    'user_id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                    'identity_data': {
                      'email': 'fake1@email.com',
                      'sub': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                    },
                    'provider': 'email',
                    'last_sign_in_at': '2023-04-01T09:38:59.784028Z',
                    'created_at': '2023-04-01T09:38:59.784028Z',
                    'updated_at': '2023-04-01T09:38:59.784028Z',
                  },
                ],
                'created_at': '2023-04-01T09:38:59.784028Z',
                'updated_at': '2023-04-01T09:38:59.908816Z',
              },
            },
          ),
        ),
      ),
      201,
      request: request,
    );
  }
}
