import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

void main() {
  group('encode', () {
    test('renders the elements as a vector literal', () {
      expect(postgrestVector.encode([0.5, -2.25, 1e-7]), '[0.5,-2.25,1e-7]');
    });

    test('an empty list is the empty literal', () {
      expect(postgrestVector.encode([]), '[]');
    });
  });

  group('decode', () {
    test('reads the literal PostgREST sends', () {
      expect(postgrestVector.decode('[0.5,-2.25,1e-07]'), [0.5, -2.25, 1e-7]);
    });

    test('reads integral elements as doubles', () {
      final decoded = postgrestVector.decode('[1,2,3]');

      expect(decoded, [1.0, 2.0, 3.0]);
      expect(decoded, isA<List<double>>());
    });

    test('allows whitespace around the literal and its elements', () {
      expect(postgrestVector.decode(' [ 0.5 , -2.25 ] '), [0.5, -2.25]);
    });

    test('reads the empty literal', () {
      expect(postgrestVector.decode('[]'), isEmpty);
    });

    test('rejects text that is not a vector literal', () {
      expect(() => postgrestVector.decode('{0.5,1}'), throwsFormatException);
      expect(() => postgrestVector.decode('0.5,1'), throwsFormatException);
      expect(() => postgrestVector.decode('[0.5,1'), throwsFormatException);
    });

    test('rejects an element that is not a number', () {
      expect(() => postgrestVector.decode('[0.5,a]'), throwsFormatException);
      expect(() => postgrestVector.decode('[0.5,,1]'), throwsFormatException);
    });
  });

  test('round trips its elements', () {
    const elements = [0.1, -0.2, 3.5, 1e-30, 123456.789];

    expect(postgrestVector.decode(postgrestVector.encode(elements)), elements);
  });
}
