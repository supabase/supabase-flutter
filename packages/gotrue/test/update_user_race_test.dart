import 'dart:async';
import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'utils.dart';

Map<String, dynamic> _userJson(String id, String email) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': email,
  'app_metadata': {
    'provider': 'email',
    'providers': ['email'],
  },
  'user_metadata': <String, dynamic>{},
  'created_at': '2023-04-01T09:38:59.784028Z',
};

String _sessionJson(String userId, String email, String accessToken) {
  final expiresAt =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'exp': expiresAt,
            'sub': userId,
            'role': 'authenticated',
            'session_id': accessToken,
          }),
        ),
      )
      .replaceAll('=', '');
  return jsonEncode({
    'access_token': 'header.$payload.signature',
    'expires_in': 3600,
    'expires_at': expiresAt,
    'refresh_token': 'refresh-$accessToken',
    'token_type': 'bearer',
    'user': _userJson(userId, email),
  });
}

/// Holds the `PUT /user` response until [release] completes, so the session
/// can change while the request is in flight.
class _DelayedUpdateHttpClient extends BaseClient {
  final release = Completer<void>();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    await release.future;
    return StreamedResponse(
      Stream.value(
        utf8.encode(jsonEncode(_userJson(userId1, 'updated@email.com'))),
      ),
      200,
      request: request,
    );
  }
}

void main() {
  late _DelayedUpdateHttpClient httpClient;
  late GoTrueClient client;
  late List<AuthChangeEvent> events;

  setUp(() {
    httpClient = _DelayedUpdateHttpClient();
    client = GoTrueClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
    events = [];
    client.onAuthStateChange.listen(
      (state) => events.add(state.event),
      onError: (_) {},
    );
  });

  tearDown(() {
    client.dispose();
  });

  test(
    'a response for a user who signed out leaves the next user untouched',
    () async {
      await client.recoverSession(_sessionJson(userId1, email1, 'first'));
      final update = client.updateUser(UserAttributes(password: 'new'));
      await pumpEventQueue();

      await client.recoverSession(_sessionJson(userId2, email2, 'second'));
      final otherAccessToken = client.currentSession?.accessToken;
      await pumpEventQueue();
      events.clear();
      httpClient.release.complete();
      final response = await update;
      await pumpEventQueue();

      expect(response.user?.id, userId1);
      expect(client.currentSession?.user.id, userId2);
      expect(client.currentSession?.user.email, email2);
      expect(client.currentSession?.accessToken, otherAccessToken);
      expect(events, isNot(contains(AuthChangeEvent.userUpdated)));
    },
  );

  test(
    'a response for the same user still applies after the session changed',
    () async {
      await client.recoverSession(_sessionJson(userId1, email1, 'first'));
      final update = client.updateUser(UserAttributes(password: 'new'));
      await pumpEventQueue();

      await client.recoverSession(_sessionJson(userId1, email1, 'newer'));
      final newerAccessToken = client.currentSession?.accessToken;
      await pumpEventQueue();
      events.clear();
      httpClient.release.complete();
      await update;
      await pumpEventQueue();

      expect(client.currentSession?.user.email, 'updated@email.com');
      expect(client.currentSession?.accessToken, newerAccessToken);
      expect(events, [AuthChangeEvent.userUpdated]);
    },
  );
}
