import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// All Storage access for the example lives here, so the UI stays thin and every
/// `supabase.storage` call is easy to read and to exercise from an integration
/// test.
class StorageRepository {
  StorageRepository(this._client);

  final SupabaseClient _client;

  /// Public bucket created by the example migration. Being public lets the
  /// gallery load images straight from their public URL without a signed URL.
  static const bucket = 'images';

  StorageFileApi get _files => _client.storage.from(bucket);

  /// Uploads [bytes] under [name] and returns the stored path.
  ///
  /// `upsert: true` overwrites an object that already has the same name instead
  /// of failing, and `contentType` tells Storage the bytes are a PNG.
  Future<String> uploadImage({
    required String name,
    required Uint8List bytes,
  }) {
    return _files.uploadBinary(
      name,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
    );
  }

  /// Lists the images in the bucket, newest first.
  ///
  /// `list()` also returns folder placeholders, which have no `id`, so those are
  /// filtered out before mapping to [StoredImage].
  Future<List<StoredImage>> listImages() async {
    final files = await _files.list(
      searchOptions: const SearchOptions(
        sortBy: SortBy(column: 'created_at', order: 'desc'),
      ),
    );
    return files
        .where((file) => file.id != null)
        .map(StoredImage.fromFileObject)
        .toList();
  }

  /// Builds a public URL for [path], optionally applying an image
  /// [transform] server-side. `Image.network` can render the result directly.
  String imageUrl(String path, {TransformOptions? transform}) {
    return _files.getPublicUrl(path, transform: transform);
  }

  /// Downloads the bytes for [path], optionally applying an image [transform]
  /// server-side before the bytes are returned.
  Future<Uint8List> downloadImage(String path, {TransformOptions? transform}) {
    return _files.download(path, transform: transform);
  }

  /// Deletes [path] from the bucket.
  Future<void> deleteImage(String path) async {
    await _files.remove([path]);
  }
}
