import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late AuthClient client;
  late MockSupabaseHttpClient mockClient;

  /// The body the MFA challenge endpoint received last.
  Map<String, dynamic> lastChallengeBody() =>
      mockClient.requestsTo('/challenge').last.jsonBody as Map<String, dynamic>;

  setUp(() {
    mockClient = MockSupabaseHttpClient()
      ..stub({
        'id': 'mock-challenge-id',
        'type': 'phone',
        'expires_at': 9999999999,
      }, path: '/challenge');
    client = AuthClient(
      url: 'https://example.com',
      httpClient: mockClient,
      asyncStorage: TestAsyncStorage(),
    );
  });

  test('challenge() omits the channel by default', () async {
    await client.mfa.challenge(factorId: 'factor-id');

    expect(lastChallengeBody().containsKey('channel'), isFalse);
  });

  test('challenge() forwards the whatsapp channel', () async {
    await client.mfa.challenge(
      factorId: 'factor-id',
      channel: OtpChannel.whatsapp,
    );

    expect(lastChallengeBody()['channel'], 'whatsapp');
  });

  test('challenge() forwards the sms channel', () async {
    await client.mfa.challenge(
      factorId: 'factor-id',
      channel: OtpChannel.sms,
    );

    expect(lastChallengeBody()['channel'], 'sms');
  });
}
