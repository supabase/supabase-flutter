import 'dart:convert';

/// Decodes base64url strings, normalizing missing padding first.
class Base64Url {
  /// Decodes a base64url string to a UTF-8 string
  static String decodeToString(String input) {
    final normalized = base64Url.normalize(input);
    return utf8.decode(base64Url.decode(normalized));
  }

  /// Decodes a base64url string to its raw bytes.
  static List<int> decodeToBytes(String input) {
    final normalized = base64Url.normalize(input);
    return base64Url.decode(normalized);
  }
}
