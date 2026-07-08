import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// Captures the body sent to the MFA challenge endpoint and returns a valid
/// challenge response.
class MfaChallengeMockClient extends BaseClient {
  Map<String, dynamic>? lastChallengeBody;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request is Request && request.url.path.endsWith('/challenge')) {
      try {
        lastChallengeBody = json.decode(request.body) as Map<String, dynamic>;
      } catch (_) {
        // Ignore non-JSON bodies.
      }
    }

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'id': 'mock-challenge-id',
            'type': 'phone',
            'expires_at': 9999999999,
          }),
        ),
      ),
      200,
      request: request,
    );
  }
}

void main() {
  late GoTrueClient client;
  late MfaChallengeMockClient mockClient;

  setUp(() {
    mockClient = MfaChallengeMockClient();
    client = GoTrueClient(
      url: 'https://example.com',
      httpClient: mockClient,
      asyncStorage: TestAsyncStorage(),
    );
  });

  test('challenge() omits the channel by default', () async {
    await client.mfa.challenge(factorId: 'factor-id');

    expect(mockClient.lastChallengeBody?.containsKey('channel'), isFalse);
  });

  test('challenge() forwards the whatsapp channel', () async {
    await client.mfa.challenge(
      factorId: 'factor-id',
      channel: OtpChannel.whatsapp,
    );

    expect(mockClient.lastChallengeBody?['channel'], 'whatsapp');
  });

  test('challenge() forwards the sms channel', () async {
    await client.mfa.challenge(
      factorId: 'factor-id',
      channel: OtpChannel.sms,
    );

    expect(mockClient.lastChallengeBody?['channel'], 'sms');
  });
}
