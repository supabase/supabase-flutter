// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:supabase_flutter/supabase_flutter.dart';

final _localStorage = html.window.localStorage;

Future<bool> hasAccessToken() async =>
    _localStorage.containsKey(SharedPreferencesLocalStorage.persistSessionKey);

Future<String?> accessToken() async =>
    _localStorage[SharedPreferencesLocalStorage.persistSessionKey];

Future<void> removePersistedSession() async =>
    _localStorage.remove(SharedPreferencesLocalStorage.persistSessionKey);

Future<void> persistSession(persistSessionString) async =>
    _localStorage[SharedPreferencesLocalStorage.persistSessionKey] =
        persistSessionString;
