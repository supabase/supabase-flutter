import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

/// Supported data types for vector components.
///
/// Currently the S3 Vectors service only supports 32-bit floats.
@experimental
enum VectorDataType {
  /// 32-bit floating point components.
  float32;

  /// The value sent to and returned by the storage API.
  String get value => name.toLowerCase();

  /// The [VectorDataType] matching the given API [value], or `null` when it is
  /// not recognized.
  static VectorDataType? fromValue(Object? value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Distance metric used when comparing vectors during a similarity search.
@experimental
enum DistanceMetric {
  /// The cosine of the angle between two vectors.
  cosine,

  /// The straight-line distance between two vectors.
  euclidean,

  /// The dot product of two vectors.
  dotProduct;

  /// The value sent to and returned by the storage API.
  String get value => name.toLowerCase();

  /// The [DistanceMetric] matching the given API [value], or `null` when it is
  /// not recognized.
  static DistanceMetric? fromValue(Object? value) {
    for (final metric in values) {
      if (metric.value == value) return metric;
    }
    return null;
  }
}

List<double>? _parseFloat32(Object? data) {
  if (data is! Map) return null;
  final float32 = data['float32'];
  if (float32 is! List) return null;
  return float32.map((value) => (value as num).toDouble()).toList();
}

/// Parses a Unix timestamp in seconds, returning `null` for anything the S3
/// Vectors API sends that is not a number.
DateTime? _parseUnixSeconds(Object? value) {
  if (value is! num) return null;
  return dateTimeFromUnixSeconds(value);
}

/// Encryption settings attached to a vector bucket.
@experimental
class VectorBucketEncryption {
  const VectorBucketEncryption({this.kmsKeyArn, this.serverSideEncryptionType});

  factory VectorBucketEncryption.fromJson(Map<String, dynamic> json) {
    return VectorBucketEncryption(
      kmsKeyArn: json['kmsKeyArn'] as String?,
      serverSideEncryptionType: json['sseType'] as String?,
    );
  }

  /// The ARN of the KMS key used to encrypt the bucket, if any.
  final String? kmsKeyArn;

  /// The server-side encryption type applied to the bucket.
  final String? serverSideEncryptionType;
}

/// Metadata describing a vector bucket.
@experimental
class VectorBucket {
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

  /// The unique name of the vector bucket.
  final String name;

  /// When the bucket was created, in UTC. `null` when the server does not
  /// include it (for example in list responses).
  final DateTime? creationTime;

  /// The bucket's encryption configuration, when present.
  final VectorBucketEncryption? encryption;
}

/// Metadata describing a vector index within a bucket.
@experimental
class VectorIndex {
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
      dataType: VectorDataType.fromValue(json['dataType']),
      dimension: (json['dimension'] as num?)?.toInt(),
      distanceMetric: DistanceMetric.fromValue(json['distanceMetric']),
      nonFilterableMetadataKeys: nonFilterableMetadataKeys is List
          ? nonFilterableMetadataKeys.cast()
          : null,
      creationTime: _parseUnixSeconds(json['creationTime']),
    );
  }

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
}

/// A single vector to insert or update through
/// [StorageVectorIndexApi.putVectors].
@experimental
class Vector {
  const Vector({
    required this.key,
    required this.data,
    this.metadata,
  });

  /// The unique key identifying the vector within its index.
  final String key;

  /// The vector embedding. Its length must match the index dimension.
  final List<double> data;

  /// Optional arbitrary metadata stored alongside the vector.
  final Map<String, dynamic>? metadata;

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

  /// The unique key identifying the vector within its index.
  final String key;

  /// The vector embedding, when requested.
  final List<double>? data;

  /// The arbitrary metadata stored alongside the vector, when requested.
  final Map<String, dynamic>? metadata;

  /// The similarity distance from the query vector. Only present in query
  /// results when distances were requested.
  final double? distance;
}

/// The result of [SupabaseVectorsClient.listBuckets].
@experimental
class VectorBucketList {
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

  /// The buckets in this page.
  final List<VectorBucket> buckets;

  /// The token to pass as `nextToken` to fetch the next page, if any.
  final String? nextToken;
}

/// The result of [StorageVectorBucketApi.listIndexes].
@experimental
class VectorIndexList {
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

  /// The indexes in this page.
  final List<VectorIndex> indexes;

  /// The token to pass as `nextToken` to fetch the next page, if any.
  final String? nextToken;
}

/// The result of [StorageVectorIndexApi.listVectors].
@experimental
class VectorList {
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

  /// The vectors in this page.
  final List<VectorMatch> vectors;

  /// The token to pass as `nextToken` to fetch the next page, if any.
  final String? nextToken;
}

/// The result of [StorageVectorIndexApi.queryVectors].
@experimental
class VectorQueryResult {
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
      distanceMetric: DistanceMetric.fromValue(json['distanceMetric']),
    );
  }

  /// The matching vectors ordered by ascending distance from the query vector.
  final List<VectorMatch> matches;

  /// The distance metric the server used for the search. `null` for values the
  /// client does not recognize.
  final DistanceMetric? distanceMetric;
}
