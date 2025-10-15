import 'dart:convert';
import 'dart:typed_data';

import 'package:gotrue/src/base64url.dart';
import 'package:test/test.dart';

void main() {
  group('Base64Url', () {
    group('decode', () {
      test('decodes empty string', () {
        final result = Base64Url.decodeToBytes('');
        expect(result, isEmpty);
      });

      test('decodes simple data', () {
        final result = Base64Url.decodeToBytes('aGVsbG8');
        expect(utf8.decode(result), 'hello');
      });

      test('decodes data with padding', () {
        final result = Base64Url.decodeToBytes('aGVsbG8=');
        expect(utf8.decode(result), 'hello');
      });

      test('decodes data with multiple padding chars', () {
        final result = Base64Url.decodeToBytes('YQ==');
        expect(utf8.decode(result), 'a');
      });

      test('decodes base64url alphabet (- and _)', () {
        // "--8" in base64url decodes to [251, 239]
        final result = Base64Url.decodeToBytes('--8');
        expect(result, equals(Uint8List.fromList([251, 239])));
      });

      test('decodes with loose mode ignores padding errors', () {
        // Invalid padding but should work in loose mode
        final result = Base64Url.decodeToBytes('YQ');
        expect(utf8.decode(result), 'a');
      });

      test('throws on invalid characters', () {
        expect(
          () => Base64Url.decodeToBytes('invalid!!!'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('JWT compatibility', () {
      test('decodes JWT header', () {
        // Standard JWT header: {"alg":"HS256","typ":"JWT"}
        const jwtHeader = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
        final decoded = Base64Url.decodeToString(jwtHeader);
        final json = jsonDecode(decoded);
        expect(json['alg'], 'HS256');
        expect(json['typ'], 'JWT');
      });

      test('decodes JWT payload', () {
        // Standard JWT payload with sub, name, iat
        const jwtPayload =
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ';
        final decoded = Base64Url.decodeToString(jwtPayload);
        final json = jsonDecode(decoded);
        expect(json['sub'], '1234567890');
        expect(json['name'], 'John Doe');
        expect(json['iat'], 1516239022);
      });

      test('handles JWT signature bytes', () {
        // JWT signature is binary data
        const jwtSignature = 'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        final decoded = Base64Url.decodeToBytes(jwtSignature);
        expect(decoded, isA<List<int>>());
        expect(decoded.length, greaterThan(0));
      });
    });
  });
}
