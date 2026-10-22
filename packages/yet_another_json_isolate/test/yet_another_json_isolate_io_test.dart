@TestOn('vm')
library;

import 'dart:async';
import 'dart:collection';
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

/// A JSON object that cannot be sent to another isolate because it holds a
/// [ReceivePort].
class _UnsendableMap extends MapBase<String, Object?> {
  _UnsendableMap(this._entries);

  final Map<String, Object?> _entries;
  final ReceivePort port = ReceivePort();

  @override
  Object? operator [](Object? key) => _entries[key];

  @override
  void operator []=(String key, Object? value) => _entries[key] = value;

  @override
  void clear() => _entries.clear();

  @override
  Iterable<String> get keys => _entries.keys;

  @override
  Object? remove(Object? key) => _entries.remove(key);
}

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

    test('encodes a large structure holding an unsendable value', () async {
      final isolate = YAJsonIsolate();
      addTearDown(() => dispose(isolate));
      final value = _UnsendableButEncodable();
      addTearDown(value.port.close);
      final large = [
        for (var i = 0; i < 5000; i++) {'id': i, 'name': 'user_$i'},
        value,
      ];

      final encoded = await isolate.encode(large);
      final decoded = jsonDecode(encoded) as List<dynamic>;
      expect(decoded, hasLength(5001));
      expect(decoded.first, {'id': 0, 'name': 'user_0'});
      expect(decoded[4999], {'id': 4999, 'name': 'user_4999'});
      expect(decoded.last, {'type': 'unsendable'});
    });

    test('encodes a large unsendable map inline', () async {
      final map = _UnsendableMap({
        for (var i = 0; i < 5000; i++) 'user_$i': {'id': i},
      });
      addTearDown(map.port.close);
      final isolate = YAJsonIsolate();
      addTearDown(() => dispose(isolate));

      final decoded = jsonDecode(await isolate.encode(map)) as Map;
      expect(decoded, hasLength(5000));
      expect(decoded['user_4999'], {'id': 4999});
    });
  });
}
