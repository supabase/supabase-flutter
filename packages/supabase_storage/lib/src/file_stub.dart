// coverage:ignore-file
import 'dart:typed_data';

/// A stub for the `dart:io` [File] class.
typedef File = dynamic;

Future<void> writeStreamAtomically(
  Stream<Uint8List> bytes,
  String destination,
) {
  throw UnsupportedError('Writing a download to a file needs dart:io.');
}
