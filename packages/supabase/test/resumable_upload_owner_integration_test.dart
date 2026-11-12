@Tags(['integration'])
library;

import 'dart:typed_data';

import 'package:supabase/supabase.dart';
import 'package:supabase_common/supabase_common.dart' show projectRef;
import 'package:test/test.dart';

import 'utils.dart';

// The bucket is covered by the policies of the storage_owner_folders
// migration: a signed-in user may only write and read the objects under a
// folder named after their user id.
void main() {
  final runId = DateTime.now().millisecondsSinceEpoch;
  final bucketId = 'owner-folders-$runId';
  final recordsKey = 'sb-${projectRef(localStackUrl)}-resumable-uploads';
  const password = 'owner-folders-password';
  final data = Uint8List.fromList(
    List.generate(
      ResumableUploadOptions.defaultChunkSize * 2 + 1000,
      (index) => index % 251,
    ),
  );
  final userIds = <String>[];
  late SupabaseClient admin;
  late MemoryResumableUploadStorage ownerRecords;
  late MemoryResumableUploadStorage otherRecords;
  late SupabaseClient owner;
  late SupabaseClient other;

  SupabaseClient createClient(String key, ResumableUploadStorage records) =>
      SupabaseClient(
        localStackUrl,
        key,
        authOptions: AuthClientOptions(asyncStorage: TestAsyncStorage()),
        storageOptions: StorageClientOptions(
          resumableUploadOptions: ResumableUploadOptions(storage: records),
        ),
      );

  Future<SupabaseClient> signedIn(
    String name,
    ResumableUploadStorage records,
  ) async {
    final email = '$name-$runId@example.com';
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(email: email, password: password, emailConfirm: true),
    );
    userIds.add(created.user!.id);
    final client = createClient(localStackAnonKey, records);
    await client.auth.signInWithPassword(email: email, password: password);
    return client;
  }

  setUp(() async {
    admin = createClient(
      localStackServiceRoleKey,
      MemoryResumableUploadStorage(),
    );
    await admin.storage.createBucket(bucketId);
    ownerRecords = MemoryResumableUploadStorage();
    otherRecords = MemoryResumableUploadStorage();
    owner = await signedIn('owner', ownerRecords);
    other = await signedIn('other', otherRecords);
  });

  tearDown(() async {
    await owner.dispose();
    await other.dispose();
    await admin.storage.emptyBucket(bucketId);
    await admin.storage.deleteBucket(bucketId);
    for (final id in userIds) {
      await admin.auth.admin.deleteUser(id);
    }
    userIds.clear();
    await admin.dispose();
  });

  test(
    'another user cannot continue, cancel or read a resumable upload',
    () async {
      final path = '${owner.auth.currentUser!.id}/video.bin';
      final upload = owner.storage
          .from(bucketId)
          .resumableUploadBinary(path, data);
      // The second chunk is only sent once the server holds the first.
      await upload.progress.firstWhere(
        (progress) =>
            progress.bytesUploaded > ResumableUploadOptions.defaultChunkSize,
      );
      upload.pause();
      final record = (await ownerRecords.getItem(recordsKey))!;

      await otherRecords.setItem(recordsKey, record);
      final continued = await other.storage.resumeUploadBinary(
        upload.id,
        data,
      );
      await expectLater(
        continued.done,
        throwsA(
          isA<StorageApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        ),
      );

      await otherRecords.setItem(recordsKey, record);
      await other.storage.discardResumableUpload(upload.id);

      final bytesUploaded = upload.progress
          .map((progress) => progress.bytesUploaded)
          .toList();
      upload.resume();
      await upload.done;

      expect(
        await bytesUploaded,
        everyElement(
          greaterThanOrEqualTo(ResumableUploadOptions.defaultChunkSize),
        ),
      );
      expect(await owner.storage.from(bucketId).download(path), data);
      await expectLater(
        other.storage.from(bucketId).download(path),
        throwsA(isA<StorageException>()),
      );
    },
  );
}
