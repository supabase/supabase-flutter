import 'dart:async';
import 'dart:convert';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// A session that supabase_flutter v2 apps kept in their own storage under
/// `supabasePersistSessionKey` is moved to the storage key.
void main() {
  const authUrl = 'http://localhost:9999';
  const legacyKey = 'SUPABASE_PERSIST_SESSION_KEY';
  final storageKey = defaultPersistSessionKey(authUrl);

  late MockSupabaseHttpClient httpClient;
  late MemoryAuthAsyncStorage storage;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    storage = MemoryAuthAsyncStorage();
  });

  String sessionValue({
    required String refreshToken,
    Duration expiresIn = const Duration(hours: 1),
  }) {
    final expiresAt = DateTime.now().add(expiresIn);
    return jsonEncode(
      testSessionResponseJson(
        accessToken: unsignedTestJwt({
          'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
          'sub': testUserId,
        }),
        refreshToken: refreshToken,
      ),
    );
  }

  AuthClient createClient({String? storageKey, bool autoRefreshToken = false}) {
    final client = AuthClient(
      url: authUrl,
      httpClient: httpClient,
      asyncStorage: storage,
      persistSession: true,
      storageKey: storageKey,
      autoRefreshToken: autoRefreshToken,
    );
    addTearDown(client.dispose);
    return client;
  }

  test('moves a session under the legacy key to the storage key', () async {
    await storage.setItem(legacyKey, sessionValue(refreshToken: 'legacy'));

    final client = createClient();
    await client.initialized;
    await pumpEventQueue();

    expect(client.currentSession?.refreshToken, 'legacy');
    final moved = await storage.getItem(storageKey);
    expect(Session.fromJson(jsonDecode(moved!)).refreshToken, 'legacy');
    expect(await storage.getItem(legacyKey), isNull);
  });

  test('refreshes an expired session it moved', () async {
    httpClient.stub(
      jsonDecode(sessionValue(refreshToken: 'refreshed')),
      method: HttpMethod.post,
      path: '/token',
      query: {'grant_type': 'refresh_token'},
    );
    await storage.setItem(
      legacyKey,
      sessionValue(
        refreshToken: 'legacy',
        expiresIn: const Duration(hours: -1),
      ),
    );

    final client = createClient(autoRefreshToken: true);
    await client.onAuthStateChange.firstWhere(
      (state) => state.event == AuthChangeEvent.tokenRefreshed,
    );
    await pumpEventQueue();

    final refresh = httpClient.requestsTo('/token', method: HttpMethod.post);
    expect(refresh.single.jsonBody, {'refresh_token': 'legacy'});
    final persisted = await storage.getItem(storageKey);
    expect(Session.fromJson(jsonDecode(persisted!)).refreshToken, 'refreshed');
    expect(await storage.getItem(legacyKey), isNull);
  });

  test('keeps the legacy session when writing it to the storage key '
      'fails', () async {
    final value = sessionValue(refreshToken: 'legacy');
    storage = _ReadOnlyStorage({legacyKey: value});

    final client = createClient();
    await client.initialized;
    await pumpEventQueue();

    expect(client.currentSession?.refreshToken, 'legacy');
    expect(await storage.getItem(legacyKey), value);
  });

  test('prefers the session under the storage key', () async {
    await storage.setItem(storageKey, sessionValue(refreshToken: 'current'));
    await storage.setItem(legacyKey, sessionValue(refreshToken: 'legacy'));

    final client = createClient();
    await client.initialized;

    expect(client.currentSession?.refreshToken, 'current');
  });

  test('removes a legacy value that holds no session without signing '
      'out', () async {
    await storage.setItem(legacyKey, 'not a session');
    final client = createClient();
    final events = <AuthChangeEvent>[];
    final subscription = client.onAuthStateChange.listen(
      (state) => events.add(state.event),
    );
    addTearDown(subscription.cancel);

    await client.initialized;
    await pumpEventQueue();

    expect(client.currentSession, isNull);
    expect(events, [AuthChangeEvent.initialSession]);
    expect(await storage.getItem(legacyKey), isNull);
  });

  test('removes the legacy session when a sign in happens during the restore '
      'instead of moving it', () async {
    final blockingStorage = _BlockingStorage(blockedKey: legacyKey);
    storage = blockingStorage;
    await storage.setItem(legacyKey, sessionValue(refreshToken: 'legacy'));
    final client = createClient();
    await pumpEventQueue();

    final signedIn = await signInTestUser(client);
    blockingStorage.release();
    await client.initialized;
    await pumpEventQueue();

    expect(client.currentSession?.accessToken, signedIn.accessToken);
    final persisted = await storage.getItem(storageKey);
    expect(
      Session.fromJson(jsonDecode(persisted!)).accessToken,
      signedIn.accessToken,
    );
    expect(await storage.getItem(legacyKey), isNull);
  });

  test('keeps the session when the legacy key is the storage key', () async {
    final value = sessionValue(refreshToken: 'legacy');
    await storage.setItem(legacyKey, value);

    final client = createClient(storageKey: legacyKey);
    await client.initialized;
    await pumpEventQueue();

    expect(client.currentSession?.refreshToken, 'legacy');
    expect(await storage.getItem(legacyKey), value);
  });
}

/// Holds back the reads of [blockedKey] until [release] is called.
class _BlockingStorage extends MemoryAuthAsyncStorage {
  _BlockingStorage({required this.blockedKey});

  final String blockedKey;
  final _released = Completer<void>();

  void release() => _released.complete();

  @override
  Future<String?> getItem(String key) async {
    if (key == blockedKey) {
      await _released.future;
    }
    return super.getItem(key);
  }
}

/// Serves [_items] and rejects every write.
class _ReadOnlyStorage extends MemoryAuthAsyncStorage {
  _ReadOnlyStorage(this._items);

  final Map<String, String> _items;

  @override
  Future<String?> getItem(String key) async => _items[key];

  @override
  Future<void> setItem(String key, String value) =>
      Future.error(StateError('The storage is read only'));

  @override
  Future<void> removeItem(String key) async {
    _items.remove(key);
  }
}
