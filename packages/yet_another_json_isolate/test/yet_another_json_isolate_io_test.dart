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
  });
}
