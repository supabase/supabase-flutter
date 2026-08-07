@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

void main() {
  group('io implementation', () {
    test('throws when initialize is called twice', () async {
      final isolate = YAJsonIsolate();
      await isolate.initialize();
      addTearDown(isolate.dispose);
      expect(isolate.initialize(), throwsA(isA<AssertionError>()));
    });

    test('exposes the provided debug name', () {
      final isolate = YAJsonIsolate(debugName: 'my-isolate');
      expect(isolate.debugName, 'my-isolate');
    });

    test('dispose completes when the isolate was never used', () async {
      final isolate = YAJsonIsolate();
      await expectLater(
        isolate.dispose().timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test('dispose completes when called twice', () async {
      final isolate = YAJsonIsolate();
      await isolate.decode('{}');
      await isolate.dispose();
      await expectLater(
        isolate.dispose().timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test('concurrent dispose calls all await the same shutdown', () async {
      final isolate = YAJsonIsolate();
      await isolate.decode('{}');

      // Started before either is awaited, so a second call must not report
      // the isolate as gone while the first is still shutting it down.
      final first = isolate.dispose();
      final second = isolate.dispose();

      await expectLater(
        Future.wait([first, second]).timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test('using the isolate after dispose throws', () async {
      final isolate = YAJsonIsolate();
      await isolate.decode('{}');
      await isolate.dispose();

      // Without this the calls below would spawn a replacement isolate onto a
      // closed receive port and then wait for a reply that never arrives.
      expect(isolate.decode('{}'), throwsStateError);
      expect(isolate.encode({}), throwsStateError);
      expect(isolate.initialize(), throwsStateError);
    });

    test('a never used isolate also rejects work after dispose', () async {
      final isolate = YAJsonIsolate();
      await isolate.dispose();

      expect(isolate.decode('{}'), throwsStateError);
    });
  });
}
