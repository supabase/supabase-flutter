import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase_storage/supabase_storage.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const storageUrl = 'http://localhost/storage/v1';
const uploadUrl = '$storageUrl/upload/resumable/upload-1';
final uploadUrlPath = Uri.parse(uploadUrl).path;

/// A tus server holding one upload, answering the way storage does.
class FakeTusServer {
  FakeTusServer(this.httpClient) {
    httpClient
      ..stubHandler(
        _create,
        method: HttpMethod.post,
        path: '/upload/resumable',
      )
      ..stubHandler(
        _create,
        method: HttpMethod.post,
        path: '/upload/resumable/sign',
      )
      ..stubHandler(_head, method: HttpMethod.head, path: uploadUrlPath)
      ..stubHandler(
        _append,
        method: HttpMethod.patch,
        path: uploadUrlPath,
      )
      ..stubHandler(
        (_) {
          length = null;
          return Response('', 204);
        },
        method: HttpMethod.delete,
        path: uploadUrlPath,
      );
  }

  final MockSupabaseHttpClient httpClient;
  int? length;
  final received = BytesBuilder();

  Response _create(RecordedRequest request) {
    length = int.parse(request.headers['upload-length']!);
    received.clear();
    if (length == 0) {
      return Response(
        '',
        201,
        headers: {'tus-complete': '1', ..._completeHeaders},
      );
    }
    return Response('', 201, headers: {'location': uploadUrl});
  }

  Response _head(RecordedRequest request) {
    final length = this.length;
    if (length == null) return Response('Not Found', 404);
    return Response(
      '',
      200,
      headers: {
        'upload-offset': '${received.length}',
        'upload-length': '$length',
        if (received.length == length) ..._completeHeaders,
      },
    );
  }

  Response _append(RecordedRequest request) {
    final length = this.length;
    if (length == null) return Response('Not Found', 404);
    if (request.headers['upload-offset'] != '${received.length}') {
      return Response('Upload-Offset conflict', 409);
    }
    received.add(request.bodyBytes);
    return Response(
      '',
      204,
      headers: {
        'upload-offset': '${received.length}',
        if (received.length == length) ...{
          'tus-complete': '1',
          ..._completeHeaders,
        },
      },
    );
  }

  static const _completeHeaders = {
    'supabase-object-id': 'object-1',
    'supabase-object-version-id': 'version-1',
  };
}

Map<String, String> decodeUploadMetadata(String header) => {
  for (final pair in header.split(','))
    pair.split(' ').first: utf8.decode(base64.decode(pair.split(' ').last)),
};

void main() {
  final data = Uint8List.fromList(List.generate(10, (index) => index));
  late MockSupabaseHttpClient httpClient;
  late FakeTusServer server;
  late MemoryResumableUploadStorage recordStorage;
  late SupabaseStorageClient storage;

  SupabaseStorageClient createClient() => SupabaseStorageClient(
    storageUrl,
    {'Authorization': 'Bearer token', 'apikey': 'key'},
    httpClient: httpClient,
    resumableUploadOptions: ResumableUploadOptions(
      chunkSize: 4,
      retryDelays: const [Duration.zero, Duration.zero],
      storage: recordStorage,
    ),
  );

  List<RecordedRequest> patches() =>
      httpClient.requestsTo(uploadUrlPath, method: HttpMethod.patch);

  List<RecordedRequest> heads() =>
      httpClient.requestsTo(uploadUrlPath, method: HttpMethod.head);

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    server = FakeTusServer(httpClient);
    recordStorage = MemoryResumableUploadStorage();
    storage = createClient();
  });

  test('creates the upload and sends it in chunks', () async {
    final upload = storage
        .from('videos')
        .resumableUploadBinary(
          '/folder//clip.mp4',
          data,
          fileOptions: const FileOptions(
            cacheControl: '60',
            metadata: {'owner': 'test'},
          ),
        );
    final progress = upload.progress.toList();

    final response = await upload.done;

    expect(response.id, 'object-1');
    expect(response.versionId, 'version-1');
    expect(response.path, 'folder/clip.mp4');
    expect(response.fullPath, 'videos/folder/clip.mp4');
    expect(upload.status, ResumableUploadStatus.completed);
    expect(server.received.toBytes(), data);

    final create = httpClient
        .requestsTo('/upload/resumable', method: HttpMethod.post)
        .single;
    expect(create.headers['tus-resumable'], '1.0.0');
    expect(create.headers['upload-length'], '10');
    expect(create.headers['x-upsert'], 'false');
    expect(create.headers['authorization'], 'Bearer token');
    expect(create.headers['apikey'], 'key');
    expect(decodeUploadMetadata(create.headers['upload-metadata']!), {
      'bucketName': 'videos',
      'objectName': 'folder/clip.mp4',
      'contentType': 'video/mp4',
      'cacheControl': '60',
      'metadata': '{"owner":"test"}',
    });

    expect(patches().map((request) => request.headers['upload-offset']), [
      '0',
      '4',
      '8',
    ]);
    for (final patch in patches()) {
      expect(
        patch.headers['content-type'],
        'application/offset+octet-stream',
      );
      expect(patch.headers['x-upsert'], 'false');
      expect(patch.headers['authorization'], 'Bearer token');
    }

    expect(
      (await progress).last,
      const ResumableUploadProgress(
        status: ResumableUploadStatus.completed,
        bytesUploaded: 10,
        totalBytes: 10,
      ),
    );
    expect(await storage.resumableUploads(), isEmpty);
  });

  test('streams a file from disk', () async {
    final directory = Directory.systemTemp.createTempSync('resumable_upload');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/notes.txt')..writeAsBytesSync(data);

    final upload = storage.from('docs').resumableUpload('notes.txt', file);
    await upload.done;

    expect(server.received.toBytes(), data);
    final create = httpClient
        .requestsTo('/upload/resumable', method: HttpMethod.post)
        .single;
    expect(
      decodeUploadMetadata(create.headers['upload-metadata']!)['contentType'],
      'text/plain',
    );
  });

  test(
    'guesses the content type from the object path for a file without '
    'an extension',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'resumable_upload',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/upload-1234')
        ..writeAsBytesSync(data);

      await storage.from('docs').resumableUpload('avatar.png', file).done;

      final create = httpClient
          .requestsTo('/upload/resumable', method: HttpMethod.post)
          .single;
      expect(
        decodeUploadMetadata(
          create.headers['upload-metadata']!,
        )['contentType'],
        'image/png',
      );
    },
  );

  test('records the upload before the first chunk is sent', () async {
    httpClient.stubStall(method: HttpMethod.patch, times: 1);

    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);
    await upload.progress.first;
    await pumpEventQueue();

    final records = await storage.resumableUploads();
    expect(records.single.id, upload.id);
    expect(records.single.bucketId, 'videos');
    expect(records.single.path, 'clip.mp4');
    expect(records.single.totalBytes, 10);
    await upload.cancel();
  });

  test('finishes an empty file with the creation request', () async {
    final response = await storage
        .from('videos')
        .resumableUploadBinary('empty.txt', Uint8List(0))
        .done;

    expect(response.id, 'object-1');
    expect(patches(), isEmpty);
    expect(await storage.resumableUploads(), isEmpty);
  });

  test(
    'pauses the chunk in flight and resumes from the server offset',
    () async {
      httpClient.stubStall(method: HttpMethod.patch, times: 1);
      final upload = storage
          .from('videos')
          .resumableUploadBinary('clip.mp4', data);
      await upload.progress.first;
      await pumpEventQueue();

      upload.pause();
      expect(upload.status, ResumableUploadStatus.paused);
      await pumpEventQueue();
      expect(heads(), isEmpty);

      upload.resume();
      await upload.done;

      expect(heads(), hasLength(1));
      expect(server.received.toBytes(), data);
    },
  );

  test('reads the offset again after a conflict', () async {
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);
    httpClient.stubHandler(
      (_) {
        server.received.add(data.sublist(0, 4));
        return Response('Upload-Offset conflict', 409);
      },
      method: HttpMethod.patch,
      times: 1,
    );

    await upload.done;

    expect(heads(), hasLength(1));
    expect(server.received.toBytes(), data);
  });

  test('retries a chunk that failed on the network', () async {
    httpClient.stubError(
      ClientException('Offline'),
      method: HttpMethod.patch,
      times: 2,
    );

    await storage.from('videos').resumableUploadBinary('clip.mp4', data).done;

    expect(heads(), hasLength(2));
    expect(server.received.toBytes(), data);
  });

  test('retries a chunk the server answered with a 5xx', () async {
    httpClient.stubHandler(
      (_) => Response('Service Unavailable', 503),
      method: HttpMethod.patch,
      times: 1,
    );

    await storage.from('videos').resumableUploadBinary('clip.mp4', data).done;

    expect(server.received.toBytes(), data);
  });

  test('keeps the record once the retries run out, to resume later', () async {
    httpClient.stubError(
      ClientException('Offline'),
      method: HttpMethod.patch,
      times: 3,
    );
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);

    await expectLater(
      upload.done,
      throwsA(isA<StorageTransportException>()),
    );
    expect(upload.status, ResumableUploadStatus.failed);
    expect(await storage.resumableUploads(), hasLength(1));

    upload.resume();
    await upload.done;

    expect(upload.status, ResumableUploadStatus.completed);
    expect(server.received.toBytes(), data);
  });

  test('resumes a failed upload through the same handle', () async {
    httpClient.stubError(
      ClientException('Offline'),
      method: HttpMethod.patch,
      times: 3,
    );
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);
    await expectLater(
      upload.done,
      throwsA(isA<StorageTransportException>()),
    );

    final resumed = await storage.resumeUploadBinary(upload.id, data);
    await resumed.done;

    expect(resumed, same(upload));
    expect(upload.status, ResumableUploadStatus.completed);
    expect(server.received.toBytes(), data);
  });

  test('fails without a record when the server refuses a chunk', () async {
    httpClient.stubText(
      'Forbidden',
      statusCode: 403,
      method: HttpMethod.patch,
    );
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);

    await expectLater(
      upload.done,
      throwsA(
        isA<StorageApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.message, 'message', 'Forbidden'),
      ),
    );
    expect(await storage.resumableUploads(), isEmpty);
  });

  test('starts over when the upload expired', () async {
    httpClient.stubHandler(
      (request) {
        server.received.add(request.bodyBytes);
        server.length = null;
        return Response('Not Found', 404);
      },
      method: HttpMethod.patch,
      times: 1,
    );
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);
    final progress = upload.progress.toList();

    await upload.done;

    expect(
      httpClient.requestsTo('/upload/resumable', method: HttpMethod.post),
      hasLength(2),
    );
    expect(server.received.toBytes(), data);
    expect(
      (await progress).map((event) => event.bytesUploaded),
      containsAllInOrder([4, 0, 10]),
    );
  });

  test(
    'fails when the upload is gone again right after starting over',
    () async {
      httpClient.stubText(
        'Not Found',
        statusCode: 404,
        method: HttpMethod.patch,
      );
      final upload = storage
          .from('videos')
          .resumableUploadBinary('clip.mp4', data);

      await expectLater(
        upload.done,
        throwsA(
          isA<StorageApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
      expect(
        httpClient.requestsTo(
          '/upload/resumable',
          method: HttpMethod.post,
        ),
        hasLength(2),
      );
      expect(await storage.resumableUploads(), isEmpty);
    },
  );

  test('surfaces an existing object like a single-request upload', () async {
    httpClient.stubText(
      'The resource already exists',
      statusCode: 409,
      method: HttpMethod.post,
    );
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);

    await expectLater(
      upload.done,
      throwsA(
        isA<StorageApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
    expect(await storage.resumableUploads(), isEmpty);
  });

  test('carries the single request error codes on the creation', () async {
    for (final (statusCode, message, errorCode) in [
      (409, 'The resource already exists', 'Duplicate'),
      (413, 'Maximum size exceeded', 'EntityTooLarge'),
    ]) {
      httpClient.stubText(
        message,
        statusCode: statusCode,
        method: HttpMethod.post,
        times: 1,
      );
      final upload = storage
          .from('videos')
          .resumableUploadBinary('clip$statusCode.mp4', data);

      await expectLater(
        upload.done,
        throwsA(
          isA<StorageApiException>()
              .having((error) => error.statusCode, 'statusCode', statusCode)
              .having((error) => error.errorCode, 'errorCode', errorCode),
        ),
      );
    }
  });

  test(
    'fails with a duplicate when the final chunk finds the object',
    () async {
      httpClient.stubText(
        'The resource already exists',
        statusCode: 409,
        method: HttpMethod.patch,
      );
      final upload = storage
          .from('videos')
          .resumableUploadBinary('clip.mp4', data);

      await expectLater(
        upload.done,
        throwsA(
          isA<StorageApiException>()
              .having((error) => error.statusCode, 'statusCode', 409)
              .having((error) => error.errorCode, 'errorCode', 'Duplicate'),
        ),
      );
      expect(
        httpClient.requestsTo(uploadUrlPath, method: HttpMethod.patch),
        hasLength(1),
      );
      expect(await storage.resumableUploads(), isEmpty);
    },
  );

  test('requires Tus-Complete to complete the upload', () async {
    httpClient.stubHandler(
      (request) => Response(
        '',
        204,
        headers: {
          'upload-offset': '10',
          'supabase-object-id': 'object-1',
        },
      ),
      method: HttpMethod.patch,
    );
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);

    await expectLater(upload.done, throwsA(isA<StorageException>()));
    expect(upload.status, ResumableUploadStatus.failed);
  });

  test('sends upsert on the creation and every chunk', () async {
    await storage
        .from('videos')
        .resumableUploadBinary(
          'clip.mp4',
          data,
          fileOptions: const FileOptions(upsert: true),
        )
        .done;

    expect(
      httpClient
          .requestsTo('/upload/resumable', method: HttpMethod.post)
          .single
          .headers['x-upsert'],
      'true',
    );
    expect(
      patches().map((request) => request.headers['x-upsert']),
      everyElement('true'),
    );
  });

  test('cancels the upload on the server and forgets it', () async {
    httpClient.stubStall(method: HttpMethod.patch, times: 1);
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);
    final progress = upload.progress.toList();
    await upload.progress.first;
    await pumpEventQueue();

    await upload.cancel();

    expect(upload.status, ResumableUploadStatus.cancelled);
    await expectLater(
      upload.done,
      throwsA(
        isA<ResumableUploadCancelledException>().having(
          (error) => error.uploadId,
          'uploadId',
          upload.id,
        ),
      ),
    );
    expect(
      httpClient.requestsTo(uploadUrlPath, method: HttpMethod.delete),
      hasLength(1),
    );
    expect(await storage.resumableUploads(), isEmpty);
    expect(
      (await progress).last.status,
      ResumableUploadStatus.cancelled,
    );
  });

  test('completes instead of cancelling once the last chunk landed', () async {
    final answer = Completer<void>();
    httpClient.stubHandler(
      (request) async {
        await answer.future;
        server.received.add(request.bodyBytes);
        return Response(
          '',
          204,
          headers: {
            'upload-offset': '10',
            'tus-complete': '1',
            'supabase-object-id': 'object-1',
          },
        );
      },
      method: HttpMethod.patch,
      times: 1,
    );
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);
    await upload.progress.first;
    await pumpEventQueue();

    final cancellation = upload.cancel();
    answer.complete();
    await cancellation;

    expect(upload.status, ResumableUploadStatus.completed);
    expect((await upload.done).id, 'object-1');
    expect(
      httpClient.requestsTo(uploadUrlPath, method: HttpMethod.delete),
      isEmpty,
    );
  });

  test('keeps a stored record it cannot read', () async {
    const key = 'sb-localhost-resumable-uploads';
    const unreadable = {'future-upload': 'from a newer version'};
    await recordStorage.setItem(key, jsonEncode(unreadable));
    httpClient.stubStall(method: HttpMethod.patch, times: 1);

    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);
    await upload.progress.first;
    await pumpEventQueue();

    expect((await storage.resumableUploads()).single.id, upload.id);
    final stored =
        jsonDecode((await recordStorage.getItem(key))!) as Map<String, dynamic>;
    expect(stored, containsPair('future-upload', 'from a newer version'));

    await upload.cancel();
    expect(
      jsonDecode((await recordStorage.getItem(key))!),
      unreadable,
    );
  });

  test('keeps a stored record with a field of the wrong type', () async {
    const key = 'sb-localhost-resumable-uploads';
    const unreadable = {
      'broken-upload': {'id': 'broken-upload', 'totalBytes': 'ten'},
    };
    await recordStorage.setItem(key, jsonEncode(unreadable));

    expect(await storage.resumableUploads(), isEmpty);
    expect(jsonDecode((await recordStorage.getItem(key))!), unreadable);
  });

  test('uploads with a signed upload token and the client headers', () async {
    await storage
        .from('videos')
        .resumableUploadBinary(
          'clip.mp4',
          data,
          fileOptions: const FileOptions(upsert: true),
          token: 'signed-token',
        )
        .done;

    final create = httpClient
        .requestsTo('/upload/resumable/sign', method: HttpMethod.post)
        .single;
    expect(create.headers['x-signature'], 'signed-token');
    expect(create.headers.containsKey('x-upsert'), isFalse);
    expect(create.headers['apikey'], 'key');
    expect(create.headers['x-client-info'], startsWith('storage-dart/'));
    for (final patch in patches()) {
      expect(patch.headers['x-signature'], 'signed-token');
      expect(patch.headers.containsKey('x-upsert'), isFalse);
      expect(patch.headers['apikey'], 'key');
    }
  });

  test('rejects metadata that cannot be encoded as JSON', () {
    expect(
      () => storage
          .from('videos')
          .resumableUploadBinary(
            'clip.mp4',
            data,
            fileOptions: FileOptions(metadata: {'at': DateTime(2026)}),
          ),
      throwsArgumentError,
    );
    expect(httpClient.requests, isEmpty);
  });

  test('fails when the bytes arrived but no object was stored', () async {
    httpClient.stubStall(method: HttpMethod.patch, times: 1);
    final upload = storage
        .from('videos')
        .resumableUploadBinary('clip.mp4', data);
    await upload.progress.first;
    await pumpEventQueue();
    upload.pause();
    httpClient.stubHandler(
      (_) => Response(
        '',
        200,
        headers: {'upload-offset': '10', 'upload-length': '10'},
      ),
      method: HttpMethod.head,
      times: 1,
    );

    upload.resume();

    await expectLater(upload.done, throwsA(isA<StorageException>()));
    expect(await storage.resumableUploads(), isEmpty);
  });

  group('after a restart', () {
    Future<String> interruptedUpload() async {
      httpClient.stubHandler(
        (request) {
          server.received.add(request.bodyBytes);
          return Response('', 204, headers: {'upload-offset': '4'});
        },
        method: HttpMethod.patch,
        times: 1,
      );
      httpClient.stubStall(method: HttpMethod.patch, times: 1);
      final upload = storage
          .from('videos')
          .resumableUploadBinary('clip.mp4', data);
      await upload.progress.firstWhere(
        (progress) => progress.bytesUploaded == 4,
      );
      upload.pause();
      return upload.id;
    }

    test('lists the record and continues it with the same data', () async {
      final id = await interruptedUpload();
      final restarted = createClient();

      final records = await restarted.resumableUploads();
      expect(records.single.id, id);

      final upload = await restarted.resumeUploadBinary(id, data);
      final response = await upload.done;

      expect(upload.id, id);
      expect(response.path, 'clip.mp4');
      expect(server.received.toBytes(), data);
      expect(
        httpClient.requestsTo(
          '/upload/resumable',
          method: HttpMethod.post,
        ),
        hasLength(1),
      );
      expect(await restarted.resumableUploads(), isEmpty);
    });

    test('rejects data of another size', () async {
      final id = await interruptedUpload();

      await expectLater(
        createClient().resumeUploadBinary(id, Uint8List(3)),
        throwsArgumentError,
      );
    });

    test('rejects an unknown id', () async {
      await expectLater(
        storage.resumeUploadBinary('unknown', data),
        throwsA(isA<StorageException>()),
      );
    });

    test('discards a record without the data', () async {
      final id = await interruptedUpload();
      final restarted = createClient();

      await restarted.discardResumableUpload(id);

      expect(await restarted.resumableUploads(), isEmpty);
      expect(
        httpClient.requestsTo(uploadUrlPath, method: HttpMethod.delete),
        hasLength(1),
      );
    });
  });
}
