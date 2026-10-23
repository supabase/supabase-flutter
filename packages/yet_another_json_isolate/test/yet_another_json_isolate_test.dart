import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

const _jsonString = '{"a":1,"b":2}';
const _jsonMap = {'a': 1, 'b': 2};

/// Large enough to encode to well over 64 KiB, so that operations on it are
/// processed on an isolate rather than inline.
final _largeValue = List.generate(
  2000,
  (index) => {
    'id': index,
    'name': 'user_$index',
    'description': 'A description for row $index. ${'x' * 40}',
  },
);

class _Book {
  _Book(this.title);

  final String title;
  int toJsonCalls = 0;

  Map<String, Object?> toJson() {
    toJsonCalls++;
    return {'title': title};
  }
}

class _Catalog {
  _Catalog(this.rows);

  final List<Map<String, Object?>> rows;
  int toJsonCalls = 0;

  List<Map<String, Object?>> toJson() {
    toJsonCalls++;
    return rows;
  }
}

class _Throwing {
  const _Throwing();

  Object toJson() => throw StateError('not serializable');
}

class _Wrapping {
  const _Wrapping(this.value);

  final Object value;

  Object toJson() => value;
}

void main() {
  late YAJsonIsolate isolate;

  group('basics', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('decodes a JSON object', () async {
      expect(await isolate.decode(_jsonString), _jsonMap);
    });

    test('encodes a JSON object', () async {
      expect(await isolate.encode(_jsonMap), _jsonString);
    });

    test('consumes the value before the caller can mutate it', () async {
      final value = <String, Object?>{'a': 1};
      final pending = isolate.encode(value);
      value['a'] = 2;
      expect(await pending, '{"a":1}');
    });
  });

  group('objects with toJson', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('calls toJson once on the calling isolate', () async {
      final book = _Book('Dune');
      expect(await isolate.encode(book), '{"title":"Dune"}');
      expect(book.toJsonCalls, 1);
    });

    test('calls toJson on objects nested in lists and maps', () async {
      final first = _Book('Dune');
      final second = _Book('Emma');
      final encoded = await isolate.encode({
        'books': [first, second],
        'featured': first,
      });
      expect(
        encoded,
        '{"books":[{"title":"Dune"},{"title":"Emma"}],'
        '"featured":{"title":"Dune"}}',
      );
      expect(first.toJsonCalls, 2);
      expect(second.toJsonCalls, 1);
    });

    test('calls toJson on the calling isolate for a large object', () async {
      final catalog = _Catalog(_largeValue);
      final encoded = await isolate.encode(catalog);
      expect(encoded.length, greaterThan(64 * 1024));
      expect(jsonDecode(encoded), _largeValue);
      expect(catalog.toJsonCalls, 1);
    });

    test('calls toJson on objects inside a large structure', () async {
      final book = _Book('Dune');
      final encoded = await isolate.encode([..._largeValue, book]);
      expect((jsonDecode(encoded) as List<dynamic>).last, {'title': 'Dune'});
      expect(book.toJsonCalls, 1);
    });

    test('leaves the original structure untouched', () async {
      final value = <String, Object?>{'book': _Book('Dune')};
      await isolate.encode(value);
      expect(value['book'], isA<_Book>());
    });

    test('throws when toJson throws', () async {
      await expectLater(
        isolate.encode(const _Throwing()),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('throws when toJson returns an unencodable value', () async {
      await expectLater(
        isolate.encode([_Wrapping(DateTime(2026))]),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('throws for a map with keys that are not strings', () async {
      await expectLater(
        isolate.encode({1: _Book('Dune')}),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('throws for a number that is not finite', () async {
      await expectLater(
        isolate.encode([double.nan]),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
  });

  group('data types', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('decodes a top level list', () async {
      expect(await isolate.decode('[1,2,3]'), [1, 2, 3]);
    });

    test('encodes a top level list', () async {
      expect(await isolate.encode([1, 2, 3]), '[1,2,3]');
    });

    test('handles nested structures', () async {
      const nested = {
        'list': [
          1,
          {'nested': true},
        ],
        'map': {'inner': null},
      };
      final encoded = await isolate.encode(nested);
      expect(await isolate.decode(encoded), nested);
    });

    test('handles ints, doubles, booleans, null and strings', () async {
      const value = {
        'int': 1,
        'double': 1.5,
        'boolTrue': true,
        'boolFalse': false,
        'null': null,
        'string': 'hello',
      };
      final encoded = await isolate.encode(value);
      expect(await isolate.decode(encoded), value);
    });

    test('preserves unicode characters', () async {
      const value = {'emoji': '🚀', 'text': 'Grüße'};
      final encoded = await isolate.encode(value);
      expect(await isolate.decode(encoded), value);
    });

    test('decodes a bare JSON primitive', () async {
      expect(await isolate.decode('42'), 42);
      expect(await isolate.decode('"text"'), 'text');
      expect(await isolate.decode('null'), isNull);
    });

    test('round trips an encoded value back to the original', () async {
      final encoded = await isolate.encode(_jsonMap);
      expect(await isolate.decode(encoded), _jsonMap);
    });
  });

  group('decodeBytes', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('decodes UTF-8 encoded JSON bytes', () async {
      expect(await isolate.decodeBytes(utf8.encode(_jsonString)), _jsonMap);
    });

    test('preserves unicode characters', () async {
      const value = {'emoji': '🚀', 'text': 'Grüße'};
      expect(
        await isolate.decodeBytes(utf8.encode(jsonEncode(value))),
        value,
      );
    });

    test('throws FormatException for invalid JSON bytes', () async {
      await expectLater(
        isolate.decodeBytes(utf8.encode('{not valid json')),
        throwsFormatException,
      );
    });

    test('throws FormatException for invalid UTF-8 bytes', () async {
      await expectLater(
        isolate.decodeBytes(Uint8List.fromList([0x22, 0xFF, 0xFE, 0x22])),
        throwsFormatException,
      );
    });

    test('reads the buffer before the caller can mutate it', () async {
      final bytes = Uint8List.fromList(utf8.encode(_jsonString));
      final pending = isolate.decodeBytes(bytes);
      bytes.fillRange(0, bytes.length, 0x20);
      expect(await pending, _jsonMap);
    });
  });

  group('large payloads', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('round trips a large structure', () async {
      final encoded = await isolate.encode(_largeValue);
      expect(encoded.length, greaterThan(64 * 1024));
      expect(await isolate.decode(encoded), _largeValue);
    });

    test('decodes large UTF-8 encoded JSON bytes', () async {
      final encoded = utf8.encode(jsonEncode(_largeValue));
      expect(await isolate.decodeBytes(encoded), _largeValue);
    });

    test('throws FormatException for large invalid JSON', () async {
      final truncated = jsonEncode(
        _largeValue,
      ).substring(0, 70 * 1024);
      await expectLater(isolate.decode(truncated), throwsFormatException);
      await expectLater(
        isolate.decodeBytes(utf8.encode(truncated)),
        throwsFormatException,
      );
    });

    test('throws for a large structure with a non encodable value', () async {
      final value = [..._largeValue, DateTime.now()];
      await expectLater(
        isolate.encode(value),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('resolves concurrent large decodes to the correct results', () async {
      final first = jsonEncode(_largeValue);
      final second = jsonEncode(_largeValue.reversed.toList());
      final results = await Future.wait([
        isolate.decode(first),
        isolate.decode(second),
      ]);
      expect(results[0], _largeValue);
      expect(results[1], _largeValue.reversed.toList());
    });
  });

  group('error handling', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('throws FormatException for invalid JSON', () async {
      await expectLater(
        isolate.decode('{not valid json'),
        throwsFormatException,
      );
    });

    test('throws for a non encodable object', () async {
      await expectLater(
        isolate.encode(DateTime.now()),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('stays usable after a decode error', () async {
      await expectLater(isolate.decode('{bad'), throwsFormatException);
      expect(await isolate.decode(_jsonString), _jsonMap);
    });

    test('stays usable after an encode error', () async {
      await expectLater(
        isolate.encode(DateTime.now()),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(await isolate.encode(_jsonMap), _jsonString);
    });
  });

  group('concurrency and ordering', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('resolves concurrent decodes to the correct results', () async {
      final results = await Future.wait([
        isolate.decode('1'),
        isolate.decode('2'),
        isolate.decode('3'),
        isolate.decode('[4]'),
      ]);
      expect(results, [
        1,
        2,
        3,
        [4],
      ]);
    });

    test('resolves interleaved encodes and decodes', () async {
      final results = await Future.wait([
        isolate.encode({'a': 1}),
        isolate.decode('[1,2]'),
        isolate.encode([true, false]),
      ]);
      expect(results, [
        '{"a":1}',
        [1, 2],
        '[true,false]',
      ]);
    });

    test('handles many sequential operations', () async {
      for (var i = 0; i < 50; i++) {
        expect(await isolate.decode('$i'), i);
      }
    });
  });

  group('lifecycle', () {
    test('every operation throws after dispose', () async {
      final disposed = YAJsonIsolate();
      await disposed.dispose();

      await expectLater(disposed.decode('{}'), throwsStateError);
      await expectLater(
        disposed.decodeBytes(utf8.encode('{}')),
        throwsStateError,
      );
      await expectLater(disposed.encode({}), throwsStateError);
    });

    test('dispose can be called more than once', () async {
      final disposed = YAJsonIsolate();
      await disposed.dispose();
      await expectLater(disposed.dispose(), completes);
    });

    test('exposes the provided debug name', () {
      expect(YAJsonIsolate(debugName: 'json').debugName, 'json');
    });

    test('dispose can be awaited on a lazily initialized isolate', () async {
      final lazyIsolate = YAJsonIsolate();
      await lazyIsolate.decode(_jsonString);
      await expectLater(lazyIsolate.dispose(), completes);
    });

    test('two isolates operate independently', () async {
      final first = YAJsonIsolate();
      final second = YAJsonIsolate();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      final results = await Future.wait([
        first.decode('[1]'),
        second.decode('[2]'),
      ]);
      expect(results, [
        [1],
        [2],
      ]);
    });
  });
}
