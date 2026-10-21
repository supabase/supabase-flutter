import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders lowercase hex bytes separated by colons', () {
      expect(
        PostgresMacAddress([8, 0, 0x2B, 1, 2, 3]).literal,
        '08:00:2b:01:02:03',
      );
      expect(
        PostgresMacAddress([8, 0, 0x2B, 1, 2, 3, 4, 5]).literal,
        '08:00:2b:01:02:03:04:05',
      );
    });

    test('toString is the literal', () {
      expect(
        PostgresMacAddress([0, 0, 0, 0, 0, 0xFF]).toString(),
        '00:00:00:00:00:ff',
      );
    });
  });

  group('parse', () {
    test('reads every separator style Postgres accepts', () {
      const expected = [8, 0, 0x2B, 1, 2, 3];
      for (final literal in [
        '08:00:2b:01:02:03',
        '08-00-2B-01-02-03',
        '08002b:010203',
        '08002b-010203',
        '0800.2b01.0203',
        '0800-2b01-0203',
        '08002b010203',
      ]) {
        expect(
          PostgresMacAddress.parse(literal).bytes,
          expected,
          reason: literal,
        );
      }
    });

    test('reads an eight byte address', () {
      expect(
        PostgresMacAddress.parse('08:00:2b:01:02:03:04:05').bytes,
        [8, 0, 0x2B, 1, 2, 3, 4, 5],
      );
    });

    test('rejects what is not a MAC address', () {
      for (final literal in [
        '',
        '08:00:2b:01:02',
        '08:00:2b:01:02:03:04',
        '08:00:2b:01:02:0g',
        '08 00 2b 01 02 03',
      ]) {
        expect(
          () => PostgresMacAddress.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('round trips a rendered literal', () {
      final address = PostgresMacAddress([0xDE, 0xAD, 0xBE, 0xEF, 0, 1]);
      expect(PostgresMacAddress.parse(address.literal), address);
    });
  });

  group('construction', () {
    test('rejects a length other than six or eight', () {
      expect(() => PostgresMacAddress([1, 2, 3, 4, 5]), throwsArgumentError);
      expect(
        () => PostgresMacAddress([1, 2, 3, 4, 5, 6, 7]),
        throwsArgumentError,
      );
    });

    test('rejects a value outside a byte', () {
      expect(
        () => PostgresMacAddress([256, 0, 0, 0, 0, 0]),
        throwsArgumentError,
      );
      expect(
        () => PostgresMacAddress([-1, 0, 0, 0, 0, 0]),
        throwsArgumentError,
      );
    });

    test('keeps its own unmodifiable copy of the bytes', () {
      final source = [8, 0, 0x2B, 1, 2, 3];
      final address = PostgresMacAddress(source);
      source[0] = 0;
      expect(address.bytes.first, 8);
      expect(() => address.bytes[0] = 0, throwsUnsupportedError);
    });
  });

  group('equality', () {
    test('compares the bytes', () {
      expect(
        PostgresMacAddress([8, 0, 0x2B, 1, 2, 3]),
        PostgresMacAddress.parse('08:00:2b:01:02:03'),
      );
      expect(
        PostgresMacAddress([8, 0, 0x2B, 1, 2, 3]) ==
            PostgresMacAddress([8, 0, 0x2B, 1, 2, 4]),
        isFalse,
      );
    });

    test('equal addresses hash alike', () {
      expect(
        PostgresMacAddress([8, 0, 0x2B, 1, 2, 3]).hashCode,
        PostgresMacAddress([8, 0, 0x2B, 1, 2, 3]).hashCode,
      );
    });
  });
}
