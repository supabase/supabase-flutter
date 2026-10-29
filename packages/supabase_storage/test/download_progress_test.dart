import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_storage/supabase_storage.dart';
import 'package:test/test.dart';

typedef _Report = (int, int?);

SupabaseStorageClient _client(
  Stream<List<int>> Function() body, {
  int? contentLength,
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return SupabaseStorageClient(
    'http://localhost/storage/v1',
    const {},
    httpClient: MockClient.streaming(
      (request, _) async => http.StreamedResponse(
        body(),
        statusCode,
        request: request,
        contentLength: contentLength,
        headers: headers,
      ),
    ),
  );
}

Stream<List<int>> _chunks(List<List<int>> chunks) =>
    Stream.fromIterable(chunks);

void main() {
  group('download progress', () {
    for (final stream in [false, true]) {
      final name = stream ? 'downloadStream' : 'download';

      Future<void> run(
        SupabaseStorageClient client,
        DownloadProgressCallback onProgress, {
        ByteRange? range,
      }) async {
        final files = client.from('bucket');
        if (stream) {
          final download = await files.downloadStream(
            'a.bin',
            onProgress: onProgress,
            range: range,
          );
          await download.drain<void>();
        } else {
          await files.download('a.bin', onProgress: onProgress, range: range);
        }
      }

      group(name, () {
        test('reports each chunk against the content length', () async {
          final reports = <_Report>[];
          final client = _client(
            () => _chunks([
              [1, 2],
              [3],
              [4, 5, 6],
            ]),
            contentLength: 6,
          );

          await run(
            client,
            (received, total) => reports.add((received, total)),
          );

          expect(reports, [(2, 6), (3, 6), (6, 6)]);
        });

        test('reports an unknown total without a content length', () async {
          final reports = <_Report>[];
          final client = _client(
            () => _chunks([
              [1, 2],
              [3],
            ]),
          );

          await run(
            client,
            (received, total) => reports.add((received, total)),
          );

          expect(reports, [(2, null), (3, null)]);
        });

        test('reports an unknown total for an encoded body', () async {
          final reports = <_Report>[];
          final client = _client(
            () => _chunks([
              [1, 2, 3],
            ]),
            contentLength: 3,
            headers: {'content-encoding': 'gzip'},
          );

          await run(
            client,
            (received, total) => reports.add((received, total)),
          );

          expect(reports, [(3, null)]);
        });

        test('reports the range length of a ranged download', () async {
          final reports = <_Report>[];
          final client = _client(
            () => _chunks([
              [1, 2],
              [3, 4],
            ]),
            contentLength: 4,
            statusCode: 206,
          );

          await run(
            client,
            (received, total) => reports.add((received, total)),
            range: ByteRange(10, 13),
          );

          expect(reports, [(2, 4), (4, 4)]);
        });

        test('reports a zero byte body once', () async {
          final reports = <_Report>[];
          final client = _client(() => const Stream.empty(), contentLength: 0);

          await run(
            client,
            (received, total) => reports.add((received, total)),
          );

          expect(reports, [(0, 0)]);
        });

        test('reports nothing for an error response', () async {
          final reports = <_Report>[];
          final client = _client(
            () => _chunks([
              [123, 125],
            ]),
            contentLength: 2,
            statusCode: 404,
          );

          await expectLater(
            run(client, (received, total) => reports.add((received, total))),
            throwsA(isA<StorageException>()),
          );

          expect(reports, isEmpty);
        });

        test('stops reporting when the body fails', () async {
          final reports = <_Report>[];
          final client = _client(() async* {
            yield [1, 2];
            throw http.ClientException('connection lost');
          }, contentLength: 4);

          await expectLater(
            run(client, (received, total) => reports.add((received, total))),
            throwsA(anything),
          );

          expect(reports.length, lessThanOrEqualTo(1));
          expect(reports.every((report) => report.$1 == 2), isTrue);
        });

        test('fails with the exception the callback throws', () async {
          final client = _client(
            () => _chunks([
              [1],
            ]),
            contentLength: 1,
          );

          await expectLater(
            run(client, (_, _) => throw const FormatException('callback')),
            throwsA(isA<FormatException>()),
          );
        });
      });
    }

    test('download returns the collected bytes', () async {
      final client = _client(
        () => _chunks([
          [1, 2],
          [3],
        ]),
        contentLength: 3,
      );

      final bytes = await client
          .from('bucket')
          .download('a.bin', onProgress: (_, _) {});

      expect(bytes, Uint8List.fromList([1, 2, 3]));
    });
  });
}
