import 'package:meta/meta.dart';
import 'package:storage_client/src/fetch.dart';
import 'package:storage_client/src/vector_types.dart';
import 'package:supabase_common/supabase_common.dart';

/// Client for the Storage Vectors API, reachable through
/// `supabase.storage.vectors`.
///
/// It manages vector buckets directly and hands out bucket-scoped clients via
/// [from], which in turn hand out index-scoped clients via
/// [StorageVectorBucketApi.index].
///
/// ```dart
/// final vectors = supabase.storage.vectors;
/// await vectors.createBucket('embeddings');
///
/// final index = vectors.from('embeddings').index('documents');
/// await index.putVectors([
///   Vector(key: 'doc-1', data: [0.1, 0.2, 0.3], metadata: {'title': 'Intro'}),
/// ]);
///
/// final result = await index.queryVectors(queryVector: [0.1, 0.2, 0.3], topK: 5);
/// ```
///
/// This API is part of a public alpha and may not be available to every
/// project.
class SupabaseVectorsClient {
  final String _url;
  final Map<String, String> _headers;
  final Fetch _storageFetch;

  @internal
  SupabaseVectorsClient(this._url, this._headers, this._storageFetch);

  FetchOptions get _options => FetchOptions(_headers);

  /// Creates a new vector bucket.
  Future<void> createBucket(String name) async {
    await _storageFetch.post(
      '$_url/CreateVectorBucket',
      {'vectorBucketName': name},
      options: _options,
    );
  }

  /// Retrieves the metadata of an existing vector bucket.
  Future<VectorBucket> getBucket(String name) async {
    final response = await _storageFetch.post(
      '$_url/GetVectorBucket',
      {'vectorBucketName': name},
      options: _options,
    );
    return VectorBucket.fromJson(
      (response as Map<String, dynamic>)['vectorBucket']
          as Map<String, dynamic>,
    );
  }

  /// Lists vector buckets, optionally filtered by [prefix] and paginated with
  /// [maxResults] and [nextToken].
  Future<VectorBucketList> listBuckets({
    String? prefix,
    int? maxResults,
    String? nextToken,
  }) async {
    final response = await _storageFetch.post(
      '$_url/ListVectorBuckets',
      {
        'prefix': ?prefix,
        'maxResults': ?maxResults,
        'nextToken': ?nextToken,
      },
      options: _options,
    );
    return VectorBucketList.fromJson(response as Map<String, dynamic>);
  }

  /// Deletes a vector bucket. The bucket must have no indexes.
  Future<void> deleteBucket(String name) async {
    await _storageFetch.post(
      '$_url/DeleteVectorBucket',
      {'vectorBucketName': name},
      options: _options,
    );
  }

  /// Scopes index operations to the vector bucket named [bucketName].
  StorageVectorBucketApi from(String bucketName) {
    return StorageVectorBucketApi(_url, _headers, _storageFetch, bucketName);
  }
}

/// Index operations scoped to a single vector bucket.
///
/// Obtain an instance through [SupabaseVectorsClient.from].
class StorageVectorBucketApi {
  final String _url;
  final Map<String, String> _headers;
  final Fetch _storageFetch;

  /// The name of the vector bucket these operations are scoped to.
  final String bucketName;

  @internal
  StorageVectorBucketApi(
    this._url,
    this._headers,
    this._storageFetch,
    this.bucketName,
  );

  FetchOptions get _options => FetchOptions(_headers);

  /// Creates a new vector index in this bucket.
  ///
  /// [dimension] is the length of the vectors the index will store and
  /// [distanceMetric] the metric used for similarity queries. Keys listed in
  /// [nonFilterableMetadataKeys] can be stored on vectors but not used in query
  /// filters.
  Future<void> createIndex({
    required String name,
    required int dimension,
    required DistanceMetric distanceMetric,
    VectorDataType dataType = VectorDataType.float32,
    List<String>? nonFilterableMetadataKeys,
  }) async {
    await _storageFetch.post(
      '$_url/CreateIndex',
      {
        'vectorBucketName': bucketName,
        'indexName': name,
        'dataType': dataType.value,
        'dimension': dimension,
        'distanceMetric': distanceMetric.value,
        if (nonFilterableMetadataKeys != null)
          'metadataConfiguration': {
            'nonFilterableMetadataKeys': nonFilterableMetadataKeys,
          },
      },
      options: _options,
    );
  }

  /// Retrieves the metadata of an index in this bucket.
  Future<VectorIndex> getIndex(String name) async {
    final response = await _storageFetch.post(
      '$_url/GetIndex',
      {'vectorBucketName': bucketName, 'indexName': name},
      options: _options,
    );
    return VectorIndex.fromJson(
      (response as Map<String, dynamic>)['index'] as Map<String, dynamic>,
    );
  }

  /// Lists indexes in this bucket, optionally filtered by [prefix] and
  /// paginated with [maxResults] and [nextToken].
  Future<VectorIndexList> listIndexes({
    String? prefix,
    int? maxResults,
    String? nextToken,
  }) async {
    final response = await _storageFetch.post(
      '$_url/ListIndexes',
      {
        'vectorBucketName': bucketName,
        'prefix': ?prefix,
        'maxResults': ?maxResults,
        'nextToken': ?nextToken,
      },
      options: _options,
    );
    return VectorIndexList.fromJson(response as Map<String, dynamic>);
  }

  /// Deletes an index and all of its vectors from this bucket.
  Future<void> deleteIndex(String name) async {
    await _storageFetch.post(
      '$_url/DeleteIndex',
      {'vectorBucketName': bucketName, 'indexName': name},
      options: _options,
    );
  }

  /// Scopes vector data operations to the index named [indexName] in this
  /// bucket.
  StorageVectorIndexApi index(String indexName) {
    return StorageVectorIndexApi(
      _url,
      _headers,
      _storageFetch,
      bucketName,
      indexName,
    );
  }
}

/// Vector data operations scoped to a single index within a bucket.
///
/// Obtain an instance through [StorageVectorBucketApi.index].
class StorageVectorIndexApi {
  final String _url;
  final Map<String, String> _headers;
  final Fetch _storageFetch;

  /// The name of the vector bucket these operations are scoped to.
  final String bucketName;

  /// The name of the index these operations are scoped to.
  final String indexName;

  @internal
  StorageVectorIndexApi(
    this._url,
    this._headers,
    this._storageFetch,
    this.bucketName,
    this.indexName,
  );

  FetchOptions get _options => FetchOptions(_headers);

  /// Inserts or updates a batch of [vectors] in this index.
  ///
  /// The batch must contain between 1 and 500 vectors.
  Future<void> putVectors(List<Vector> vectors) async {
    if (vectors.isEmpty || vectors.length > 500) {
      throw ArgumentError('Vector batch size must be between 1 and 500 items');
    }
    await _storageFetch.post(
      '$_url/PutVectors',
      {
        'vectorBucketName': bucketName,
        'indexName': indexName,
        'vectors': vectors.map((vector) => vector.toJson()).toList(),
      },
      options: _options,
    );
  }

  /// Retrieves vectors by their [keys].
  ///
  /// Set [returnData] and [returnMetadata] to include the embeddings and
  /// metadata in the result. Keys that do not exist are omitted from the
  /// returned list.
  Future<List<VectorMatch>> getVectors({
    required List<String> keys,
    bool? returnData,
    bool? returnMetadata,
  }) async {
    final response = await _storageFetch.post(
      '$_url/GetVectors',
      {
        'vectorBucketName': bucketName,
        'indexName': indexName,
        'keys': keys,
        'returnData': ?returnData,
        'returnMetadata': ?returnMetadata,
      },
      options: _options,
    );
    final vectors =
        (response as Map<String, dynamic>)['vectors'] as List? ?? const [];
    return vectors
        .map((value) => VectorMatch.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  /// Lists vectors in this index with pagination.
  ///
  /// A full-index scan can be distributed across multiple workers by giving
  /// each worker a different [segmentIndex] (0 to `segmentCount - 1`) for the
  /// same [segmentCount] (1 to 16).
  Future<VectorList> listVectors({
    int? maxResults,
    String? nextToken,
    bool? returnData,
    bool? returnMetadata,
    int? segmentCount,
    int? segmentIndex,
  }) async {
    if (segmentCount != null) {
      if (segmentCount < 1 || segmentCount > 16) {
        throw ArgumentError('segmentCount must be between 1 and 16');
      }
      if (segmentIndex != null &&
          (segmentIndex < 0 || segmentIndex >= segmentCount)) {
        throw ArgumentError(
          'segmentIndex must be between 0 and ${segmentCount - 1}',
        );
      }
    }
    final response = await _storageFetch.post(
      '$_url/ListVectors',
      {
        'vectorBucketName': bucketName,
        'indexName': indexName,
        'maxResults': ?maxResults,
        'nextToken': ?nextToken,
        'returnData': ?returnData,
        'returnMetadata': ?returnMetadata,
        'segmentCount': ?segmentCount,
        'segmentIndex': ?segmentIndex,
      },
      options: _options,
    );
    return VectorList.fromJson(response as Map<String, dynamic>);
  }

  /// Searches this index for the vectors most similar to [queryVector].
  ///
  /// [topK] limits the number of matches returned. [filter] restricts the
  /// search to vectors whose metadata matches the given expression. Set
  /// [returnDistance] and [returnMetadata] to include the distance scores and
  /// metadata in the result.
  Future<VectorQueryResult> queryVectors({
    required List<double> queryVector,
    int? topK,
    Map<String, dynamic>? filter,
    bool? returnDistance,
    bool? returnMetadata,
  }) async {
    final response = await _storageFetch.post(
      '$_url/QueryVectors',
      {
        'vectorBucketName': bucketName,
        'indexName': indexName,
        'queryVector': {'float32': queryVector},
        'topK': ?topK,
        'filter': ?filter,
        'returnDistance': ?returnDistance,
        'returnMetadata': ?returnMetadata,
      },
      options: _options,
    );
    return VectorQueryResult.fromJson(response as Map<String, dynamic>);
  }

  /// Deletes vectors by their [keys].
  ///
  /// The batch must contain between 1 and 500 keys.
  Future<void> deleteVectors(List<String> keys) async {
    if (keys.isEmpty || keys.length > 500) {
      throw ArgumentError('Keys batch size must be between 1 and 500 items');
    }
    await _storageFetch.post(
      '$_url/DeleteVectors',
      {
        'vectorBucketName': bucketName,
        'indexName': indexName,
        'keys': keys,
      },
      options: _options,
    );
  }
}
