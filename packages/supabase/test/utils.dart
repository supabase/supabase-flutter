import 'dart:convert';

/// Construct session data for a given expiration date
({String accessToken, String sessionString}) getSessionData(DateTime dateTime) {
  final expiresAt = dateTime.millisecondsSinceEpoch ~/ 1000;
  final accessTokenMid = base64.encode(utf8.encode(json.encode(
      {"exp": expiresAt, "sub": "1234567890", "role": "authenticated"})));
  final accessToken = "any.$accessTokenMid.any";
  final sessionString =
      '{"access_token":"$accessToken","expires_in":${dateTime.difference(DateTime.now()).inSeconds},"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"provider_refresh_token":null,"user":{"id":"4d2583da-8de4-49d3-9cd1-37a9a74f55bd","app_metadata":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_at":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04-01T08:35:05.226938Z"}}';
  return (accessToken: accessToken, sessionString: sessionString);
}
