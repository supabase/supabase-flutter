import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final env = DotEnv();
  env.load();

  final authUrl = getAuthUrl(env);
  final anonToken = getAnonToken(env);
  final storageKey = defaultPersistSessionKey(authUrl);

  late TestAsyncStorage storage;

  AuthClient createClient({
    bool persistSession = true,
    String? storageKey,
    bool autoRefreshToken = true,
  }) {
    final client = AuthClient(
      url: authUrl,
      headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
      asyncStorage: storage,
      persistSession: persistSession,
      storageKey: storageKey,
      autoRefreshToken: autoRefreshToken,
      flowType: AuthFlowType.implicit,
    );
    addTearDown(client.dispose);
    return client;
  }

  /// Lets the queued storage writes of the client run.
  Future<void> settle() => Future.delayed(Duration.zero);

  setUp(() async {
    final response = await http.post(
      Uri.parse(resetAuthDataUrl),
      headers: {
        'x-forwarded-for': '127.0.0.1',
        'apikey': getServiceRoleToken(env),
        'Authorization': 'Bearer ${getServiceRoleToken(env)}',
      },
    );
    if (response.body.isNotEmpty) throw response.body;
    storage = TestAsyncStorage();
  });

  test('emits a null initial session when nothing is persisted', () async {
    final client = createClient();

    await client.initialized;

    final state = await client.onAuthStateChange.first;
    expect(state.event, AuthChangeEvent.initialSession);
    expect(state.session, isNull);
    expect(client.currentSession, isNull);
  });

  test('uses the key derived from the url by default', () async {
    final client = createClient();

    expect(client.storageKey, storageKey);
    expect(storageKey, startsWith('sb-'));
  });

  test('writes the session on sign in and removes it on sign out', () async {
    final client = createClient();
    await client.initialized;

    final response = await client.signInWithPassword(
      email: email1,
      password: password,
    );
    await settle();

    final persisted = await storage.getItem(storageKey);
    expect(persisted, isNotNull);
    expect(
      Session.fromJson(jsonDecode(persisted!))?.accessToken,
      response.session?.accessToken,
    );

    await client.signOut();
    await settle();

    expect(await storage.getItem(storageKey), isNull);
  });

  test('restores the persisted session in a new client', () async {
    final client = createClient();
    await client.initialized;
    final response = await client.signInWithPassword(
      email: email1,
      password: password,
    );
    await settle();

    final restored = createClient();
    await restored.initialized;

    expect(
      restored.currentSession?.accessToken,
      response.session?.accessToken,
    );
    final state = await restored.onAuthStateChange.first;
    expect(state.event, AuthChangeEvent.initialSession);
    expect(state.session?.accessToken, response.session?.accessToken);
  });

  test('stores the session under a custom storage key', () async {
    final client = createClient(storageKey: 'custom-key');
    await client.initialized;

    await client.signInWithPassword(email: email1, password: password);
    await settle();

    expect(client.storageKey, 'custom-key');
    expect(await storage.getItem('custom-key'), isNotNull);
    expect(await storage.getItem(storageKey), isNull);
  });

  test('a client that does not persist leaves the storage alone', () async {
    final client = createClient(persistSession: false);
    await client.initialized;

    await client.signInWithPassword(email: email1, password: password);
    await settle();

    expect(await storage.getItem(storageKey), isNull);
    expect(client.currentSession, isNotNull);
  });

  test('a client that does not persist emits a null initial session', () async {
    final client = createClient(persistSession: false);
    await client.initialized;
    final states = <AuthState>[];
    final subscription = client.onAuthStateChange.listen(states.add);
    addTearDown(subscription.cancel);

    await client.signInWithPassword(email: email1, password: password);
    await settle();

    expect(states.map((state) => state.event), [
      AuthChangeEvent.initialSession,
      AuthChangeEvent.signedIn,
    ]);
    expect(states.first.session, isNull);
  });

  test('restores an expired session and signs out when it cannot be '
      'refreshed', () async {
    final expired = getSessionData(
      DateTime.now().subtract(const Duration(hours: 1)),
    );
    await storage.setItem(storageKey, expired.sessionString);
    final client = createClient();

    await client.initialized;

    expect(client.currentSession?.accessToken, expired.accessToken);
    expect(client.currentSession?.isExpired, isTrue);

    final states = await client.onAuthStateChange
        .handleError((_) {})
        .take(2)
        .toList();
    expect(states.first.event, AuthChangeEvent.initialSession);
    expect(states.first.session?.accessToken, expired.accessToken);
    expect(states.last.event, AuthChangeEvent.signedOut);
    expect(states.last.signOutReason, SignOutReason.sessionExpired);
    await settle();
    expect(await storage.getItem(storageKey), isNull);
  });

  test('does not refresh an expired session without auto refresh', () async {
    final expired = getSessionData(
      DateTime.now().subtract(const Duration(hours: 1)),
    );
    await storage.setItem(storageKey, expired.sessionString);
    final client = createClient(autoRefreshToken: false);

    await client.initialized;

    await expectLater(
      client.onAuthStateChange,
      emitsThrough(emitsError(isA<AuthException>())),
    );
    expect(client.currentSession, isNull);
  });

  test('discards a persisted value that is not a session', () async {
    await storage.setItem(storageKey, 'not a session');
    final client = createClient();

    await client.initialized;
    await settle();

    expect(client.currentSession, isNull);
    expect(await storage.getItem(storageKey), isNull);
    final state = await client.onAuthStateChange
        .handleError((_) {})
        .firstWhere(
          (candidate) => candidate.event == AuthChangeEvent.initialSession,
        );
    expect(state.session, isNull);
  });

  test('a session without user data is removed from the storage', () async {
    await storage.setItem(storageKey, '{"access_token":"token"}');
    final client = createClient();

    await client.initialized;
    await settle();

    expect(client.currentSession, isNull);
    expect(await storage.getItem(storageKey), isNull);
  });

  test('a sign in during the restore is not replaced by the stored '
      'session', () async {
    final stored = getSessionData(DateTime.now().add(const Duration(hours: 1)));
    final slowStorage = _SlowStorage();
    await slowStorage.setItem(storageKey, stored.sessionString);
    final client = AuthClient(
      url: authUrl,
      headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
      asyncStorage: slowStorage,
      persistSession: true,
      flowType: AuthFlowType.implicit,
    );
    addTearDown(client.dispose);
    final states = <AuthState>[];
    final subscription = client.onAuthStateChange.listen(states.add);
    addTearDown(subscription.cancel);

    final response = await client.signInWithPassword(
      email: email1,
      password: password,
    );
    await client.initialized;
    await settle();

    expect(client.currentSession?.accessToken, response.session?.accessToken);
    final persisted = await slowStorage.getItem(storageKey);
    expect(
      Session.fromJson(jsonDecode(persisted!))?.accessToken,
      response.session?.accessToken,
    );
    expect(states.map((state) => state.event), [
      AuthChangeEvent.initialSession,
      AuthChangeEvent.signedIn,
    ]);
    expect(
      states.first.session?.accessToken,
      response.session?.accessToken,
    );
  });

  test('persists the user after it was updated', () async {
    final client = createClient();
    await client.initialized;
    await client.signInWithPassword(email: email1, password: password);

    await client.updateUser(UserAttributes(data: {'name': 'Updated'}));
    await settle();

    final persisted = await storage.getItem(storageKey);
    final session = Session.fromJson(jsonDecode(persisted!));
    expect(session?.user.userMetadata?['name'], 'Updated');
  });

  test('a persisted value without an access token only emits an initial '
      'session', () async {
    await storage.setItem(storageKey, '{}');
    final client = createClient();
    final events = <AuthChangeEvent>[];
    final subscription = client.onAuthStateChange.listen(
      (state) => events.add(state.event),
      onError: (_) {},
    );
    addTearDown(subscription.cancel);

    await client.initialized;
    await settle();

    expect(client.currentSession, isNull);
    expect(await storage.getItem(storageKey), isNull);
    expect(events, [AuthChangeEvent.initialSession]);
  });

  test('does not write the restored session back to the storage', () async {
    final stored = getSessionData(DateTime.now().add(const Duration(hours: 1)));
    final countingStorage = _CountingStorage();
    await countingStorage.setItem(storageKey, stored.sessionString);
    countingStorage.writes = 0;
    final client = AuthClient(
      url: authUrl,
      headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
      asyncStorage: countingStorage,
      persistSession: true,
      flowType: AuthFlowType.implicit,
    );
    addTearDown(client.dispose);

    await client.initialized;
    await settle();

    expect(client.currentSession?.accessToken, stored.accessToken);
    expect(countingStorage.writes, 0);
  });

  test('a late subscriber receives the current session as its initial '
      'event', () async {
    final client = createClient(persistSession: false);
    await client.initialized;
    final response = await client.signInWithPassword(
      email: email1,
      password: password,
    );

    final state = await client.onAuthStateChange.first;

    expect(state.event, AuthChangeEvent.initialSession);
    expect(state.session?.accessToken, response.session?.accessToken);
  });

  test('every subscriber receives its own initial event', () async {
    final client = createClient(persistSession: false);
    await client.initialized;

    final first = await client.onAuthStateChange.first;
    final second = await client.onAuthStateChange.first;

    expect(first.event, AuthChangeEvent.initialSession);
    expect(second.event, AuthChangeEvent.initialSession);
  });

  test('a failing storage does not break sign in', () async {
    const failingStorage = _FailingStorage();
    final client = AuthClient(
      url: authUrl,
      headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
      asyncStorage: failingStorage,
      persistSession: true,
      flowType: AuthFlowType.implicit,
    );
    addTearDown(client.dispose);
    await client.initialized;

    final response = await client.signInWithPassword(
      email: email1,
      password: password,
    );
    await settle();

    expect(client.currentSession?.accessToken, response.session?.accessToken);
  });
}

/// Takes long enough to read that a sign in can complete in the meantime.
class _SlowStorage extends MemoryAuthAsyncStorage {
  @override
  Future<String?> getItem(String key) async {
    await Future.delayed(const Duration(seconds: 2));
    return super.getItem(key);
  }
}

/// Counts the writes it receives.
class _CountingStorage extends MemoryAuthAsyncStorage {
  int writes = 0;

  @override
  Future<void> setItem(String key, String value) {
    writes++;
    return super.setItem(key, value);
  }

  @override
  Future<void> removeItem(String key) {
    writes++;
    return super.removeItem(key);
  }
}

class _FailingStorage extends AuthAsyncStorage {
  const _FailingStorage();

  @override
  Future<String?> getItem(String key) async => throw StateError('read failed');

  @override
  Future<void> setItem(String key, String value) async =>
      throw StateError('write failed');

  @override
  Future<void> removeItem(String key) async =>
      throw StateError('remove failed');
}
