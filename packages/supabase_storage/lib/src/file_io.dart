import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

export 'dart:io' show File;

@internal
Future<void> writeStreamAtomically(
  Stream<Uint8List> bytes,
  String destination,
) async {
  final random = Random.secure();
  File? temporary;
  while (temporary == null) {
    final candidate = File(
      '$destination.${random.nextInt(1 << 32).toRadixString(16)}.tmp',
    );
    try {
      await candidate.create(exclusive: true);
      temporary = candidate;
    } on PathExistsException {
      continue;
    }
  }

  try {
    final file = await temporary.open(mode: FileMode.write);
    try {
      await for (final chunk in bytes) {
        await file.writeFrom(chunk);
      }
    } finally {
      await file.close();
    }
    await temporary.rename(destination);
  } catch (_) {
    try {
      await temporary.delete();
    } on FileSystemException {
      // The temporary file is already gone.
    }
    rethrow;
  }
}
