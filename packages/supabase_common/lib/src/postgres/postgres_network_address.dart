part of 'postgres_values.dart';

/// An IPv4 or IPv6 host or network address with its netmask, the value of a
/// Postgres `inet` or `cidr` column.
///
/// ```dart
/// PostgresNetworkAddress.parse('192.168.1.5/24').prefixLength // 24
/// PostgresNetworkAddress([10, 0, 0, 1]).literal               // 10.0.0.1
/// PostgresNetworkAddress.parse('2001:db8::1/64').isIpv6       // true
/// ```
///
/// It is written in pure Dart, so unlike `InternetAddress` of `dart:io` it
/// also works on the web.
@experimental
final class PostgresNetworkAddress implements PostgresValue {
  /// The address made of [bytes], four for IPv4 and sixteen for IPv6, with a
  /// netmask of [prefixLength] bits, by default the whole address.
  ///
  /// Throws an [ArgumentError] when there are not four or sixteen bytes, one
  /// of them is outside 0 to 255, or [prefixLength] is longer than the
  /// address.
  PostgresNetworkAddress(List<int> bytes, {int? prefixLength})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
      prefixLength = prefixLength ?? (bytes.length * 8) {
    if (bytes.length != 4 && bytes.length != 16) {
      throw ArgumentError.value(bytes, 'bytes', 'Must hold 4 or 16 bytes');
    }
    if (bytes.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError.value(bytes, 'bytes', 'Must be between 0 and 255');
    }
    if (this.prefixLength < 0 || this.prefixLength > bytes.length * 8) {
      throw ArgumentError.value(
        prefixLength,
        'prefixLength',
        'Must be between 0 and ${bytes.length * 8}',
      );
    }
  }

  /// Parses the literal Postgres emits for an `inet` or `cidr`: a dotted
  /// IPv4 or a colon-separated IPv6 address, optionally followed by
  /// `/prefixLength`, as in `192.168.1.5/24` or `2001:db8::1`.
  ///
  /// Throws a [FormatException] when [literal] is not a network address.
  factory PostgresNetworkAddress.parse(String literal) {
    final text = literal.trim();
    final slash = text.indexOf('/');
    final address = slash < 0 ? text : text.substring(0, slash);
    final bytes = address.contains(':')
        ? _parseIpv6(address)
        : _parseIpv4(address);
    if (bytes == null) {
      throw FormatException('Not a network address', literal);
    }
    if (slash < 0) return PostgresNetworkAddress(bytes);
    final prefixText = text.substring(slash + 1);
    final prefixLength = RegExp(r'^\d{1,3}$').hasMatch(prefixText)
        ? int.parse(prefixText)
        : null;
    if (prefixLength == null || prefixLength > bytes.length * 8) {
      throw FormatException('Not a network address', literal);
    }
    return PostgresNetworkAddress(bytes, prefixLength: prefixLength);
  }

  /// The four or sixteen bytes of the address, most significant first.
  final Uint8List bytes;

  /// The number of leading bits of [bytes] that form the network.
  final int prefixLength;

  /// Whether this is an IPv6 address rather than an IPv4 one.
  bool get isIpv6 => bytes.length == 16;

  /// The literal Postgres emits for an `inet`: the address in its canonical
  /// form, followed by `/prefixLength` unless the netmask covers the whole
  /// address.
  ///
  /// Postgres reads it as a `cidr` too, which prints the whole-address
  /// netmask as well, so `192.168.1.5/32` read from a `cidr` equals the
  /// address written as `192.168.1.5`.
  @override
  String get literal {
    final address = isIpv6 ? _formatIpv6(bytes) : bytes.join('.');
    return prefixLength == bytes.length * 8
        ? address
        : '$address/$prefixLength';
  }

  @override
  String toString() => literal;

  @override
  bool operator ==(Object other) {
    if (other is! PostgresNetworkAddress ||
        other.prefixLength != prefixLength ||
        other.bytes.length != bytes.length) {
      return false;
    }
    for (var index = 0; index < bytes.length; index++) {
      if (other.bytes[index] != bytes[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(prefixLength, Object.hashAll(bytes));
}

List<int>? _parseIpv4(String address) {
  final parts = address.split('.');
  if (parts.length != 4) return null;
  final bytes = <int>[];
  for (final part in parts) {
    if (!RegExp(r'^\d{1,3}$').hasMatch(part)) return null;
    final byte = int.parse(part);
    if (byte > 255) return null;
    bytes.add(byte);
  }
  return bytes;
}

List<int>? _parseIpv6(String address) {
  final halves = address.split('::');
  if (halves.length > 2) return null;
  List<int>? groups(String text) {
    if (text.isEmpty) return [];
    final words = <int>[];
    final parts = text.split(':');
    for (final (index, part) in parts.indexed) {
      if (index == parts.length - 1 && part.contains('.')) {
        final ipv4 = _parseIpv4(part);
        if (ipv4 == null) return null;
        words
          ..add(ipv4[0] << 8 | ipv4[1])
          ..add(ipv4[2] << 8 | ipv4[3]);
      } else if (RegExp(r'^[0-9A-Fa-f]{1,4}$').hasMatch(part)) {
        words.add(int.parse(part, radix: 16));
      } else {
        return null;
      }
    }
    return words;
  }

  final head = groups(halves.first);
  final tail = halves.length == 2 ? groups(halves.last) : <int>[];
  if (head == null || tail == null) return null;
  final missing = 8 - head.length - tail.length;
  if (halves.length == 2 ? missing < 1 : missing != 0) return null;
  final words = [...head, for (var i = 0; i < missing; i++) 0, ...tail];
  return [
    for (final word in words) ...[word >> 8, word & 0xFF],
  ];
}

/// Formats sixteen bytes the way Postgres prints an IPv6 address: the
/// longest run of two or more zero groups, the first of equally long ones,
/// becomes `::`, and the last four bytes are dotted when the address is
/// IPv4-compatible or IPv4-mapped.
String _formatIpv6(Uint8List bytes) {
  final words = [
    for (var index = 0; index < 16; index += 2)
      bytes[index] << 8 | bytes[index + 1],
  ];
  var bestStart = -1;
  var bestLength = 0;
  for (var start = 0; start < 8;) {
    if (words[start] != 0) {
      start++;
      continue;
    }
    var end = start;
    while (end < 8 && words[end] == 0) {
      end++;
    }
    if (end - start > bestLength) {
      bestStart = start;
      bestLength = end - start;
    }
    start = end;
  }
  if (bestLength < 2) bestStart = -1;
  final embedsIpv4 =
      bestStart == 0 &&
      (bestLength == 6 || (bestLength == 5 && words[5] == 0xFFFF));
  final buffer = StringBuffer();
  for (var index = 0; index < 8; index++) {
    if (index == bestStart) {
      buffer.write(':');
      index += bestLength - 1;
      if (index == 7) buffer.write(':');
      continue;
    }
    if (index > 0) buffer.write(':');
    if (embedsIpv4 && index == 6) {
      buffer.write(bytes.sublist(12).join('.'));
      break;
    }
    buffer.write(words[index].toRadixString(16));
  }
  return buffer.toString();
}
