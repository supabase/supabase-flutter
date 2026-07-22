import 'dart:typed_data';

import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

const storageUrl = 'http://localhost/storage/v1';
const headers = {'Authorization': 'Bearer token'};

void main() {
  test('object paths with reserved characters are percent-encoded', () async {
    final mockClient = CustomHttpClient();
    mockClient.response = Uint8List.fromList([1, 2, 3]);
    mockClient.statusCode = 200;
    final client = SupabaseStorageClient(
      storageUrl,
      headers,
      httpClient: mockClient,
    );

    await client.from('public').download('report?v=2 final.pdf');

    final url = mockClient.receivedRequests.single.url;
    // The `?` and space must stay part of the object key, not be parsed as the
    // start of a query string (which would fetch the wrong object).
    expect(url.query, isEmpty);
    expect(url.pathSegments.last, 'report?v=2 final.pdf');
    expect(url.path, contains('/object/public/'));
  });
}
