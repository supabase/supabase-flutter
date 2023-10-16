import 'dart:typed_data';

/// A stub for the `dart:io` [File] class. Only the methods used by the storage client are stubbed.
class File {
  String get path => throw UnimplementedError();

  Uint8List readAsBytesSync() => throw UnimplementedError();
}
