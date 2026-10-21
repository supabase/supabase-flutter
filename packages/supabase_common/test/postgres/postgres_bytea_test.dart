import 'dart:typed_data';

import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('encode', () {
    test('renders the bytes as a lowercase hex literal', () {
      expect(
        postgresBytea.encode(Uint8List.fromList([0, 15, 16, 171, 255])),
        r'\x000f10abff',
      );
    });

    test('an empty value is the empty hex literal', () {
      expect(postgresBytea.encode(Uint8List(0)), r'\x');
    });

    test('accepts any list of bytes', () {
      expect(postgresBytea.encode([72, 105]), r'\x4869');
    });
  });

  group('decode', () {
    test('reads a hex literal with digits in either case', () {
      expect(postgresBytea.decode(r'\x000f10abff'), [0, 15, 16, 171, 255]);
      expect(postgresBytea.decode(r'\x00ABFF'), [0, 171, 255]);
      expect(postgresBytea.decode(r'\x'), isEmpty);
    });

    test('returns a Uint8List', () {
      expect(postgresBytea.decode(r'\x4869'), isA<Uint8List>());
      expect(postgresBytea.decoder.convert(r'\x4869'), isA<Uint8List>());
    });

    test('reads the escape format', () {
      expect(postgresBytea.decode(r'Hi\\\000\377'), [72, 105, 92, 0, 255]);
      expect(postgresBytea.decode(''), isEmpty);
    });

    test('rejects an odd number of hex digits', () {
      expect(() => postgresBytea.decode(r'\x486'), throwsFormatException);
    });

    test('rejects a non hex digit', () {
      expect(() => postgresBytea.decode(r'\x4g'), throwsFormatException);
      expect(() => postgresBytea.decode(r'\x4 869'), throwsFormatException);
    });

    test('rejects a malformed escape sequence', () {
      expect(() => postgresBytea.decode(r'Hi\'), throwsFormatException);
      expect(() => postgresBytea.decode(r'Hi\12'), throwsFormatException);
      expect(() => postgresBytea.decode(r'Hi\789'), throwsFormatException);
      expect(() => postgresBytea.decode(r'Hi\400'), throwsFormatException);
    });

    test('rejects characters outside ASCII in the escape format', () {
      expect(() => postgresBytea.decode('Hé'), throwsFormatException);
    });
  });

  test('round trips every byte value', () {
    final bytes = Uint8List.fromList([for (var i = 0; i < 256; i++) i]);

    expect(postgresBytea.decode(postgresBytea.encode(bytes)), bytes);
  });
}
