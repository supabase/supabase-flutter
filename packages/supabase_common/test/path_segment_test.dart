import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('encodePathSegment', () {
    test('keeps "/", "\\", "?", "#" and "%" inside the segment', () {
      const segment = r'../a\b?c=1#d%2e';

      final encoded = encodePathSegment(segment);
      final url = Uri.parse('https://example.com/api/$encoded/rest');

      expect(url.pathSegments, ['api', segment, 'rest']);
      expect(url.hasQuery, isFalse);
      expect(url.hasFragment, isFalse);
    });

    test('leaves a plain name, a colon and a timestamp as they are', () {
      expect(encodePathSegment('todos'), 'todos');
      expect(encodePathSegment('custom:acme'), 'custom:acme');
      expect(
        encodePathSegment('2026-11-12T10:00:00Z'),
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
