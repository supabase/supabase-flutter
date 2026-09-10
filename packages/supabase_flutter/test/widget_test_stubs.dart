import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';

class MockWidget extends StatefulWidget {
  const MockWidget({super.key});

  @override
  State<MockWidget> createState() => _MockWidgetState();
}

class _MockWidgetState extends State<MockWidget> {
  bool isSignedIn = true;
  StreamSubscription<AuthState>? _authSubscription;

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
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          isSignedIn = false;
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
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

  final binaryMessenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  binaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => mockMethodChannel ? initialLink : null,
  );

  if (mockEventChannel) {
    Future<void> handleEventChannelCall(MethodCall methodCall) async {
      await binaryMessenger.handlePlatformMessage(
        eventChannel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(initialLink),
        (ByteData? data) {},
      );
    }

    binaryMessenger.setMockMethodCallHandler(
      eventChannel,
      handleEventChannelCall,
    );
  }
}

/// Answers the user endpoint with a user carrying [email].
MockSupabaseHttpClient createGetUserHttpClient(String email) =>
    MockSupabaseHttpClient()..stub(testUserJson(email: email));

class MockAsyncStorage extends MemoryAuthAsyncStorage {}

/// Answers the token endpoint of the PKCE flow with a fresh session.
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
