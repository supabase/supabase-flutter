import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';

import 'supabase_client.dart';

/// Extends a [SupabaseClient] from the outside, without changing how the
/// application calls it.
///
/// An interceptor can wrap the [PostgrestTableExecutor] that runs the
/// requests of the typed table API, [SupabaseClient.table], and receives the
/// client once it is fully constructed. The untyped [SupabaseClient.from],
/// `rpc`, storage, functions and realtime traffic never passes through an
/// interceptor.
///
/// Interceptors are given to the [SupabaseClient] constructor, or to
/// `Supabase.initialize` in Flutter:
///
/// ```dart
/// final supabase = SupabaseClient(url, key, interceptors: [offline]);
/// ```
@experimental
abstract class SupabaseClientInterceptor {
  const SupabaseClientInterceptor();

  /// Returns the executor [SupabaseClient.table] runs its requests through.
  ///
  /// [inner] sends a request to PostgREST with the current access token, so
  /// an executor that holds a request back and runs it through [inner] later
  /// still authenticates as the current user. Interceptors wrap in the order
  /// they were given, so the last interceptor sees a request first. Return
  /// [inner] to leave execution untouched.
  PostgrestTableExecutor wrapTableExecutor(PostgrestTableExecutor inner) =>
      inner;

  /// Called once with the fully constructed [client], after every service
  /// client exists.
  void attach(SupabaseClient client) {}

  /// Called when the host application returns to the foreground, for
  /// example on `AppLifecycleState.resumed` in Flutter.
  ///
  /// The host does not wait for the returned future, so a long running
  /// reaction, a synchronization for example, does not delay anything else
  /// the host does on resume. An error the future completes with is logged.
  Future<void> resume() async {}

  /// Called from [SupabaseClient.dispose] before the service clients are
  /// disposed. An error thrown here is logged and does not stop the other
  /// interceptors or the client from being disposed.
  Future<void> dispose() async {}
}
