@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// JSON encodable through [toJson], but not sendable to another isolate
/// because it holds a [ReceivePort].
class _UnsendableButEncodable {
  final ReceivePort port = ReceivePort();

  Map<String, dynamic> toJson() => {'type': 'unsendable'};
}

/// Every disposal in this group is bounded, so a regression that makes
/// `dispose()` wait forever fails the test instead of hanging the suite.
Future<void> dispose(YAJsonIsolate isolate) =>
    isolate.dispose().timeout(const Duration(seconds: 5));

void main() {
  group('io implementation', () {
    test('throws when initialize is called twice', () async {
      final isolate = YAJsonIsolate();
      await isolate.initialize();
      addTearDown(() => dispose(isolate));
      expect(isolate.initialize(), throwsA(isA<AssertionError>()));
    });

    test('exposes the provided debug name', () {
      final isolate = YAJsonIsolate(debugName: 'my-isolate');
      expect(isolate.debugName, 'my-isolate');
    });

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
      expect(isolate.initialize(), throwsStateError);
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

    test('encodes an unsendable value inline', () async {
      final isolate = YAJsonIsolate();
      addTearDown(() => dispose(isolate));
      final value = _UnsendableButEncodable();
      addTearDown(value.port.close);

      expect(await isolate.encode(value), '{"type":"unsendable"}');
    });

    test(
      'encodes a large structure holding an unsendable value inline',
      () async {
        final isolate = YAJsonIsolate();
        addTearDown(() => dispose(isolate));
        final value = _UnsendableButEncodable();
        addTearDown(value.port.close);
        final large = [
          for (var i = 0; i < 5000; i++) {'id': i, 'name': 'user_$i'},
          value,
        ];

        final encoded = await isolate.encode(large);
        expect(encoded, endsWith('{"type":"unsendable"}]'));
      },
    );
  });
}
