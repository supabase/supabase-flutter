import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('field', () {
    const json = <String, dynamic>{'name': 'books', 'count': 1};

    test('returns a value of the expected type', () {
      expect(json.field<String>('name'), 'books');
    });

    test('returns null for a missing nullable field', () {
      expect(json.field<String?>('title'), isNull);
    });

    test('throws a FormatException naming a field of the wrong type', () {
      expect(
        () => json.field<String>('count'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Expected "count" to be String, got int',
          ),
        ),
      );
    });

    test('throws a FormatException for a missing required field', () {
      expect(
        () => json.field<String>('title'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Expected "title" to be String, got Null',
          ),
        ),
      );
    });
  });

  group('listOf', () {
    const json = <String, dynamic>{
      'names': ['a', 'b'],
      'mixed': ['a', 1],
      'name': 'a',
    };

    test('returns the elements of the list', () {
      expect(json.listOf<String>('names'), ['a', 'b']);
    });

    test('returns null for a missing list', () {
      expect(json.listOf<String>('titles'), isNull);
    });

    test('throws a FormatException naming a value that is not a list', () {
      expect(
        () => json.listOf<String>('name'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Expected "name" to be List<String>, got String',
          ),
        ),
      );
    });

    test('throws a FormatException naming an element of the wrong type', () {
      expect(
        () => json.listOf<String>('mixed'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Expected the elements of "mixed" to be String, got int',
          ),
        ),
      );
    });
  });

  group('requiredListOf', () {
    const json = <String, dynamic>{
      'names': ['a', 'b'],
    };

    test('returns the elements of the list', () {
      expect(json.requiredListOf<String>('names'), ['a', 'b']);
    });

    test('throws a FormatException naming a missing list', () {
      expect(
        () => json.requiredListOf<String>('titles'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Expected "titles" to be List<String>, got Null',
          ),
        ),
      );
    });
  });

  group('jsonObject', () {
    test('returns a JSON object', () {
      const object = <String, dynamic>{'id': 1};
      expect(jsonObject(object, description: 'the body'), same(object));
    });

    for (final value in <Object?>[
      null,
      'a',
      <dynamic>[],
      <dynamic, dynamic>{'id': 1},
    ]) {
      test('throws a FormatException naming $value', () {
        expect(
          () => jsonObject(value, description: 'the body'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Expected the body to be a JSON object, got '
                  '${value.runtimeType}',
            ),
          ),
        );
      });
    }
  });

  group('jsonObjectList', () {
    test('returns a list of JSON objects', () {
      expect(
        jsonObjectList(<dynamic>[
          <String, dynamic>{'id': 1},
        ], description: 'the body'),
        [
          {'id': 1},
        ],
      );
    });

    test('throws a FormatException for a value that is not a list', () {
      expect(
        () => jsonObjectList(<String, dynamic>{}, description: 'the body'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            startsWith('Expected the body to be a list'),
          ),
        ),
      );
    });

    test('throws a FormatException for an element that is not an object', () {
      expect(
        () => jsonObjectList(<dynamic>[1], description: 'the body'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Expected each of the body to be a JSON object, got int',
          ),
        ),
      );
    });
  });
}
