import 'dart:convert';
import 'dart:typed_data';

import 'package:gotrue/src/base64url.dart';
import 'package:test/test.dart';

void main() {
  group('Base64Url', () {
    group('encode', () {
      test('encodes empty data', () {
        final result = Base64Url.encode([]);
        expect(result, '');
      });

      test('encodes simple data without padding', () {
        final data = utf8.encode('hello');
        final result = Base64Url.encode(data, pad: false);
        expect(result, 'aGVsbG8');
      });

      test('encodes simple data with padding', () {
        final data = utf8.encode('hello');
        final result = Base64Url.encode(data, pad: true);
        expect(result, 'aGVsbG8=');
      });

      test('encodes data that requires multiple padding chars', () {
        final data = utf8.encode('a');
        final result = Base64Url.encode(data, pad: true);
        expect(result, 'YQ==');
      });

      test('uses base64url alphabet (- and _ instead of + and /)', () {
        // This byte sequence produces characters that differ between base64 and base64url
        final data = Uint8List.fromList([251, 239]);
        final result = Base64Url.encode(data, pad: false);
        // In base64 this would be "++"
        // In base64url this should be "--"
        expect(result, '--8');
      });

      test('encodes binary data correctly', () {
        final data = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
        final result = Base64Url.encode(data, pad: false);
        expect(result.length, greaterThan(0));
        // Verify we can decode it back
        final decoded = Base64Url.decode(result);
        expect(decoded, equals(data));
      });
    });

    group('decode', () {
      test('decodes empty string', () {
        final result = Base64Url.decode('');
        expect(result, isEmpty);
      });

      test('decodes simple data', () {
        final result = Base64Url.decode('aGVsbG8');
        expect(utf8.decode(result), 'hello');
      });

      test('decodes data with padding', () {
        final result = Base64Url.decode('aGVsbG8=');
        expect(utf8.decode(result), 'hello');
      });

      test('decodes data with multiple padding chars', () {
        final result = Base64Url.decode('YQ==');
        expect(utf8.decode(result), 'a');
      });

      test('decodes base64url alphabet (- and _)', () {
        // "--8" in base64url decodes to [251, 239]
        final result = Base64Url.decode('--8');
        expect(result, equals(Uint8List.fromList([251, 239])));
      });

      test('decodes with loose mode ignores padding errors', () {
        // Invalid padding but should work in loose mode
        final result = Base64Url.decode('YQ', loose: true);
        expect(utf8.decode(result), 'a');
      });

      test('throws on invalid characters', () {
        expect(
          () => Base64Url.decode('invalid!!!'),
          throwsA(isA<FormatException>()),
        );
      });

      test('decodes data with implicit padding in strict mode', () {
        // 'YQ' is 'a' without padding, should work in strict mode
        // because the remainder is valid (2 or 4)
        final result = Base64Url.decode('YQ', loose: false);
        expect(utf8.decode(result), 'a');
      });
    });

    group('round-trip encoding', () {
      test('encodes and decodes simple string', () {
        const original = 'The quick brown fox jumps over the lazy dog';
        final encoded = Base64Url.encodeFromString(original);
        final decoded = Base64Url.decodeToString(encoded);
        expect(decoded, original);
      });

      test('encodes and decodes empty string', () {
        const original = '';
        final encoded = Base64Url.encodeFromString(original);
        final decoded = Base64Url.decodeToString(encoded);
        expect(decoded, original);
      });

      test('encodes and decodes unicode string', () {
        const original = 'Hello 世界 🌍';
        final encoded = Base64Url.encodeFromString(original);
        final decoded = Base64Url.decodeToString(encoded);
        expect(decoded, original);
      });

      test('encodes and decodes binary data', () {
        final original = Uint8List.fromList(
            List.generate(256, (i) => i % 256)); // All byte values
        final encoded = Base64Url.encode(original);
        final decoded = Base64Url.decode(encoded);
        expect(decoded, equals(original));
      });

      test('encodes and decodes with padding', () {
        final original = utf8.encode('test');
        final encoded = Base64Url.encode(original, pad: true);
        final decoded = Base64Url.decode(encoded);
        expect(decoded, equals(original));
      });

      test('encodes and decodes without padding', () {
        final original = utf8.encode('test');
        final encoded = Base64Url.encode(original, pad: false);
        final decoded = Base64Url.decode(encoded, loose: true);
        expect(decoded, equals(original));
      });
    });

    group('JWT compatibility', () {
      test('decodes JWT header', () {
        // Standard JWT header: {"alg":"HS256","typ":"JWT"}
        const jwtHeader = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
        final decoded = Base64Url.decodeToString(jwtHeader, loose: true);
        final json = jsonDecode(decoded);
        expect(json['alg'], 'HS256');
        expect(json['typ'], 'JWT');
      });

      test('decodes JWT payload', () {
        // Standard JWT payload with sub, name, iat
        const jwtPayload =
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ';
        final decoded = Base64Url.decodeToString(jwtPayload, loose: true);
        final json = jsonDecode(decoded);
        expect(json['sub'], '1234567890');
        expect(json['name'], 'John Doe');
        expect(json['iat'], 1516239022);
      });

      test('handles JWT signature bytes', () {
        // JWT signature is binary data
        const jwtSignature = 'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        final decoded = Base64Url.decode(jwtSignature, loose: true);
        expect(decoded, isA<Uint8List>());
        expect(decoded.length, greaterThan(0));
      });
    });
  });
}
