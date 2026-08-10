import 'package:meta/meta.dart';

@internal
class Counter {
  int _value = 0;

  int get value => _value;

  int increment() {
    return _value++;
  }
}
