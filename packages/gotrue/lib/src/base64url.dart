import 'dart:convert';
import 'dart:typed_data';

/// Base64URL encoding and decoding utilities for JWT operations.
/// Extracted and adapted from RFC 4648 specification.
class Base64Url {
  static const String _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  static const int _bits = 6;

  /// Decodes a base64url encoded string to bytes
  ///
  /// [input] The base64url encoded string to decode
  /// [loose] If true, allows lenient parsing that doesn't strictly validate padding
  static Uint8List decode(String input, {bool loose = false}) {
    // Remove padding characters
    String string = input.replaceAll('=', '');

    // Build character lookup table
    final Map<String, int> codes = {};
    for (int i = 0; i < _chars.length; i++) {
      codes[_chars[i]] = i;
    }

    // For loose mode or when there's actual content, skip strict validation
    // The validation below will catch actual errors during decoding
    if (!loose && string.isNotEmpty) {
      final remainder = (string.length * _bits) % 8;
      // Allow if remainder is 0 or if it's 2 or 4 (valid base64 partial bytes)
      if (remainder != 0 && remainder != 2 && remainder != 4) {
        throw FormatException('Invalid base64url string length');
      }
    }

    // Calculate output size
    final int outputLength = (string.length * _bits) ~/ 8;
    final Uint8List out = Uint8List(outputLength);

    // Decode the string
    int bits = 0; // Number of bits currently in the buffer
    int buffer = 0; // Bits waiting to be written out, MSB first
    int written = 0; // Next byte to write

    for (int i = 0; i < string.length; i++) {
      final String char = string[i];
      final int? value = codes[char];

      if (value == null) {
        throw FormatException('Invalid character in base64url string: $char');
      }

      // Append the bits to the buffer
      buffer = (buffer << _bits) | value;
      bits += _bits;

      // Write out some bits if the buffer has a byte's worth
      if (bits >= 8) {
        bits -= 8;
        out[written++] = 0xff & (buffer >> bits);
      }
    }

    // Verify that we have received just enough bits
    if (bits >= _bits || (0xff & (buffer << (8 - bits))) != 0) {
      if (!loose) {
        throw FormatException('Unexpected end of base64url data');
      }
    }

    return out;
  }

  /// Encodes bytes to a base64url encoded string
  ///
  /// [data] The bytes to encode
  /// [pad] If true, adds padding characters to the output
  static String encode(List<int> data, {bool pad = false}) {
    final int mask = (1 << _bits) - 1;
    String out = '';

    int bits = 0; // Number of bits currently in the buffer
    int buffer = 0; // Bits waiting to be written out, MSB first

    for (int i = 0; i < data.length; i++) {
      // Slurp data into the buffer
      buffer = (buffer << 8) | (0xff & data[i]);
      bits += 8;

      // Write out as much as we can
      while (bits > _bits) {
        bits -= _bits;
        out += _chars[mask & (buffer >> bits)];
      }
    }

    // Handle partial character
    if (bits > 0) {
      out += _chars[mask & (buffer << (_bits - bits))];
    }

    // Add padding characters until we hit a byte boundary
    if (pad) {
      while ((out.length * _bits) % 8 != 0) {
        out += '=';
      }
    }

    return out;
  }

  /// Decodes a base64url string to a UTF-8 string
  static String decodeToString(String input, {bool loose = false}) {
    final bytes = decode(input, loose: loose);
    return utf8.decode(bytes);
  }

  /// Encodes a UTF-8 string to base64url
  static String encodeFromString(String input, {bool pad = false}) {
    final bytes = utf8.encode(input);
    return encode(bytes, pad: pad);
  }
}
