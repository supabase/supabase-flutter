import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders both halves in uppercase hex without leading zeros', () {
      expect(
        PostgresLogSequenceNumber(0x16, 0xB374D848).literal,
        '16/B374D848',
      );
      expect(PostgresLogSequenceNumber(0, 0).literal, '0/0');
      expect(
        PostgresLogSequenceNumber(0xFFFFFFFF, 0xFFFFFFFF).literal,
        'FFFFFFFF/FFFFFFFF',
      );
    });

    test('toString is the literal', () {
      expect(PostgresLogSequenceNumber(1, 2).toString(), '1/2');
    });
  });

  group('parse', () {
    test('reads the literal Postgres emits', () {
      final position = PostgresLogSequenceNumber.parse('16/B374D848');
      expect(position.high, 0x16);
      expect(position.low, 0xB374D848);
    });

    test('reads lowercase digits and leading zeros', () {
      expect(
        PostgresLogSequenceNumber.parse(' 00000016/b374d848 '),
        PostgresLogSequenceNumber(0x16, 0xB374D848),
      );
    });

    test('rejects what is not a log sequence number', () {
      for (final literal in [
        '',
        '16',
        '16/',
        '/1',
        '1/2/3',
        'G/1',
        '1/123456789',
      ]) {
        expect(
          () => PostgresLogSequenceNumber.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('round trips a rendered literal', () {
      final position = PostgresLogSequenceNumber(0xFFFFFFFF, 0x1);
      expect(PostgresLogSequenceNumber.parse(position.literal), position);
    });
  });

  test('rejects a half outside 32 bits', () {
    expect(() => PostgresLogSequenceNumber(-1, 0), throwsArgumentError);
    expect(
      () => PostgresLogSequenceNumber(0, 0x100000000),
      throwsArgumentError,
    );
  });

  group('ordering', () {
    test('compares in log order, the high half first', () {
      final positions = [
        PostgresLogSequenceNumber(1, 0),
        PostgresLogSequenceNumber(0, 0xFFFFFFFF),
        PostgresLogSequenceNumber(0, 1),
      ]..sort();
      expect(positions, [
        PostgresLogSequenceNumber(0, 1),
        PostgresLogSequenceNumber(0, 0xFFFFFFFF),
        PostgresLogSequenceNumber(1, 0),
      ]);
    });

    test('equal positions hash alike', () {
      expect(
        PostgresLogSequenceNumber(1, 2).hashCode,
        PostgresLogSequenceNumber(1, 2).hashCode,
      );
    });
  });
}
