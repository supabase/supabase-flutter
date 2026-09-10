import 'package:meta/meta.dart';

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
