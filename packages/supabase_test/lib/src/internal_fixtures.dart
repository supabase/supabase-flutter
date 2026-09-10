import 'dart:convert';

import 'package:meta/meta.dart';

/// User id embedded in the session produced by [getSessionData].
@visibleForTesting
const sessionDataUserId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';

/// Constructs session data for a given expiration date, belonging to
/// [userId].
@visibleForTesting
({String accessToken, String sessionString}) getSessionData(
  DateTime expireDateTime, {
  String userId = sessionDataUserId,
}) {
  final expiresAt = expireDateTime.millisecondsSinceEpoch ~/ 1000;
  final accessTokenMid = base64.encode(
    utf8.encode(
      json.encode({
        'exp': expiresAt,
        'sub': userId,
        'role': 'authenticated',
      }),
    ),
  );
  final accessToken = 'any.$accessTokenMid.any';
  final sessionString =
      '{"access_token":"$accessToken","expires_in":'
      '${expireDateTime.difference(DateTime.now()).inSeconds},"refresh_token":"'
      '-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"pro'
      'vider_refresh_token":null,"user":{"id":"$userId","app_metadat'
      'a":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"'
      'World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_'
      'at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_a'
      't":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign'
      '_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04'
      '-01T08:35:05.226938Z"}}';
  return (accessToken: accessToken, sessionString: sessionString);
}

/// Column description of the `todos` fixture table, as the realtime server
/// reports it in a `postgres_changes` event.
@visibleForTesting
const todoColumns = [
  {'name': 'id', 'type': 'int4', 'type_modifier': 4294967295},
  {'name': 'task', 'type': 'text', 'type_modifier': 4294967295},
  {'name': 'status', 'type': 'bool', 'type_modifier': 4294967295},
];
