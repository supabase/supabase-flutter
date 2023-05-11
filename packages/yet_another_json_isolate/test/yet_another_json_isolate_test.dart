import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

const _jsonString = '{"a":1,"b":2}';
const _jsonMap = {'a': 1, 'b': 2};

void main() {
  late YAJsonIsolate isolate;
  group('Initialize isolate manually', () {
    setUp(() async {
      isolate = YAJsonIsolate();
      await isolate.initialize();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('decode', () async {
      final json = await isolate.decode(_jsonString);
      expect(json, _jsonMap);
    });

    test('encode', () async {
      final str = await isolate.encode(_jsonMap);
      expect(str, _jsonString);
    });
  });

  group('Do not initialize isolate manually ', () {
    setUp(() {
      isolate = YAJsonIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('decode', () async {
      final json = await isolate.decode(_jsonString);
      expect(json, _jsonMap);
    });

    test('encode', () async {
      final str = await isolate.encode(_jsonMap);
      expect(str, _jsonString);
    });
  });
}
