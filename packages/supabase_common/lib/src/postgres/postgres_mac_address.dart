part of 'postgres_values.dart';

/// A hardware address, the value of a Postgres `macaddr` column with six
/// [bytes] or of a `macaddr8` column with eight.
///
/// A `macaddr` column rejects an address of eight bytes. A `macaddr8` column
/// stores an address of six bytes in the EUI-64 form, with `ff:fe` inserted
/// in the middle, so it reads back as a different, eight byte address.
///
/// ```dart
/// PostgresMacAddress.parse('08:00:2b:01:02:03').bytes // [8, 0, 43, 1, 2, 3]
/// PostgresMacAddress([8, 0, 43, 1, 2, 3]).literal     // 08:00:2b:01:02:03
/// ```
@experimental
final class PostgresMacAddress implements PostgresValue {
  /// The address made of [bytes], six for a `macaddr` and eight for a
  /// `macaddr8`.
  ///
  /// Throws an [ArgumentError] when there are not six or eight bytes, or one
  /// of them is outside 0 to 255.
  PostgresMacAddress(List<int> bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (bytes.length != 6 && bytes.length != 8) {
      throw ArgumentError.value(bytes, 'bytes', 'Must hold 6 or 8 bytes');
    }
    if (bytes.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError.value(bytes, 'bytes', 'Must be between 0 and 255');
    }
  }

  /// Parses a MAC address of six or eight bytes written as hexadecimal
  /// digits in groups of whole bytes, separated by one of `:`, `-` or `.`
  /// throughout or not at all, as in `08:00:2b:01:02:03`,
  /// `08-00-2B-01-02-03`, `08002b:010203` or `0800.2b01.0203`.
  ///
  /// Throws a [FormatException] when [literal] is not a MAC address.
  factory PostgresMacAddress.parse(String literal) {
    final text = literal.trim();
    final separator = RegExp('[:.-]').firstMatch(text)?[0];
    final groups = separator == null ? [text] : text.split(separator);
    final digits = groups.join();
    if ((digits.length != 12 && digits.length != 16) ||
        groups.any((group) => group.isEmpty || group.length.isOdd) ||
        !RegExp(r'^[0-9A-Fa-f]+$').hasMatch(digits)) {
      throw FormatException('Not a MAC address', literal);
    }
    return PostgresMacAddress([
      for (var index = 0; index < digits.length; index += 2)
        int.parse(digits.substring(index, index + 2), radix: 16),
    ]);
  }

  /// The six or eight bytes of the address, in transmission order.
  final Uint8List bytes;

  /// The literal Postgres emits: the bytes in lowercase hexadecimal separated
  /// by colons, `08:00:2b:01:02:03`.
  @override
  String get literal => [
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join(':');

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) {
    if (other is! PostgresMacAddress || other.bytes.length != bytes.length) {
      return false;
    }
    for (var index = 0; index < bytes.length; index++) {
      if (other.bytes[index] != bytes[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(bytes);
}
