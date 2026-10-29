import 'dart:typed_data';

import 'types.dart';

import 'file_stub.dart' if (dart.library.io) './file_io.dart';

/// Helpers that consume a stream of downloaded bytes, such as the one
/// returned by `StorageFileApi.downloadStream`.
extension StorageByteStream on Stream<Uint8List> {
  /// Collects the stream into one [Uint8List].
  ///
  /// With [maxBytes], the bytes are counted as they arrive, after any decoding
  /// by the HTTP stack. Once they exceed [maxBytes] the subscription is
  /// cancelled, which closes the connection, what was collected is discarded,
  /// and a [StorageDownloadTooLargeException] is thrown. Without it, the whole
  /// body is collected.
  Future<Uint8List> collectBytes({int? maxBytes}) async {
    if (maxBytes != null && maxBytes < 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'Must not be negative');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in this) {
      if (maxBytes != null && builder.length + chunk.length > maxBytes) {
        builder.clear();
        throw StorageDownloadTooLargeException(maxBytes);
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Writes the stream to the file at [path] atomically.
  ///
  /// The bytes go to a new temporary file in the same directory, which is
  /// renamed over [path] once the stream has ended without an error. On any
  /// failure or cancellation the temporary file is deleted and [path] is left
  /// untouched. The directory of [path] must exist and is not created.
  ///
  /// Throws an [UnsupportedError] on the web.
  Future<void> writeToFile(String path) => writeStreamAtomically(this, path);
}
