import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// A device clock that differs from the server's must not change when the
/// session expires, since the access token's lifetime is counted from the
/// time the device received it.
void main() {
  const authUrl = 'http://localhost:9999';
  final storageKey = defaultPersistSessionKey(authUrl);
  final serverNow = DateTime.utc(2030);
  const lifetime = Duration(hours: 1);

  late MockSupabaseHttpClient httpClient;
  late TestAsyncStorage storage;
  late DateTime deviceNow;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    storage = TestAsyncStorage();
  });

  /// A token response issued at [serverNow], which expires [lifetime] later
  /// on the server's clock.
  Map<String, dynamic> sessionResponse() => testSessionResponseJson(
    accessToken: unsignedTestJwt({
      'exp': unixSecondsFromDateTime(serverNow.add(lifetime)),
      'sub': testUserId,
      'role': 'authenticated',
    }),
    expiresIn: lifetime.inSeconds,
  );

  void stubToken() {
    httpClient.stub(
      sessionResponse(),
      method: HttpMethod.post,
      path: '/token',
      headers: {'x-sb-api-version': '2024-01-01'},
    );
  }

  int tokenRequests() => httpClient.requestsTo('/token').length;

  Future<T> onDevice<T>(Future<T> Function(AuthClient client) body) {
    return withClock(Clock(() => deviceNow), () async {
      final client = AuthClient(
        url: authUrl,
        asyncStorage: storage,
        httpClient: httpClient,
        persistSession: true,
        autoRefreshToken: false,
      );
      addTearDown(client.dispose);
      await client.initialized;
      return body(client);
    });
  }

  Future<void> autoRefreshTick(AuthClient client) async {
    client.startAutoRefresh();
    await pumpEventQueue();
    client.stopAutoRefresh();
  }

  for (final (description, skew) in [
    ('ahead of', const Duration(hours: 2)),
    ('behind', -const Duration(hours: 2)),
  ]) {
    group('a device clock two hours $description the server', () {
      setUp(() {
        deviceNow = serverNow.add(skew);
        stubToken();
      });

      test('keeps a new session without refreshing it', () async {
        await onDevice((client) async {
          await client.signInWithPassword(
            email: 'fake1@email.com',
            password: 'password',
          );

          for (var i = 0; i < 5; i++) {
            final session = await client.getSession();
            expect(session?.isExpired, isFalse);
          }
          await autoRefreshTick(client);

          expect(tokenRequests(), 1);
        });
      });

      test('refreshes once the lifetime has passed on the device', () async {
        await onDevice((client) async {
          await client.signInWithPassword(
            email: 'fake1@email.com',
            password: 'password',
          );

          deviceNow = deviceNow.add(lifetime - const Duration(seconds: 31));
          await client.getSession();
          expect(tokenRequests(), 1);

          deviceNow = deviceNow.add(const Duration(seconds: 2));
          await client.getSession();
          await client.getSession();
          expect(tokenRequests(), 2);
        });
      });

      test('keeps a session restored from storage', () async {
        await onDevice((client) async {
          await client.signInWithPassword(
            email: 'fake1@email.com',
            password: 'password',
          );
          await pumpEventQueue();
        });
        deviceNow = deviceNow.add(const Duration(minutes: 10));

        await onDevice((client) async {
          expect(client.currentSession?.isExpired, isFalse);
          await client.getSession();
          await autoRefreshTick(client);
        });

        expect(tokenRequests(), 1);
      });
    });
  }

  test('a session stored without its receipt time refreshes once', () async {
    deviceNow = serverNow.add(const Duration(hours: 2));
    stubToken();
    final legacy = Map<String, dynamic>.of(sessionResponse())
      ..['expires_at'] = unixSecondsFromDateTime(serverNow.add(lifetime));
    await storage.setItem(storageKey, jsonEncode(legacy));

    await onDevice((client) async {
      await client.getSession();
      await pumpEventQueue();
      expect(tokenRequests(), 1);

      final stored = jsonDecode((await storage.getItem(storageKey))!);
      expect(stored['received_at'], deviceNow.millisecondsSinceEpoch);
      await client.getSession();
      await autoRefreshTick(client);
    });

    expect(tokenRequests(), 1);
  });
}
