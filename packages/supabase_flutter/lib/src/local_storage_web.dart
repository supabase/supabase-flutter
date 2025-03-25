import 'package:web/web.dart';

final _localStorage = window.localStorage;

Future<bool> hasAccessToken(String persistSessionKey) async =>
    _localStorage.getItem(persistSessionKey) != null;

Future<String?> accessToken(String persistSessionKey) async =>
    _localStorage.getItem(persistSessionKey);

Future<void> removePersistedSession(String persistSessionKey) async =>
    _localStorage.removeItem(persistSessionKey);

Future<void> persistSession(
        String persistSessionKey, persistSessionString) async =>
    _localStorage.setItem(persistSessionKey, persistSessionString);
