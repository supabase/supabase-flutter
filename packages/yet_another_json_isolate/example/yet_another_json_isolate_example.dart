import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

void main() async {
  final isolate = YAJsonIsolate();

  await isolate.initialize();

  final json = await isolate.decode('{"a": 1, "b": 2}');
  print(json);

  final str = await isolate.encode(json);
  print(str);
  isolate.dispose();
}
