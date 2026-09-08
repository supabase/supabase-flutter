import 'package:meta/meta.dart';
import 'package:web/web.dart';

final _localStorage = window.localStorage;

@internal
String? getItem(String key) => _localStorage.getItem(key);

@internal
void setItem(String key, String value) => _localStorage.setItem(key, value);

@internal
void removeItem(String key) => _localStorage.removeItem(key);
