import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('encodePathSegment', () {
    test('keeps "/", "\\", "?", "#" and "%" inside the segment', () {
      const segment = r'../a\b?c=1#d%2e';

      final encoded = encodePathSegment(segment, name: 'id');
      final url = Uri.parse('https://example.com/api/$encoded/rest');

      expect(url.pathSegments, ['api', segment, 'rest']);
      expect(url.hasQuery, isFalse);
      expect(url.hasFragment, isFalse);
    });

    test('encodes the characters a server may read as path syntax', () {
      expect(
        encodePathSegment('a;b+c d,e=f@g', name: 'id'),
        'a%3Bb%2Bc%20d%2Ce%3Df%40g',
      );
    });

    test('leaves a plain name, a colon and a timestamp as they are', () {
      expect(encodePathSegment('todos', name: 'id'), 'todos');
      expect(encodePathSegment('custom:acme', name: 'id'), 'custom:acme');
      expect(
        encodePathSegment('2026-11-12T10:00:00Z', name: 'id'),
        '2026-11-12T10:00:00Z',
      );
    });

    for (final segment in ['', '.', '..']) {
      test('throws an ArgumentError naming the argument for "$segment"', () {
        expect(
          () => encodePathSegment(segment, name: 'table'),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'table')
                .having((error) => error.invalidValue, 'value', segment),
          ),
        );
      });
    }
  });
}
