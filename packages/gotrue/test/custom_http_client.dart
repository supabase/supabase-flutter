import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart';

import 'utils.dart';

class CustomHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    //Return custom status code to check for usage of this client.
    return StreamedResponse(
      request.finalize(),
      420,
      request: request,
    );
  }
}

class NoEmailConfirmationHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
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

/// Client to test out the token refresh retry logic.
///
/// This client will fail the first 3 requests and succede on the 4th one.
class RetryTestHttpClient extends BaseClient {
  var retryCount = 0;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    retryCount++;
    if (retryCount < 4) {
      throw ClientException('Retry #$retryCount');
    }
    final jwt = JWT(
      {'exp': (DateTime.now().millisecondsSinceEpoch / 1000).round() + 60},
      subject: userId1,
    );

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode(
            {
              'access_token': jwt.sign(
                SecretKey('37c304f8-51aa-419a-a1af-06154e63707a'),
              ),
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'tDoDnvj5MKLuZOQ65KyVfQ',
              'user': {
                'id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                'aud': '',
                'role': '',
                'email': 'fake1@email.com',
                'email_confirmed_at': '2023-04-01T09:38:59.784028Z',
                'phone': '166600000000',
                'phone_confirmed_at': '2023-04-01T09:38:59.784028Z',
                'confirmed_at': '2023-04-01T09:38:59.784028Z',
                'last_sign_in_at': '2023-04-01T09:38:59.904492805Z',
                'app_metadata': {
                  'provider': 'email',
                  'providers': ['email']
                },
                'user_metadata': {},
                'factors': [
                  {
                    'id': '1d3aa138-da96-4aea-8217-af07daa6b82d',
                    'created_at': '2023-04-01T09:38:59.784028Z',
                    'updated_at': '2023-04-01T09:38:59.784028Z',
                    'status': 'unverified',
                    'friendly_name': 'UnverifiedFactor',
                    'factor_type': 'totp'
                  }
                ],
                'identities': [
                  {
                    'id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                    'user_id': '18bc7a4e-c095-4573-93dc-e0be29bada97',
                    'identity_data': {
                      'email': 'fake1@email.com',
                      'sub': '18bc7a4e-c095-4573-93dc-e0be29bada97'
                    },
                    'provider': 'email',
                    'last_sign_in_at': '2023-04-01T09:38:59.784028Z',
                    'created_at': '2023-04-01T09:38:59.784028Z',
                    'updated_at': '2023-04-01T09:38:59.784028Z'
                  }
                ],
                'created_at': '2023-04-01T09:38:59.784028Z',
                'updated_at': '2023-04-01T09:38:59.908816Z'
              }
            },
          ),
        ),
      ),
      201,
      request: request,
    );
  }
}
