import 'dart:convert';

import 'package:meta/meta.dart';

/// User id embedded in the session produced by [getSessionData].
@visibleForTesting
const sessionDataUserId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';

/// Constructs session data for a given expiration date.
@visibleForTesting
({String accessToken, String sessionString}) getSessionData(
  DateTime expireDateTime,
) {
  final expiresAt = expireDateTime.millisecondsSinceEpoch ~/ 1000;
  final accessTokenMid = base64.encode(
    utf8.encode(
      json.encode({
        'exp': expiresAt,
        'sub': '1234567890',
        'role': 'authenticated',
      }),
    ),
  );
  final accessToken = 'any.$accessTokenMid.any';
  final sessionString =
      '{"access_token":"$accessToken","expires_in":'
      '${expireDateTime.difference(DateTime.now()).inSeconds},"refresh_token":"'
      '-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"pro'
      'vider_refresh_token":null,"user":{"id":"$sessionDataUserId","app_metadat'
      'a":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"'
      'World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_'
      'at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_a'
      't":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign'
      '_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04'
      '-01T08:35:05.226938Z"}}';
  return (accessToken: accessToken, sessionString: sessionString);
}

/// Id of the user [testUserJson] describes.
@visibleForTesting
const testUserId = '18bc7a4e-c095-4573-93dc-e0be29bada97';

/// The JSON form of a fixed test user carrying an unverified TOTP factor and
/// an email identity, as the auth server would return it.
@visibleForTesting
Map<String, dynamic> testUserJson({
  String id = testUserId,
  String email = 'fake1@email.com',
  String phone = '166600000000',
}) => {
  'id': id,
  'aud': '',
  'role': '',
  'email': email,
  'email_confirmed_at': '2023-04-01T09:38:59.784028Z',
  'phone': phone,
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
      'id': id,
      'user_id': id,
      'identity_data': {
        'email': email,
        'sub': id,
      },
      'provider': 'email',
      'last_sign_in_at': '2023-04-01T09:38:59.784028Z',
      'created_at': '2023-04-01T09:38:59.784028Z',
      'updated_at': '2023-04-01T09:38:59.784028Z',
    },
  ],
  'created_at': '2023-04-01T09:38:59.784028Z',
  'updated_at': '2023-04-01T09:38:59.908816Z',
};

/// The JSON form of a token endpoint response carrying [accessToken] and
/// [user], which defaults to [testUserJson].
@visibleForTesting
Map<String, dynamic> testSessionResponseJson({
  required String accessToken,
  String refreshToken = 'tDoDnvj5MKLuZOQ65KyVfQ',
  Map<String, dynamic>? user,
}) => {
  'access_token': accessToken,
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': refreshToken,
  'user': user ?? testUserJson(),
};
