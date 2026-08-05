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
  group('sendRequest', () {
    test('sends over the given client', () async {
      final httpClient = _RecordingClient();
      final request = Request('GET', Uri.parse('http://localhost/things'));

      final response = await sendRequest(request, httpClient: httpClient);

      expect(httpClient.sentRequest, same(request));
      expect(
        await response.stream.bytesToString(),
        'sent by the custom client',
      );
    });
  });

  group('headerValue', () {
    test('matches the name case insensitively', () {
      const headers = {'Content-Type': 'application/json'};

      expect(headerValue(headers, 'content-type'), 'application/json');
      expect(headerValue(headers, 'CONTENT-TYPE'), 'application/json');
    });

    test('returns null when the header is absent', () {
      expect(headerValue(const {}, 'content-type'), isNull);
    });
  });

  group('setDefaultContentType', () {
    test('sets the content type when there is none', () {
      final headers = <String, String>{};

      setDefaultContentType(headers, 'application/json');

      expect(headers, {'Content-Type': 'application/json'});
    });

    test('keeps a content type set under any casing', () {
      final headers = {'content-type': 'text/csv'};

      setDefaultContentType(headers, 'application/json');

      expect(headers, {'content-type': 'text/csv'});
    });
  });

  group('responseMediaType', () {
    test('drops parameters and lowercases the type', () {
      expect(
        responseMediaType(const {
          'content-type': 'Application/JSON; charset=utf-8',
        }),
        'application/json',
      );
    });

    test('returns null when there is no content type', () {
      expect(responseMediaType(const {}), isNull);
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
