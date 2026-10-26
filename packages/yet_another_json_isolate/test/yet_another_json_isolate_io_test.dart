@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// Every disposal in this group is bounded, so a regression that makes
/// `dispose()` wait forever fails the test instead of hanging the suite.
Future<void> dispose(YAJsonIsolate isolate) =>
    isolate.dispose().timeout(const Duration(seconds: 5));

void main() {
  group('io implementation', () {
    test('dispose completes when the isolate was never used', () async {
      final isolate = YAJsonIsolate();
      await expectLater(dispose(isolate), completes);
    });

    test('dispose completes when called twice', () async {
      final isolate = YAJsonIsolate();
      await isolate.decode('{}');
      await dispose(isolate);
      await expectLater(dispose(isolate), completes);
    });

    test('concurrent dispose calls all await the same shutdown', () async {
      final isolate = YAJsonIsolate();
      await isolate.decode('{}');

      final first = isolate.dispose();
      final second = isolate.dispose();
      expect(identical(first, second), isTrue);

      await expectLater(
        Future.wait([first, second]).timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test('using the isolate after dispose throws', () async {
      final isolate = YAJsonIsolate();
      await isolate.decode('{}');
      await dispose(isolate);

      expect(isolate.decode('{}'), throwsStateError);
      expect(isolate.encode({}), throwsStateError);
    });

    test('a never used isolate also rejects work after dispose', () async {
      final isolate = YAJsonIsolate();
      await dispose(isolate);

      expect(isolate.decode('{}'), throwsStateError);
    });

    test('dispose waits for in-flight isolate work', () async {
      final isolate = YAJsonIsolate();
      final largeJson = jsonEncode([
        for (var i = 0; i < 5000; i++) {'id': i, 'name': 'user_$i'},
      ]);

      var decodeCompleted = false;
      final pending = isolate.decode(largeJson).then((_) {
        decodeCompleted = true;
      });

      await dispose(isolate);
      // One event loop turn lets the completion listeners of the awaited
      // work run; the isolate round trip itself takes far longer, so this
      // fails when disposal stops awaiting in-flight work.
      await Future<void>.delayed(Duration.zero);
      expect(decodeCompleted, isTrue);
      await pending;
    });

    test('encodes a deeply nested structure', () async {
      final isolate = YAJsonIsolate();
      addTearDown(() => dispose(isolate));
      Object? nested = 'leaf';
      for (var i = 0; i < 600; i++) {
        nested = [nested];
      }

      final encoded = await isolate.encode(nested);
      expect(encoded, '${'[' * 600}"leaf"${']' * 600}');
    });

    test('throws for a cyclic structure', () async {
      final isolate = YAJsonIsolate();
      addTearDown(() => dispose(isolate));
      final inner = <Object?>[];
      final cyclic = [inner];
      inner.add(cyclic);

      await expectLater(
        isolate.encode(cyclic),
        throwsA(isA<JsonCyclicError>()),
      );
    });
  });
}
