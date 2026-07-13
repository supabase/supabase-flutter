import 'dart:convert';

import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

const _jsonString = '{"a":1,"b":2}';
const _jsonMap = {'a': 1, 'b': 2};

void main() {
  late YAJsonIsolate isolate;

  group('with manual initialize', () {
    setUp(() async {
      isolate = YAJsonIsolate();
      await isolate.initialize();
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
  });

  group('without manual initialize', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('decodes lazily on first call', () async {
      expect(await isolate.decode(_jsonString), _jsonMap);
    });

    test('encodes lazily on first call', () async {
      expect(await isolate.encode(_jsonMap), _jsonString);
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
    setUp(() async {
      isolate = YAJsonIsolate();
      await isolate.initialize();
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
