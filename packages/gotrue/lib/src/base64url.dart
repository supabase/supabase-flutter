import 'dart:convert';
import 'dart:typed_data';

/// Base64URL encoding and decoding utilities for JWT operations.
/// Uses dart:convert for the core base64 operations and converts to/from base64url format.
class Base64Url {
  /// Decodes a base64url encoded string to bytes
  ///
  /// [input] The base64url encoded string to decode
  /// [loose] If true, allows lenient parsing that doesn't strictly validate padding
  static Uint8List decode(String input, {bool loose = false}) {
    // Convert base64url to base64 by replacing characters and adding padding
    String base64 = _base64urlToBase64(input);

    try {
      return base64Decode(base64);
    } catch (e) {
      if (loose) {
        // Try to decode with minimal padding adjustments
        return _decodeLoose(input);
      }
      rethrow;
    }
  }

  /// Encodes bytes to a base64url encoded string
  ///
  /// [data] The bytes to encode
  /// [pad] If true, adds padding characters to the output
  static String encode(List<int> data, {bool pad = false}) {
    // Use dart:convert base64 encoding
    String base64 = base64Encode(data);

    // Convert base64 to base64url
    String base64url = _base64ToBase64url(base64);

    // Remove padding if not requested
    if (!pad) {
      base64url = base64url.replaceAll('=', '');
    }

    return base64url;
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

  /// Converts base64url to base64 format
  static String _base64urlToBase64(String base64url) {
    // Replace base64url characters with base64 characters
    String base64 = base64url.replaceAll('-', '+').replaceAll('_', '/');

    // Add padding if needed
    int paddingLength = (4 - (base64.length % 4)) % 4;
    return base64 + '=' * paddingLength;
  }

  /// Converts base64 to base64url format
  static String _base64ToBase64url(String base64) {
    // Replace characters (keep padding as-is)
    return base64.replaceAll('+', '-').replaceAll('/', '_');
  }

  /// Loose decoding for malformed base64url strings
  static Uint8List _decodeLoose(String input) {
    // Try to fix common issues and decode
    String fixed = input;

    // Add minimal padding if needed
    if (fixed.length % 4 != 0) {
      fixed += '=' * (4 - (fixed.length % 4));
    }

    String base64 = _base64urlToBase64(fixed);

    try {
      return base64Decode(base64);
    } catch (e) {
      throw FormatException('Invalid base64url string: $input');
    }
  }
}
