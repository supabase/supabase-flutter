import 'package:meta/meta.dart';

/// Supported data types for vector components.
///
/// Currently the S3 Vectors service only supports 32-bit floats.
@experimental
enum VectorDataType {
  float32;

  /// The value sent to and returned by the storage API.
  String get value => name.toLowerCase();
}

/// Distance metric used when comparing vectors during a similarity search.
@experimental
enum DistanceMetric {
  cosine,
  euclidean,
  dotProduct;

  /// The value sent to and returned by the storage API.
  String get value => name.toLowerCase();
}

VectorDataType? _vectorDataTypeFromValue(Object? value) {
  for (final type in VectorDataType.values) {
    if (type.value == value) return type;
  }
  return null;
}

DistanceMetric? _distanceMetricFromValue(Object? value) {
  for (final metric in DistanceMetric.values) {
    if (metric.value == value) return metric;
  }
  return null;
}

List<double>? _parseFloat32(Object? data) {
  if (data is! Map) return null;
  final float32 = data['float32'];
  if (float32 is! List) return null;
  return float32.map((value) => (value as num).toDouble()).toList();
}

DateTime? _parseUnixSeconds(Object? value) {
  if (value is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    (value * 1000).round(),
    isUtc: true,
  );
}

/// Encryption settings attached to a vector bucket.
@experimental
class VectorBucketEncryption {
  /// The ARN of the KMS key used to encrypt the bucket, if any.
  final String? kmsKeyArn;

  /// The server-side encryption type applied to the bucket.
  final String? sseType;

  const VectorBucketEncryption({this.kmsKeyArn, this.sseType});

  factory VectorBucketEncryption.fromJson(Map<String, dynamic> json) {
    return VectorBucketEncryption(
      kmsKeyArn: json['kmsKeyArn'] as String?,
      sseType: json['sseType'] as String?,
    );
  }
}

/// Metadata describing a vector bucket.
@experimental
class VectorBucket {
  /// The unique name of the vector bucket.
  final String name;

  /// When the bucket was created, in UTC. `null` when the server does not
  /// include it (for example in list responses).
  final DateTime? creationTime;

  /// The bucket's encryption configuration, when present.
  final VectorBucketEncryption? encryption;

  const VectorBucket({
    required this.name,
    this.creationTime,
    this.encryption,
  });

  factory VectorBucket.fromJson(Map<String, dynamic> json) {
    final encryption = json['encryptionConfiguration'];
    return VectorBucket(
      name: json['vectorBucketName'] as String,
      creationTime: _parseUnixSeconds(json['creationTime']),
      encryption: encryption is Map<String, dynamic>
          ? VectorBucketEncryption.fromJson(encryption)
          : null,
    );
  }
}

/// Metadata describing a vector index within a bucket.
@experimental
class VectorIndex {
  /// The unique name of the index within its bucket.
  final String name;

  /// The name of the parent vector bucket. `null` when the server does not
  /// include it (for example in list responses).
  final String? bucketName;

  /// The data type of the vector components. `null` for values the client does
  /// not recognize.
  final VectorDataType? dataType;

  /// The dimensionality of the vectors stored in this index.
  final int? dimension;

  /// The distance metric used for similarity queries. `null` for values the
  /// client does not recognize.
  final DistanceMetric? distanceMetric;

  /// Metadata keys that are stored but cannot be used in query filters.
  final List<String>? nonFilterableMetadataKeys;

  /// When the index was created, in UTC. `null` when the server does not
  /// include it.
  final DateTime? creationTime;

  const VectorIndex({
    required this.name,
    this.bucketName,
    this.dataType,
    this.dimension,
    this.distanceMetric,
    this.nonFilterableMetadataKeys,
    this.creationTime,
  });

  factory VectorIndex.fromJson(Map<String, dynamic> json) {
    final metadataConfiguration = json['metadataConfiguration'];
    final nonFilterableMetadataKeys =
        metadataConfiguration is Map<String, dynamic>
        ? metadataConfiguration['nonFilterableMetadataKeys']
        : null;
    return VectorIndex(
      name: json['indexName'] as String,
      bucketName: json['vectorBucketName'] as String?,
      dataType: _vectorDataTypeFromValue(json['dataType']),
      dimension: (json['dimension'] as num?)?.toInt(),
      distanceMetric: _distanceMetricFromValue(json['distanceMetric']),
      nonFilterableMetadataKeys: nonFilterableMetadataKeys is List
          ? nonFilterableMetadataKeys.cast<String>()
          : null,
      creationTime: _parseUnixSeconds(json['creationTime']),
    );
  }
}

/// A single vector to insert or update through
/// [StorageVectorIndexApi.putVectors].
@experimental
class Vector {
  /// The unique key identifying the vector within its index.
  final String key;

  /// The vector embedding. Its length must match the index dimension.
  final List<double> data;

  /// Optional arbitrary metadata stored alongside the vector.
  final Map<String, dynamic>? metadata;

  const Vector({
    required this.key,
    required this.data,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'data': {'float32': data},
      'metadata': ?metadata,
    };
  }
}

/// A vector returned from a get, list or query operation.
///
/// [data], [metadata] and [distance] are only populated when the corresponding
/// operation was asked to return them.
@experimental
class VectorMatch {
  /// The unique key identifying the vector within its index.
  final String key;

  /// The vector embedding, when requested.
  final List<double>? data;

  /// The arbitrary metadata stored alongside the vector, when requested.
  final Map<String, dynamic>? metadata;

  /// The similarity distance from the query vector. Only present in query
  /// results when distances were requested.
  final double? distance;

  const VectorMatch({
    required this.key,
    this.data,
    this.metadata,
    this.distance,
  });

  factory VectorMatch.fromJson(Map<String, dynamic> json) {
    return VectorMatch(
      key: json['key'] as String,
      data: _parseFloat32(json['data']),
      metadata: json['metadata'] as Map<String, dynamic>?,
      distance: (json['distance'] as num?)?.toDouble(),
    );
  }
}

/// The result of [SupabaseVectorsClient.listBuckets].
@experimental
class VectorBucketList {
  /// The buckets in this page.
  final List<VectorBucket> buckets;

  /// The token to pass as `nextToken` to fetch the next page, if any.
  final String? nextToken;

  const VectorBucketList({
    required this.buckets,
    this.nextToken,
  });

  factory VectorBucketList.fromJson(Map<String, dynamic> json) {
    final buckets = json['vectorBuckets'] as List? ?? const [];
    return VectorBucketList(
      buckets: buckets
          .map((value) => VectorBucket.fromJson(value as Map<String, dynamic>))
          .toList(),
      nextToken: json['nextToken'] as String?,
    );
  }
}

/// The result of [StorageVectorBucketApi.listIndexes].
@experimental
class VectorIndexList {
  /// The indexes in this page.
  final List<VectorIndex> indexes;

  /// The token to pass as `nextToken` to fetch the next page, if any.
  final String? nextToken;

  const VectorIndexList({
    required this.indexes,
    this.nextToken,
  });

  factory VectorIndexList.fromJson(Map<String, dynamic> json) {
    final indexes = json['indexes'] as List? ?? const [];
    return VectorIndexList(
      indexes: indexes
          .map((value) => VectorIndex.fromJson(value as Map<String, dynamic>))
          .toList(),
      nextToken: json['nextToken'] as String?,
    );
  }
}

/// The result of [StorageVectorIndexApi.listVectors].
@experimental
class VectorList {
  /// The vectors in this page.
  final List<VectorMatch> vectors;

  /// The token to pass as `nextToken` to fetch the next page, if any.
  final String? nextToken;

  const VectorList({
    required this.vectors,
    this.nextToken,
  });

  factory VectorList.fromJson(Map<String, dynamic> json) {
    final vectors = json['vectors'] as List? ?? const [];
    return VectorList(
      vectors: vectors
          .map((value) => VectorMatch.fromJson(value as Map<String, dynamic>))
          .toList(),
      nextToken: json['nextToken'] as String?,
    );
  }
}

/// The result of [StorageVectorIndexApi.queryVectors].
@experimental
class VectorQueryResult {
  /// The matching vectors ordered by ascending distance from the query vector.
  final List<VectorMatch> matches;

  /// The distance metric the server used for the search. `null` for values the
  /// client does not recognize.
  final DistanceMetric? distanceMetric;

  const VectorQueryResult({
    required this.matches,
    this.distanceMetric,
  });

  factory VectorQueryResult.fromJson(Map<String, dynamic> json) {
    final matches = json['vectors'] as List? ?? const [];
    return VectorQueryResult(
      matches: matches
          .map((value) => VectorMatch.fromJson(value as Map<String, dynamic>))
          .toList(),
      distanceMetric: _distanceMetricFromValue(json['distanceMetric']),
    );
  }
}
