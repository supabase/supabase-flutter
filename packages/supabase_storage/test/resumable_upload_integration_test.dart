import 'dart:typed_data';

import 'package:supabase_common/testing.dart';
import 'package:supabase_storage/supabase_storage.dart';
import 'package:test/test.dart';

// These tests send resumable uploads to the tus endpoint of a live Supabase
// stack. Each test uploads into a bucket of its own, removed afterwards.
void main() {
  final runId = DateTime.now().millisecondsSinceEpoch;
  var counter = 0;
  late MemoryResumableUploadStorage recordStorage;
  late SupabaseStorageClient storage;
  late String bucketId;

  SupabaseStorageClient createClient() => SupabaseStorageClient(
    localStackStorageUrl,
    {'Authorization': 'Bearer $localStackServiceRoleKey'},
    resumableUploadOptions: ResumableUploadOptions(storage: recordStorage),
  );

  Uint8List bytes(int length) =>
      Uint8List.fromList(List.generate(length, (index) => index % 251));

  setUp(() async {
    recordStorage = MemoryResumableUploadStorage();
    storage = createClient();
    bucketId = 'resumable-test-$runId-${counter++}';
    await storage.createBucket(bucketId);
  });

  tearDown(() async {
    await storage.emptyBucket(bucketId);
    await storage.deleteBucket(bucketId);
  });

  test('uploads a file larger than one chunk', () async {
    final data = bytes(ResumableUploadOptions.defaultChunkSize * 2 + 1000);

    final upload = storage
        .from(bucketId)
        .resumableUploadBinary(
          'folder/large.bin',
          data,
          fileOptions: const FileOptions(metadata: {'source': 'test'}),
        );
    final progress = upload.progress.toList();
    final response = await upload.done;

    expect(response.fullPath, '$bucketId/folder/large.bin');
    expect(await storage.from(bucketId).download('folder/large.bin'), data);
    final info = await storage.from(bucketId).getMetadata('folder/large.bin');
    expect(info.metadata?['source'], 'test');
    expect(
      (await progress).last,
      ResumableUploadProgress(
        status: ResumableUploadStatus.completed,
        bytesUploaded: data.length,
        totalBytes: data.length,
      ),
    );
    expect(await storage.resumableUploads(), isEmpty);
  });

  test('uploads an empty file', () async {
    await storage
        .from(bucketId)
        .resumableUploadBinary('empty.txt', Uint8List(0))
        .done;

    expect(await storage.from(bucketId).download('empty.txt'), isEmpty);
  });

  test('continues a paused upload after a restart', () async {
    final data = bytes(ResumableUploadOptions.defaultChunkSize * 2 + 1000);
    final upload = storage
        .from(bucketId)
        .resumableUploadBinary('restart.bin', data);
    await upload.progress.firstWhere(
      (progress) =>
          progress.bytesUploaded >= ResumableUploadOptions.defaultChunkSize &&
          progress.bytesUploaded < data.length,
    );
    upload.pause();

    final restarted = createClient();
    expect((await restarted.resumableUploads()).single.id, upload.id);
    final resumed = await restarted.resumeUploadBinary(upload.id, data);
    await resumed.done;

    expect(await storage.from(bucketId).download('restart.bin'), data);
    expect(await restarted.resumableUploads(), isEmpty);
  });

  test('refuses to overwrite an object without upsert', () async {
    await storage
        .from(bucketId)
        .uploadBinary('existing.txt', Uint8List.fromList([1]));

    final upload = storage
        .from(bucketId)
        .resumableUploadBinary('existing.txt', Uint8List.fromList([2]));

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
  });

  test('overwrites an object with upsert', () async {
    await storage
        .from(bucketId)
        .uploadBinary('existing.txt', Uint8List.fromList([1]));

    await storage
        .from(bucketId)
        .resumableUploadBinary(
          'existing.txt',
          Uint8List.fromList([2]),
          fileOptions: const FileOptions(upsert: true),
        )
        .done;

    expect(await storage.from(bucketId).download('existing.txt'), [2]);
  });

  test('uploads with a signed upload token', () async {
    final signed = await storage
        .from(bucketId)
        .createSignedUploadUrl('signed.bin');
    final data = bytes(1000);

    await storage
        .from(bucketId)
        .resumableUploadBinary('signed.bin', data, token: signed.token)
        .done;

    expect(await storage.from(bucketId).download('signed.bin'), data);
  });

  test('cancels an upload', () async {
    final data = bytes(ResumableUploadOptions.defaultChunkSize * 2);
    final upload = storage
        .from(bucketId)
        .resumableUploadBinary('cancelled.bin', data);
    await upload.progress.firstWhere(
      (progress) => progress.bytesUploaded > 0,
    );

    await upload.cancel();

    await expectLater(
      upload.done,
      throwsA(isA<ResumableUploadCancelledException>()),
    );
    expect(await storage.resumableUploads(), isEmpty);
    expect(await storage.from(bucketId).exists('cancelled.bin'), isFalse);
  });
}
