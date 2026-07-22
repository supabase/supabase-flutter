import 'dart:convert';

import 'package:http/http.dart';
import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

const storageUrl = 'http://localhost/storage/v1';
const headers = {'Authorization': 'Bearer token'};

void main() {
  late CustomHttpClient mockClient;
  late SupabaseVectorsClient vectors;

  setUp(() {
    mockClient = CustomHttpClient();
    mockClient.statusCode = 200;
    mockClient.response = <String, dynamic>{};
    vectors = SupabaseStorageClient(
      storageUrl,
      headers,
      httpClient: mockClient,
    ).vectors;
  });

  Request lastRequest() => mockClient.receivedRequests.single as Request;

  Map<String, dynamic> lastBody() =>
      jsonDecode(lastRequest().body) as Map<String, dynamic>;

  group('vector buckets', () {
    test('createBucket posts the bucket name', () async {
      await vectors.createBucket('embeddings');

      expect(
        lastRequest().url.toString(),
        'http://localhost/storage/v1/vector/CreateVectorBucket',
      );
      expect(lastRequest().method, 'POST');
      expect(lastBody(), {'vectorBucketName': 'embeddings'});
    });

    test('getBucket parses the bucket metadata', () async {
      mockClient.response = {
        'vectorBucket': {
          'vectorBucketName': 'embeddings',
          'creationTime': 1700000000,
          'encryptionConfiguration': {'sseType': 'AES256'},
        },
      };

      final bucket = await vectors.getBucket('embeddings');

      expect(
        lastRequest().url.toString(),
        'http://localhost/storage/v1/vector/GetVectorBucket',
      );
      expect(bucket.name, 'embeddings');
      expect(
        bucket.creationTime,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
      expect(bucket.encryption?.sseType, 'AES256');
    });

    test('listBuckets sends filters and parses buckets and cursor', () async {
      mockClient.response = {
        'vectorBuckets': [
          {'vectorBucketName': 'embeddings-a'},
          {'vectorBucketName': 'embeddings-b'},
        ],
        'nextToken': 'cursor-1',
      };

      final result = await vectors.listBuckets(
        prefix: 'embeddings-',
        maxResults: 10,
      );

      expect(lastBody(), {'prefix': 'embeddings-', 'maxResults': 10});
      expect(result.buckets.map((bucket) => bucket.name), [
        'embeddings-a',
        'embeddings-b',
      ]);
      expect(result.nextToken, 'cursor-1');
    });

    test('deleteBucket posts the bucket name', () async {
      await vectors.deleteBucket('embeddings');

      expect(
        lastRequest().url.toString(),
        'http://localhost/storage/v1/vector/DeleteVectorBucket',
      );
      expect(lastBody(), {'vectorBucketName': 'embeddings'});
    });
  });

  group('vector indexes', () {
    test('createIndex sends the full configuration', () async {
      await vectors
          .from('embeddings')
          .createIndex(
            name: 'documents',
            dimension: 1536,
            distanceMetric: DistanceMetric.cosine,
            nonFilterableMetadataKeys: ['raw_text'],
          );

      expect(
        lastRequest().url.toString(),
        'http://localhost/storage/v1/vector/CreateIndex',
      );
      expect(lastBody(), {
        'vectorBucketName': 'embeddings',
        'indexName': 'documents',
        'dataType': 'float32',
        'dimension': 1536,
        'distanceMetric': 'cosine',
        'metadataConfiguration': {
          'nonFilterableMetadataKeys': ['raw_text'],
        },
      });
    });

    test('getIndex parses the index metadata', () async {
      mockClient.response = {
        'index': {
          'indexName': 'documents',
          'vectorBucketName': 'embeddings',
          'dataType': 'float32',
          'dimension': 1536,
          'distanceMetric': 'euclidean',
          'metadataConfiguration': {
            'nonFilterableMetadataKeys': ['raw_text'],
          },
        },
      };

      final index = await vectors.from('embeddings').getIndex('documents');

      expect(index.name, 'documents');
      expect(index.bucketName, 'embeddings');
      expect(index.dataType, VectorDataType.float32);
      expect(index.dimension, 1536);
      expect(index.distanceMetric, DistanceMetric.euclidean);
      expect(index.nonFilterableMetadataKeys, ['raw_text']);
    });

    test('getIndex leaves unknown enum values null', () async {
      mockClient.response = {
        'index': {
          'indexName': 'documents',
          'distanceMetric': 'manhattan',
        },
      };

      final index = await vectors.from('embeddings').getIndex('documents');

      expect(index.distanceMetric, isNull);
    });

    test('listIndexes parses indexes and cursor', () async {
      mockClient.response = {
        'indexes': [
          {'indexName': 'documents'},
          {'indexName': 'images'},
        ],
        'nextToken': 'cursor-2',
      };

      final result = await vectors.from('embeddings').listIndexes();

      expect(result.indexes.map((index) => index.name), [
        'documents',
        'images',
      ]);
      expect(result.nextToken, 'cursor-2');
    });

    test('deleteIndex posts the bucket and index names', () async {
      await vectors.from('embeddings').deleteIndex('documents');

      expect(lastBody(), {
        'vectorBucketName': 'embeddings',
        'indexName': 'documents',
      });
    });
  });

  group('vector data', () {
    StorageVectorIndexApi index() =>
        vectors.from('embeddings').index('documents');

    test('putVectors serializes the batch', () async {
      await index().putVectors([
        Vector(key: 'doc-1', data: [0.1, 0.2, 0.3], metadata: {'page': 1}),
        Vector(key: 'doc-2', data: [0.4, 0.5, 0.6]),
      ]);

      expect(
        lastRequest().url.toString(),
        'http://localhost/storage/v1/vector/PutVectors',
      );
      expect(lastBody(), {
        'vectorBucketName': 'embeddings',
        'indexName': 'documents',
        'vectors': [
          {
            'key': 'doc-1',
            'data': {
              'float32': [0.1, 0.2, 0.3],
            },
            'metadata': {'page': 1},
          },
          {
            'key': 'doc-2',
            'data': {
              'float32': [0.4, 0.5, 0.6],
            },
          },
        ],
      });
    });

    test('putVectors rejects an empty batch', () {
      expect(
        index().putVectors([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('putVectors rejects a batch larger than 500', () {
      final batch = List.generate(
        501,
        (i) => Vector(key: 'doc-$i', data: const [0.1]),
      );
      expect(
        index().putVectors(batch),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getVectors parses the returned vectors', () async {
      mockClient.response = {
        'vectors': [
          {
            'key': 'doc-1',
            'data': {
              'float32': [0.1, 0.2, 0.3],
            },
            'metadata': {'title': 'Intro'},
          },
        ],
      };

      final result = await index().getVectors(
        keys: ['doc-1'],
        returnData: true,
        returnMetadata: true,
      );

      expect(lastBody(), {
        'vectorBucketName': 'embeddings',
        'indexName': 'documents',
        'keys': ['doc-1'],
        'returnData': true,
        'returnMetadata': true,
      });
      expect(result.single.key, 'doc-1');
      expect(result.single.data, [0.1, 0.2, 0.3]);
      expect(result.single.metadata, {'title': 'Intro'});
    });

    test('listVectors parses vectors and cursor', () async {
      mockClient.response = {
        'vectors': [
          {'key': 'doc-1'},
          {'key': 'doc-2'},
        ],
        'nextToken': 'cursor-3',
      };

      final result = await index().listVectors(maxResults: 2);

      expect(result.vectors.map((vector) => vector.key), ['doc-1', 'doc-2']);
      expect(result.nextToken, 'cursor-3');
    });

    test('listVectors sends parallel scan segments', () async {
      await index().listVectors(segmentCount: 4, segmentIndex: 2);

      expect(lastBody(), {
        'vectorBucketName': 'embeddings',
        'indexName': 'documents',
        'segmentCount': 4,
        'segmentIndex': 2,
      });
    });

    test('listVectors rejects an out-of-range segmentCount', () {
      expect(
        index().listVectors(segmentCount: 17),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('listVectors rejects a segmentIndex outside the segment count', () {
      expect(
        index().listVectors(segmentCount: 4, segmentIndex: 4),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('queryVectors sends the query vector and parses matches', () async {
      mockClient.response = {
        'vectors': [
          {
            'key': 'doc-1',
            'distance': 0.02,
            'metadata': {'title': 'Intro'},
          },
        ],
        'distanceMetric': 'cosine',
      };

      final result = await index().queryVectors(
        queryVector: [0.1, 0.2, 0.3],
        topK: 5,
        filter: {'category': 'technical'},
        returnDistance: true,
        returnMetadata: true,
      );

      expect(lastBody(), {
        'vectorBucketName': 'embeddings',
        'indexName': 'documents',
        'queryVector': {
          'float32': [0.1, 0.2, 0.3],
        },
        'topK': 5,
        'filter': {'category': 'technical'},
        'returnDistance': true,
        'returnMetadata': true,
      });
      expect(result.matches.single.key, 'doc-1');
      expect(result.matches.single.distance, 0.02);
      expect(result.distanceMetric, DistanceMetric.cosine);
    });

    test('deleteVectors posts the keys', () async {
      await index().deleteVectors(['doc-1', 'doc-2']);

      expect(lastBody(), {
        'vectorBucketName': 'embeddings',
        'indexName': 'documents',
        'keys': ['doc-1', 'doc-2'],
      });
    });

    test('deleteVectors rejects an empty batch', () {
      expect(
        index().deleteVectors([]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
