import 'dart:typed_data';

import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

void main() {
  group('encode', () {
    test('renders the bytes as a lowercase hex literal', () {
      expect(
        postgrestBytea.encode(Uint8List.fromList([0, 15, 16, 171, 255])),
        r'\x000f10abff',
      );
    });

    test('an empty value is the empty hex literal', () {
      expect(postgrestBytea.encode(Uint8List(0)), r'\x');
    });

    test('accepts any list of bytes', () {
      expect(postgrestBytea.encode([72, 105]), r'\x4869');
    });
  });

  group('decode', () {
    test('reads a hex literal with digits in either case', () {
      expect(postgrestBytea.decode(r'\x000f10abff'), [0, 15, 16, 171, 255]);
      expect(postgrestBytea.decode(r'\x00ABFF'), [0, 171, 255]);
      expect(postgrestBytea.decode(r'\x'), isEmpty);
    });

    test('returns a Uint8List', () {
      expect(postgrestBytea.decode(r'\x4869'), isA<Uint8List>());
      expect(postgrestBytea.decoder.convert(r'\x4869'), isA<Uint8List>());
    });

    test('allows whitespace between hex digit pairs', () {
      expect(postgrestBytea.decode('\\x48 69\t00\n'), [72, 105, 0]);
    });

    test('reads the escape format', () {
      expect(postgrestBytea.decode(r'Hi\\\000\377'), [72, 105, 92, 0, 255]);
      expect(postgrestBytea.decode(''), isEmpty);
    });

    test('rejects an odd number of hex digits', () {
      expect(() => postgrestBytea.decode(r'\x486'), throwsFormatException);
    });

    test('rejects a digit split by whitespace or a non hex digit', () {
      expect(() => postgrestBytea.decode(r'\x4 869'), throwsFormatException);
      expect(() => postgrestBytea.decode(r'\x4g'), throwsFormatException);
    });

    test('rejects a malformed escape sequence', () {
      expect(() => postgrestBytea.decode(r'Hi\'), throwsFormatException);
      expect(() => postgrestBytea.decode(r'Hi\12'), throwsFormatException);
      expect(() => postgrestBytea.decode(r'Hi\789'), throwsFormatException);
      expect(() => postgrestBytea.decode(r'Hi\400'), throwsFormatException);
    });

    test('rejects characters outside ASCII in the escape format', () {
      expect(() => postgrestBytea.decode('Hé'), throwsFormatException);
    });
  });

  test('round trips every byte value', () {
    final bytes = Uint8List.fromList([for (var i = 0; i < 256; i++) i]);

    expect(postgrestBytea.decode(postgrestBytea.encode(bytes)), bytes);
  });
}
