import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

const storageUrl = 'http://127.0.0.1:54421/storage/v1';
// service_role key of the local Supabase CLI stack (RS256, signed by the
// committed supabase/signing_keys.json). It bypasses RLS so the tests have
// unrestricted access.
const storageKey =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6IjNkZjU5YWIxLWI4ZWMtNDlkMy05YzkyLThiOWQ0MmNhYzFmZSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MjA5Njg5NTE5Mn0.jO5vwkRNFZTiVHNjFzaypvWV4aJkKm6TvFsdl0W5x9g7LttQMWMopC7HanUpeFLmg4E9gMb-v1e6f6oZ9e0PHYpsRwEdSOxKfYwKhzFI9DsDGLrX4ueArZuKgaV_bulWpwGKI3xwLugeuCp6N0hYFkXvMmUjaKx9nClWckJ33cchSpgjVQ5YxL8PGrUj2Sjhw-5IyGiwrdPfWjTQmpWnCjePoVrRf2jEMF_VGoxDAEqt72w_HGOrdXRFU5BW9-LkvpfzkrTENrj555JtYP4mkZgvUlrkXFRSh010o3n2UehN5WonfDRzwOeTC56QEbPVS6ubvWGR9luykdMNlXawZA';

// These tests exercise the Storage Vectors API against a live Supabase stack
// with `[storage.vector] enabled = true`. Each test provisions and tears down
// its own bucket/index, so they are self-contained and can run in any order.
void main() {
  late SupabaseVectorsClient vectors;
  final runId = DateTime.now().millisecondsSinceEpoch;
  var counter = 0;

  setUpAll(() {
    vectors = SupabaseStorageClient(storageUrl, {
      'Authorization': 'Bearer $storageKey',
    }).vectors;
  });

  String uniqueName(String prefix) => '$prefix-$runId-${counter++}';

  group('bucket lifecycle', () {
    test('create, get, list and delete a vector bucket', () async {
      final name = uniqueName('vec-bucket');

      await vectors.createBucket(name);

      final bucket = await vectors.getBucket(name);
      expect(bucket.name, name);
      expect(bucket.creationTime, isA<DateTime>());

      final list = await vectors.listBuckets(prefix: name);
      expect(list.buckets.map((entry) => entry.name), contains(name));

      await vectors.deleteBucket(name);
      await expectLater(
        vectors.getBucket(name),
        throwsA(isA<StorageException>()),
      );
    });
  });

  group('index and vector operations', () {
    late String bucketName;
    late StorageVectorBucketApi bucket;
    late StorageVectorIndexApi index;

    setUp(() async {
      bucketName = uniqueName('vec-idx');
      await vectors.createBucket(bucketName);
      bucket = vectors.from(bucketName);
      await bucket.createIndex(
        name: 'idx',
        dimension: 3,
        distanceMetric: DistanceMetric.cosine,
      );
      index = bucket.index('idx');
    });

    tearDown(() async {
      try {
        await bucket.deleteIndex('idx');
      } catch (_) {}
      try {
        await vectors.deleteBucket(bucketName);
      } catch (_) {}
    });

    test('get and list indexes', () async {
      final fetched = await bucket.getIndex('idx');
      expect(fetched.name, 'idx');
      expect(fetched.bucketName, bucketName);
      expect(fetched.dataType, VectorDataType.float32);
      expect(fetched.dimension, 3);
      expect(fetched.distanceMetric, DistanceMetric.cosine);
      expect(fetched.creationTime, isA<DateTime>());

      final list = await bucket.listIndexes();
      expect(list.indexes.map((entry) => entry.name), contains('idx'));
    });

    test('put, get and list vectors', () async {
      await index.putVectors([
        Vector(key: 'a', data: [0.1, 0.2, 0.3], metadata: {'label': 'first'}),
        Vector(key: 'b', data: [0.4, 0.5, 0.6]),
      ]);

      final fetched = await index.getVectors(
        keys: ['a'],
        returnData: true,
        returnMetadata: true,
      );
      expect(fetched.single.key, 'a');
      expect(fetched.single.data, hasLength(3));
      expect(fetched.single.metadata?['label'], 'first');

      final listed = await index.listVectors();
      expect(
        listed.vectors.map((vector) => vector.key),
        containsAll(['a', 'b']),
      );
    });

    test('query returns the nearest vector first', () async {
      await index.putVectors([
        Vector(key: 'near', data: [0.1, 0.2, 0.3]),
        Vector(key: 'far', data: [0.9, 0.1, 0.05]),
      ]);

      final result = await index.queryVectors(
        queryVector: [0.1, 0.2, 0.3],
        topK: 2,
        returnDistance: true,
      );

      expect(result.distanceMetric, DistanceMetric.cosine);
      expect(result.matches.first.key, 'near');
      expect(result.matches.first.distance, isNotNull);
    });

    test('delete removes vectors', () async {
      await index.putVectors([
        Vector(key: 'a', data: [0.1, 0.2, 0.3]),
        Vector(key: 'b', data: [0.4, 0.5, 0.6]),
      ]);

      await index.deleteVectors(['a']);

      final remaining = await index.getVectors(keys: ['a', 'b']);
      expect(remaining.map((vector) => vector.key), ['b']);
    });

    test('parallel scan segments cover every vector', () async {
      await index.putVectors([
        Vector(key: 'a', data: [0.1, 0.2, 0.3]),
        Vector(key: 'b', data: [0.4, 0.5, 0.6]),
        Vector(key: 'c', data: [0.7, 0.8, 0.9]),
      ]);

      final keys = <String>{};
      for (var segment = 0; segment < 2; segment++) {
        final page = await index.listVectors(
          segmentCount: 2,
          segmentIndex: segment,
        );
        keys.addAll(page.vectors.map((vector) => vector.key));
      }

      expect(keys, {'a', 'b', 'c'});
    });
  });
}
