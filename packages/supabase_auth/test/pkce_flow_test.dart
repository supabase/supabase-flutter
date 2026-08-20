import 'dart:convert';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_auth/src/auth_constants.dart';
import 'package:supabase_auth/src/helper.dart';
import 'package:supabase_auth/src/pkce_verifier_store.dart';
import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// Records the code verifier each `/token` exchange submits and answers with a
/// session, so a test can assert which flow's verifier was used.
class PKCETokenMockClient extends BaseClient {
  final submittedCodeVerifiers = <String>[];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request is Request &&
        request.url.queryParameters['grant_type'] == 'pkce') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      submittedCodeVerifiers.add(body['code_verifier'] as String);
    }

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'access_token': 'my-access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'my-refresh-token',
            'user': {
              'id': userId1,
              'aud': '',
              'role': '',
              'email': email1,
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
              'created_at': '2023-04-01T09:38:59.784028Z',
              'updated_at': '2023-04-01T09:38:59.908816Z',
            },
          }),
        ),
      ),
      200,
      request: request,
    );
  }
}

/// Records the `redirect_to` of the last request, which the auth server takes
/// as a query parameter.
class RedirectRecordingMockClient extends BaseClient {
  String? lastRedirectTo;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastRedirectTo = request.url.queryParameters['redirect_to'];
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(<String, dynamic>{}))),
      200,
      request: request,
    );
  }
}

/// Delays every operation so overlapping calls into [PKCEVerifierStore] are
/// forced to interleave rather than happening to complete in call order.
class SlowAsyncStorage extends AuthAsyncStorage {
  final _items = <String, String>{};

  Future<void> get _delay => Future.delayed(Duration.zero);

  @override
  Future<String?> getItem({required String key}) async {
    await _delay;
    return _items[key];
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _delay;
    _items[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _delay;
    _items.remove(key);
  }
}

void main() {
  const legacyKey = '${AuthConstants.defaultStorageKey}-code-verifier';
  const indexKey = '${AuthConstants.defaultStorageKey}-flows-code-verifier';

  String slotKey(String flowId) =>
      '${AuthConstants.defaultStorageKey}-flow-$flowId-code-verifier';

  group('PKCEVerifierStore', () {
    late TestAsyncStorage storage;
    late PKCEVerifierStore store;

    setUp(() {
      storage = TestAsyncStorage();
      store = PKCEVerifierStore(storage);
    });

    test('keeps concurrent flows in slots of their own', () async {
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');
      await store.store(flowId: 'flow-two', verifier: 'verifier-two');

      expect(await store.retrieve(flowId: 'flow-one'), 'verifier-one');
      expect(await store.retrieve(flowId: 'flow-two'), 'verifier-two');
    });

    test(
      'mirrors the most recently started flow under the legacy key',
      () async {
        await store.store(flowId: 'flow-one', verifier: 'verifier-one');
        await store.store(flowId: 'flow-two', verifier: 'verifier-two');

        expect(await store.retrieve(), 'verifier-two');
        expect(await storage.getItem(key: legacyKey), 'verifier-two');
      },
    );

    test('does not fall back to the legacy key for an unknown flow', () async {
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');

      expect(await store.retrieve(flowId: 'flow-unknown'), isNull);
    });

    test('evicts the oldest verifier past the concurrency limit', () async {
      final flowIds = List.generate(
        AuthConstants.pkceMaxConcurrentFlows + 2,
        (index) => 'flow-id-$index',
      );

      final evicted = <String>[];
      for (final flowId in flowIds) {
        evicted.addAll(
          await store.store(flowId: flowId, verifier: 'verifier-$flowId'),
        );
      }

      expect(evicted, [flowIds[0], flowIds[1]]);
      expect(await store.retrieve(flowId: flowIds[0]), isNull);
      expect(await store.retrieve(flowId: flowIds[1]), isNull);
      for (final flowId in flowIds.skip(2)) {
        expect(await store.retrieve(flowId: flowId), 'verifier-$flowId');
      }
    });

    test('storing a flow again does not consume another slot', () async {
      for (
        var attempt = 0;
        attempt < AuthConstants.pkceMaxConcurrentFlows;
        attempt++
      ) {
        await store.store(flowId: 'flow-one', verifier: 'verifier-$attempt');
      }
      final evicted = await store.store(
        flowId: 'flow-two',
        verifier: 'verifier-two',
      );

      expect(evicted, isEmpty);
      expect(await store.retrieve(flowId: 'flow-one'), isNotNull);
    });

    test('removing a flow leaves the other pending flows alone', () async {
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');
      await store.store(flowId: 'flow-two', verifier: 'verifier-two');

      await store.remove(flowId: 'flow-one');

      expect(await store.retrieve(flowId: 'flow-one'), isNull);
      expect(await store.retrieve(flowId: 'flow-two'), 'verifier-two');
    });

    test('removing a flow clears the legacy key it mirrors', () async {
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');

      await store.remove(flowId: 'flow-one');

      expect(await storage.getItem(key: legacyKey), isNull);
    });

    test('removing a flow keeps a legacy key of a newer flow', () async {
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');
      await store.store(flowId: 'flow-two', verifier: 'verifier-two');

      await store.remove(flowId: 'flow-one');

      expect(await storage.getItem(key: legacyKey), 'verifier-two');
    });

    test('removing without a flow id also clears the owning slot', () async {
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');

      await store.remove();

      expect(await storage.getItem(key: legacyKey), isNull);
      expect(await store.retrieve(flowId: 'flow-one'), isNull);
      expect(await storage.getItem(key: indexKey), isNull);
    });

    test('removing without a flow id keeps the older flows', () async {
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');
      await store.store(flowId: 'flow-two', verifier: 'verifier-two');

      await store.remove();

      expect(await store.retrieve(flowId: 'flow-two'), isNull);
      expect(await store.retrieve(flowId: 'flow-one'), 'verifier-one');
      expect(jsonDecode(await storage.getItem(key: indexKey) ?? ''), [
        'flow-one',
      ]);
    });

    test('removeAll clears every pending verifier and the index', () async {
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');
      await store.store(flowId: 'flow-two', verifier: 'verifier-two');

      await store.removeAll();

      expect(await storage.getItem(key: slotKey('flow-one')), isNull);
      expect(await storage.getItem(key: slotKey('flow-two')), isNull);
      expect(await storage.getItem(key: indexKey), isNull);
      expect(await storage.getItem(key: legacyKey), isNull);
    });

    test('ignores an index that is not a list of flow ids', () async {
      await storage.setItem(key: indexKey, value: 'not json at all');
      await store.store(flowId: 'flow-one', verifier: 'verifier-one');

      expect(await store.retrieve(flowId: 'flow-one'), 'verifier-one');
      expect(jsonDecode(await storage.getItem(key: indexKey) ?? ''), [
        'flow-one',
      ]);
    });

    test('drops index entries that are not shaped like a flow id', () async {
      await storage.setItem(
        key: indexKey,
        value: jsonEncode(['../escape', 7, 'flow-one']),
      );

      await store.removeAll();

      expect(await storage.getItem(key: slotKey('flow-one')), isNull);
    });

    test('rejects a flow id it could never evict again', () async {
      await expectLater(
        store.store(flowId: '../escape', verifier: 'my-verifier'),
        throwsA(isA<ArgumentError>()),
      );

      expect(await storage.getItem(key: indexKey), isNull);
      expect(await storage.getItem(key: legacyKey), isNull);
      expect(await storage.getItem(key: slotKey('../escape')), isNull);
    });

    test('keeps every concurrently started flow in the index', () async {
      final slowStorage = SlowAsyncStorage();
      final slowStore = PKCEVerifierStore(slowStorage);

      await Future.wait([
        slowStore.store(flowId: 'flow-one', verifier: 'verifier-one'),
        slowStore.store(flowId: 'flow-two', verifier: 'verifier-two'),
      ]);

      expect(jsonDecode(await slowStorage.getItem(key: indexKey) ?? ''), [
        'flow-one',
        'flow-two',
      ]);

      // An untracked slot is one removeAll cannot reach, so a verifier would
      // outlive the sign out that was supposed to clear it.
      await slowStore.removeAll();
      expect(await slowStorage.getItem(key: slotKey('flow-one')), isNull);
      expect(await slowStorage.getItem(key: slotKey('flow-two')), isNull);
    });

    group('validateFlowId', () {
      test('accepts a generated flow id', () {
        final flowId = PKCEVerifierStore.generateFlowId();

        expect(PKCEVerifierStore.validateFlowId(flowId), flowId);
      });

      test('rejects ids that could escape the storage key', () {
        expect(PKCEVerifierStore.validateFlowId(null), isNull);
        expect(PKCEVerifierStore.validateFlowId(''), isNull);
        expect(PKCEVerifierStore.validateFlowId('short'), isNull);
        expect(PKCEVerifierStore.validateFlowId('../../escape'), isNull);
        expect(PKCEVerifierStore.validateFlowId('has.a.dot.in.it'), isNull);
        expect(PKCEVerifierStore.validateFlowId('a' * 65), isNull);
      });
    });

    group('generateFlowId', () {
      test('generates distinct ids', () {
        final flowIds = List.generate(
          100,
          (_) => PKCEVerifierStore.generateFlowId(),
        );

        expect(flowIds.toSet(), hasLength(flowIds.length));
      });
    });
  });

  group('appendPKCEFlowIdToRedirect', () {
    test('appends to a URL without a query', () {
      expect(
        appendPKCEFlowIdToRedirect('https://example.com/callback', 'flow-one'),
        'https://example.com/callback?sb_flow_id=flow-one',
      );
    });

    test('appends to a URL that already has a query', () {
      expect(
        appendPKCEFlowIdToRedirect(
          'https://example.com/callback?next=%2Fhome',
          'flow-one',
        ),
        'https://example.com/callback?next=%2Fhome&sb_flow_id=flow-one',
      );
    });

    test('replaces a flow id that is already there', () {
      expect(
        appendPKCEFlowIdToRedirect(
          'https://example.com/callback?sb_flow_id=stale&next=%2Fhome',
          'flow-one',
        ),
        'https://example.com/callback?next=%2Fhome&sb_flow_id=flow-one',
      );
    });

    test('drops a valueless flow id that is already there', () {
      expect(
        appendPKCEFlowIdToRedirect(
          'https://example.com/callback?sb_flow_id',
          'flow-one',
        ),
        'https://example.com/callback?sb_flow_id=flow-one',
      );
    });

    test('keeps a parameter whose name only shares the prefix', () {
      expect(
        appendPKCEFlowIdToRedirect(
          'https://example.com/callback?sb_flow_idx=1',
          'flow-one',
        ),
        'https://example.com/callback?sb_flow_idx=1&sb_flow_id=flow-one',
      );
    });

    test('drops a flow id that is already in the fragment', () {
      expect(
        appendPKCEFlowIdToRedirect(
          'https://example.com/callback#sb_flow_id=stale&next=%2Fhome',
          'flow-one',
        ),
        'https://example.com/callback?sb_flow_id=flow-one#next=%2Fhome',
      );
    });

    test('drops a fragment that held nothing but a flow id', () {
      expect(
        appendPKCEFlowIdToRedirect(
          'https://example.com/callback#sb_flow_id=stale',
          'flow-one',
        ),
        'https://example.com/callback?sb_flow_id=flow-one',
      );
    });

    test('keeps the fragment at the end of the URL', () {
      expect(
        appendPKCEFlowIdToRedirect(
          'https://example.com/callback?next=%2Fhome#section',
          'flow-one',
        ),
        'https://example.com/callback?next=%2Fhome&sb_flow_id=flow-one#section',
      );
    });

    test('leaves a custom deep link scheme untouched', () {
      expect(
        appendPKCEFlowIdToRedirect(
          'io.supabase.flutter://callback',
          'flow-one',
        ),
        'io.supabase.flutter://callback?sb_flow_id=flow-one',
      );
    });
  });

  group('concurrent PKCE flows', () {
    late TestAsyncStorage storage;
    late PKCETokenMockClient mockClient;
    late AuthClient client;

    setUp(() {
      storage = TestAsyncStorage();
      mockClient = PKCETokenMockClient();
      client = AuthClient(
        url: 'https://example.com',
        httpClient: mockClient,
        asyncStorage: storage,
      );
    });

    test('getOAuthSignInUrl returns the id of the flow it started', () async {
      final response = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );

      expect(PKCEVerifierStore.validateFlowId(response.flowId), isNotNull);
    });

    test('getOAuthSignInUrl returns no flow id on the implicit flow', () async {
      final implicitClient = AuthClient(
        url: 'https://example.com',
        httpClient: mockClient,
        asyncStorage: storage,
        flowType: AuthFlowType.implicit,
      );

      final response = await implicitClient.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );

      expect(response.flowId, isNull);
    });

    test('a later flow does not overwrite an earlier flow verifier', () async {
      final first = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );
      final second = await client.getOAuthSignInUrl(
        provider: OAuthProvider.github,
      );

      final store = PKCEVerifierStore(storage);
      final firstVerifier = await store.retrieve(flowId: first.flowId);
      final secondVerifier = await store.retrieve(flowId: second.flowId);

      expect(firstVerifier, isNotNull);
      expect(secondVerifier, isNotNull);
      expect(firstVerifier, isNot(secondVerifier));
    });

    test('exchanging with a flow id uses that flow verifier', () async {
      final first = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );
      await client.getOAuthSignInUrl(provider: OAuthProvider.github);

      final expectedVerifier = await PKCEVerifierStore(
        storage,
      ).retrieve(flowId: first.flowId);

      await client.exchangeCodeForSession(
        'my-auth-code',
        flowId: first.flowId,
      );

      expect(mockClient.submittedCodeVerifiers, [expectedVerifier]);
    });

    test('exchanging without a flow id uses the most recent flow', () async {
      await client.getOAuthSignInUrl(provider: OAuthProvider.google);
      final second = await client.getOAuthSignInUrl(
        provider: OAuthProvider.github,
      );

      final expectedVerifier = await PKCEVerifierStore(
        storage,
      ).retrieve(flowId: second.flowId);

      await client.exchangeCodeForSession('my-auth-code');

      expect(mockClient.submittedCodeVerifiers, [expectedVerifier]);
      expect(
        await PKCEVerifierStore(storage).retrieve(flowId: second.flowId),
        isNull,
      );
    });

    test('exchanging one flow leaves the other one exchangeable', () async {
      final first = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );
      final second = await client.getOAuthSignInUrl(
        provider: OAuthProvider.github,
      );

      final store = PKCEVerifierStore(storage);
      final firstVerifier = await store.retrieve(flowId: first.flowId);
      final secondVerifier = await store.retrieve(flowId: second.flowId);

      await client.exchangeCodeForSession(
        'first-auth-code',
        flowId: first.flowId,
      );
      await client.exchangeCodeForSession(
        'second-auth-code',
        flowId: second.flowId,
      );

      expect(mockClient.submittedCodeVerifiers, [
        firstVerifier,
        secondVerifier,
      ]);
    });

    test('exchanging with an unknown flow id throws', () async {
      await client.getOAuthSignInUrl(provider: OAuthProvider.google);

      await expectLater(
        client.exchangeCodeForSession(
          'my-auth-code',
          flowId: PKCEVerifierStore.generateFlowId(),
        ),
        throwsA(isA<AuthException>()),
      );
      expect(mockClient.submittedCodeVerifiers, isEmpty);
    });

    test('exchanging with a malformed flow id reports the flow id', () async {
      await client.getOAuthSignInUrl(provider: OAuthProvider.google);

      await expectLater(
        client.exchangeCodeForSession('my-auth-code', flowId: '../escape'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'PKCE flow id is not a valid flow id: ../escape',
          ),
        ),
      );
      expect(mockClient.submittedCodeVerifiers, isEmpty);
    });

    test('exchanging with an overlong flow id bounds the message', () async {
      await client.getOAuthSignInUrl(provider: OAuthProvider.google);

      await expectLater(
        client.exchangeCodeForSession('my-auth-code', flowId: 'a' * 500),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message.length,
            'message length',
            lessThan(128),
          ),
        ),
      );
      expect(mockClient.submittedCodeVerifiers, isEmpty);
    });

    test('exchanging an already exchanged flow throws', () async {
      final response = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );

      await client.exchangeCodeForSession(
        'my-auth-code',
        flowId: response.flowId,
      );

      await expectLater(
        client.exchangeCodeForSession(
          'my-auth-code',
          flowId: response.flowId,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('getSessionFromUrl picks the flow the callback belongs to', () async {
      final first = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );
      await client.getOAuthSignInUrl(provider: OAuthProvider.github);

      final expectedVerifier = await PKCEVerifierStore(
        storage,
      ).retrieve(flowId: first.flowId);

      await client.getSessionFromUrl(
        Uri.parse(
          'io.supabase.flutter://callback?code=my-auth-code'
          '&sb_flow_id=${first.flowId}',
        ),
      );

      expect(mockClient.submittedCodeVerifiers, [expectedVerifier]);
    });

    test('signOut clears every pending verifier', () async {
      final first = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );
      final second = await client.getOAuthSignInUrl(
        provider: OAuthProvider.github,
      );

      await client.signOut();

      final store = PKCEVerifierStore(storage);
      expect(await store.retrieve(flowId: first.flowId), isNull);
      expect(await store.retrieve(flowId: second.flowId), isNull);
      expect(await store.retrieve(), isNull);
    });
  });

  group('appendPkceFlowIdToRedirects', () {
    late RedirectRecordingMockClient mockClient;

    setUp(() {
      mockClient = RedirectRecordingMockClient();
    });

    AuthClient buildClient({required bool appendPkceFlowIdToRedirects}) {
      return AuthClient(
        url: 'https://example.com',
        httpClient: mockClient,
        asyncStorage: TestAsyncStorage(),
        appendPkceFlowIdToRedirects: appendPkceFlowIdToRedirects,
      );
    }

    test('is not appended by default', () async {
      await buildClient(
        appendPkceFlowIdToRedirects: false,
      ).signInWithOtp(email: email1, emailRedirectTo: 'myapp://callback');

      expect(mockClient.lastRedirectTo, 'myapp://callback');
    });

    test('is appended to the redirect of an email OTP', () async {
      await buildClient(
        appendPkceFlowIdToRedirects: true,
      ).signInWithOtp(email: email1, emailRedirectTo: 'myapp://callback');

      final redirectTo = Uri.parse(mockClient.lastRedirectTo!);
      expect(
        PKCEVerifierStore.validateFlowId(
          redirectTo.queryParameters[pkceFlowIdParam],
        ),
        isNotNull,
      );
    });

    test('is appended to the redirect of a password recovery', () async {
      await buildClient(
        appendPkceFlowIdToRedirects: true,
      ).resetPasswordForEmail(email1, redirectTo: 'myapp://callback');

      expect(
        mockClient.lastRedirectTo,
        contains('$pkceFlowIdParam='),
      );
    });

    test('is appended to the redirect handed to the OAuth provider', () async {
      final response =
          await buildClient(
            appendPkceFlowIdToRedirects: true,
          ).getOAuthSignInUrl(
            provider: OAuthProvider.google,
            redirectTo: 'myapp://callback',
          );

      final redirectTo = Uri.parse(
        response.url.queryParameters['redirect_to']!,
      );
      expect(
        redirectTo.queryParameters[pkceFlowIdParam],
        response.flowId,
      );
    });

    test('is not appended when there is no redirect URL', () async {
      await buildClient(
        appendPkceFlowIdToRedirects: true,
      ).signInWithOtp(email: email1);

      expect(mockClient.lastRedirectTo, isNull);
    });
  });
}
