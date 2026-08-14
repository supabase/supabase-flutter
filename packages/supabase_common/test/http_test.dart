import 'dart:convert';

import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

class _RecordingClient extends BaseClient {
  BaseRequest? sentRequest;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    sentRequest = request;
    return StreamedResponse(
      Stream.value(utf8.encode('sent by the custom client')),
      200,
      request: request,
    );
  }
}

void main() {
  group('sendWith', () {
    test('sends over the given client', () async {
      final httpClient = _RecordingClient();
      final request = Request('GET', Uri.parse('http://localhost/things'));

      final response = await request.sendWith(httpClient);

      expect(httpClient.sentRequest, same(request));
      expect(
        await response.stream.bytesToString(),
        'sent by the custom client',
      );
    });
  });

  group('header', () {
    test('matches the name case insensitively', () {
      const headers = {'Content-Type': 'application/json'};

      expect(headers.header('content-type'), 'application/json');
      expect(headers.header('CONTENT-TYPE'), 'application/json');
    });

    test('returns null when the header is absent', () {
      expect(const <String, String>{}.header('content-type'), isNull);
    });
  });

  group('redacted', () {
    test('replaces credential values but keeps the names', () {
      const headers = {
        'Authorization': 'Bearer the-access-token',
        'apikey': 'the-anon-key',
        'X-Api-Key': 'another-key',
        'Cookie': 'session=abc',
        'Content-Type': 'application/json',
        'x-region': 'eu-west-2',
      };

      expect(headers.redacted, {
        'Authorization': '<redacted>',
        'apikey': '<redacted>',
        'X-Api-Key': '<redacted>',
        'Cookie': '<redacted>',
        'Content-Type': 'application/json',
        'x-region': 'eu-west-2',
      });
    });

    test('leaves the headers themselves untouched', () {
      final headers = {'Authorization': 'Bearer the-access-token'};

      expect(headers.redacted, {'Authorization': '<redacted>'});
      expect(headers, {'Authorization': 'Bearer the-access-token'});
    });
  });

  group('mediaType', () {
    test('drops parameters and lowercases the type', () {
      expect(
        const {'content-type': 'Application/JSON; charset=utf-8'}.mediaType,
        'application/json',
      );
    });

    test('returns null when there is no content type', () {
      expect(const <String, String>{}.mediaType, isNull);
    });
  });

  group('tryDecodeJsonObject', () {
    test('decodes a JSON object', () {
      expect(tryDecodeJsonObject('{"message":"boom"}'), {'message': 'boom'});
    });

    test('returns null for an empty body', () {
      expect(tryDecodeJsonObject(''), isNull);
    });

    test('returns null for a body that is not JSON', () {
      expect(tryDecodeJsonObject('<html>502 Bad Gateway</html>'), isNull);
    });

    test('returns null for JSON that is not an object', () {
      expect(tryDecodeJsonObject('["boom"]'), isNull);
      expect(tryDecodeJsonObject('"boom"'), isNull);
      expect(tryDecodeJsonObject('42'), isNull);
      expect(tryDecodeJsonObject('null'), isNull);
    });
  });
}
