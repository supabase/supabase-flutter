import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockWidget extends StatefulWidget {
  const MockWidget({Key? key}) : super(key: key);

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

class MockExpiredStorage extends LocalStorage {
  MockExpiredStorage()
      : super(
          initialize: () async {},

          // Session expires at is at its maximum value for unix timestamp
          accessToken: () async =>
              '{"currentSession":{"token_type": "","access_token":"","expires_in":20,"refresh_token":"","user":{"app_metadata": {},"id":"","aud":"","created_at":"","role":"authenticated","updated_at":""}},"expiresAt":${((DateTime.now().subtract(Duration(seconds: 11))).millisecondsSinceEpoch / 1000).round()}}',
          persistSession: (_) async {},
          removePersistedSession: () async {},
          hasAccessToken: () async => true,
        );
}

class MockLocalStorage extends LocalStorage {
  MockLocalStorage()
      : super(
          initialize: () async {},

          // Session expires at is at its maximum value for unix timestamp
          accessToken: () async =>
              '{"currentSession":{"token_type": "","access_token":"","expires_in":3600,"refresh_token":"","user":{"app_metadata": {},"id":"","aud":"","created_at":"","role":"authenticated","updated_at":""}},"expiresAt":2147483647}',
          persistSession: (_) async {},
          removePersistedSession: () async {},
          hasAccessToken: () async => true,
        );
}

class MockEmptyLocalStorage extends LocalStorage {
  MockEmptyLocalStorage()
      : super(
          initialize: () async {},
          accessToken: () async => null,
          persistSession: (_) async {},
          removePersistedSession: () async {},
          hasAccessToken: () async => false,
        );
}

/// Registers the mock handler for uni_links
void mockAppLink({String? initialLink}) {
  const channel = MethodChannel('com.llfbandit.app_links/messages');
  const anotherChannel = MethodChannel('com.llfbandit.app_links/events');

  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => initialLink);

  TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
      .setMockMethodCallHandler(anotherChannel, (message) async => null);
}

class MockAsyncStorage extends GotrueAsyncStorage {
  static const pkceHiveBoxName = 'supabase.pkce';

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
  int callCount = 0;
  Map<String, dynamic> lastRequestBody = {};

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    //Return custom status code to check for usage of this client.
    callCount++;
    if (request is Request) {
      lastRequestBody = jsonDecode(request.body);
    }

    final now = DateTime.now().toIso8601String();
    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode(
            {
              'id': 'ef507d02-ce6a-4b3a-a8a6-6f0e14740136',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'fake1@email.com',
              'phone': '',
              'confirmation_sent_at': now,
              'app_metadata': {
                'provider': 'email',
                'providers': ['email']
              },
              'user_metadata': {},
              'identities': [
                {
                  'id': 'ef507d02-ce6a-4b3a-a8a6-6f0e14740136',
                  'user_id': 'ef507d02-ce6a-4b3a-a8a6-6f0e14740136',
                  'identity_data': {
                    'email': 'fake1@email.com',
                    'sub': 'ef507d02-ce6a-4b3a-a8a6-6f0e14740136'
                  },
                  'provider': 'email',
                  'last_sign_in_at': now,
                  'created_at': now,
                  'updated_at': now
                }
              ],
              'created_at': now,
              'updated_at': now,
            },
          ),
        ),
      ),
      201,
      request: request,
    );
  }
}
