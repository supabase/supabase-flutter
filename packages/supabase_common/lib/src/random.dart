import 'dart:math';
import 'dart:typed_data';

final Random _secureRandom = Random.secure();

/// [length] bytes from a cryptographically secure random source.
Uint8List randomBytes(int length) => Uint8List.fromList(
  List.generate(length, (_) => _secureRandom.nextInt(256)),
);

/// A lowercase hex string of [length] bytes from a cryptographically secure
/// random source, so twice as many characters as [length].
String randomHex(int length) => randomBytes(
  length,
).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
