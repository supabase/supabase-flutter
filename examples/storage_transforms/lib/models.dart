import 'package:supabase_flutter/supabase_flutter.dart';

/// A single image stored in the bucket, built from the Storage [FileObject]
/// returned by `list()`.
class StoredImage {
  const StoredImage({required this.path, this.createdAt});

  factory StoredImage.fromFileObject(FileObject file) => StoredImage(
    path: file.name,
    createdAt: file.createdAt == null
        ? null
        : DateTime.tryParse(file.createdAt!),
  );

  /// Path within the bucket, which is also the object's file name here.
  final String path;
  final DateTime? createdAt;
}

/// A named image transformation shown in the detail view.
///
/// Each preset maps to the Storage [TransformOptions] passed to `getPublicUrl`
/// and `download`. The [original] preset carries no options, so it requests the
/// untransformed image.
enum TransformPreset {
  original('Original', null),
  thumbnail(
    '120×120 cover',
    TransformOptions(width: 120, height: 120, resize: ResizeMode.cover),
  ),
  fit(
    '300×160 contain',
    TransformOptions(width: 300, height: 160, resize: ResizeMode.contain),
  ),
  lowQuality(
    '320 wide · quality 20',
    TransformOptions(width: 320, quality: 20),
  );

  const TransformPreset(this.label, this.options);

  final String label;
  final TransformOptions? options;
}
