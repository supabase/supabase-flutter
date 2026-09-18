import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:meta/meta.dart';

import 'default_http_client.dart';

/// The `dart:io` client behind [createDefaultHttpClient], with its idle
/// timeout raised to [defaultHttpIdleTimeout].
@visibleForTesting
HttpClient createDefaultIoHttpClient() =>
    HttpClient()..idleTimeout = defaultHttpIdleTimeout;

/// The transport a Supabase client uses when none is passed to it.
///
/// Every call returns a new client with its own connection pool, so the
/// Supabase client that receives it owns it and closes it on dispose.
Client createDefaultHttpClient() => IOClient(createDefaultIoHttpClient());
