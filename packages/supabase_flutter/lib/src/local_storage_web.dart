import 'package:web/web.dart';

final _localStorage = window.localStorage;

bool hasAccessToken(String persistSessionKey) =>
    _localStorage.getItem(persistSessionKey) != null;

String? accessToken(String persistSessionKey) =>
    _localStorage.getItem(persistSessionKey);

void removePersistedSession(String persistSessionKey) =>
    _localStorage.removeItem(persistSessionKey);

void persistSession(String persistSessionKey, persistSessionString) =>
    _localStorage.setItem(persistSessionKey, persistSessionString);
