import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

/// Records the body of every request it receives and answers with a minimal
/// enroll payload, so we can inspect what the client actually sent without a
/// live server.
class _RecordingHttpClient extends BaseClient {
  final List<Map<String, dynamic>> requestBodies = [];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final body = request is Request && request.body.isNotEmpty
        ? jsonDecode(request.body) as Map<String, dynamic>
        : <String, dynamic>{};
    requestBodies.add(body);
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'id': '3f1e2d4c-1111-2222-3333-444455556666',
        'type': 'totp',
        'totp': {
          'qr_code': 'svg',
          'secret': 'ABC123',
          'uri': 'otpauth://totp/Example?secret=ABC123',
        },
      }))),
      200,
      request: request,
    );
  }
}

void main() {
  group('GoTrueClient.mfa.enroll', () {
    late _RecordingHttpClient http;
    late GoTrueClient client;

    setUp(() {
      http = _RecordingHttpClient();
      client = GoTrueClient(
        url: 'http://localhost',
        headers: {'apikey': 'anon-key'},
        httpClient: http,
      );
    });

    test('a TOTP factor enrolls without an issuer', () async {
      // `issuer` is optional for TOTP, so this must reach the network instead
      // of throwing ArgumentError before the request is sent.
      await client.mfa.enroll();

      expect(http.requestBodies.single.containsKey('issuer'), isFalse);
      expect(http.requestBodies.single['factor_type'], 'totp');
    });

    test('a TOTP factor forwards the issuer when provided', () async {
      await client.mfa.enroll(issuer: 'MyApp');

      expect(http.requestBodies.single['issuer'], 'MyApp');
    });

    test('a phone factor still requires a phone number', () async {
      expect(
        () => client.mfa.enroll(factorType: FactorType.phone),
        throwsArgumentError,
      );
    });
  });
}
