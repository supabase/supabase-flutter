import 'package:meta/meta.dart';

/// The JSON form of a storage object named [name], as the storage API lists
/// it and as `FileObject.fromJson` reads it.
@visibleForTesting
Map<String, dynamic> storageObjectJson(
  String name, {
  String id = 'e7b5c1d2-4c7a-4f3e-9c1a-2b3d4e5f6a7b',
  String bucketId = 'test-bucket',
  String? owner,
  Map<String, dynamic>? metadata,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = (createdAt ?? DateTime.utc(2023, 4, 1, 9, 38, 59))
      .toIso8601String();
  final updated = (updatedAt ?? DateTime.utc(2023, 4, 1, 9, 38, 59))
      .toIso8601String();
  return {
    'id': id,
    'name': name,
    'bucket_id': bucketId,
    'owner': owner,
    'created_at': created,
    'updated_at': updated,
    'last_accessed_at': updated,
    'metadata':
        metadata ??
        {
          'size': 1024,
          'mimetype': 'application/octet-stream',
          'cacheControl': 'max-age=3600',
        },
  };
}
