import 'package:web/web.dart';
import 'package:meta/meta.dart';

final _localStorage = window.localStorage;

@internal
bool hasAccessToken(String persistSessionKey) =>
    _localStorage.getItem(persistSessionKey) != null;

@internal
String? accessToken(String persistSessionKey) =>
    _localStorage.getItem(persistSessionKey);

@internal
void removePersistedSession(String persistSessionKey) =>
    _localStorage.removeItem(persistSessionKey);

@internal
void persistSession(String persistSessionKey, persistSessionString) =>
    _localStorage.setItem(persistSessionKey, persistSessionString);
