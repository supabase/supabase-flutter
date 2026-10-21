import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('encode', () {
    test('renders the elements as a vector literal', () {
      expect(postgresVector.encode([0.5, -2.25, 1e-7]), '[0.5,-2.25,1e-7]');
    });

    test('rejects an empty list', () {
      expect(() => postgresVector.encode([]), throwsArgumentError);
    });

    test('rejects non-finite elements', () {
      expect(
        () => postgresVector.encode([0.5, double.nan]),
        throwsArgumentError,
      );
      expect(
        () => postgresVector.encode([double.infinity]),
        throwsArgumentError,
      );
      expect(
        () => postgresVector.encode([double.negativeInfinity]),
        throwsArgumentError,
      );
    });
  });

  group('decode', () {
    test('reads the literal PostgREST sends', () {
      expect(postgresVector.decode('[0.5,-2.25,1e-07]'), [0.5, -2.25, 1e-7]);
    });

    test('reads integral elements as doubles', () {
      final decoded = postgresVector.decode('[1,2,3]');

      expect(decoded, [1.0, 2.0, 3.0]);
      expect(decoded, isA<List<double>>());
    });

    test('allows whitespace around the literal and its elements', () {
      expect(postgresVector.decode(' [ 0.5 , -2.25 ] '), [0.5, -2.25]);
    });

    test('rejects the empty literal', () {
      expect(() => postgresVector.decode('[]'), throwsFormatException);
      expect(() => postgresVector.decode('[ ]'), throwsFormatException);
    });

    test('rejects non-finite elements', () {
      expect(() => postgresVector.decode('[0.5,NaN]'), throwsFormatException);
      expect(() => postgresVector.decode('[Infinity]'), throwsFormatException);
      expect(
        () => postgresVector.decode('[-Infinity]'),
        throwsFormatException,
      );
    });

    test('rejects text that is not a vector literal', () {
      expect(() => postgresVector.decode('{0.5,1}'), throwsFormatException);
      expect(() => postgresVector.decode('0.5,1'), throwsFormatException);
      expect(() => postgresVector.decode('[0.5,1'), throwsFormatException);
    });

    test('rejects an element that is not a number', () {
      expect(() => postgresVector.decode('[0.5,a]'), throwsFormatException);
      expect(() => postgresVector.decode('[0.5,,1]'), throwsFormatException);
    });
  });

  test('round trips its elements', () {
    const elements = [0.1, -0.2, 3.5, 1e-30, 123456.789];

    expect(postgresVector.decode(postgresVector.encode(elements)), elements);
  });
}
