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
  });
}
