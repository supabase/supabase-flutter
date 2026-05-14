import 'package:supabase/supabase.dart';

class PostgrestClientOptions {
  final String schema;

  const PostgrestClientOptions({this.schema = 'public'});
}

class AuthClientOptions {
  final bool autoRefreshToken;
  final GotrueAsyncStorage? pkceAsyncStorage;
  final AuthFlowType authFlowType;

  const AuthClientOptions({
    this.autoRefreshToken = true,
    this.pkceAsyncStorage,
    this.authFlowType = AuthFlowType.pkce,
  });
}

class StorageClientOptions {
  final int retryAttempts;

  /// Whether to rewrite legacy storage URLs to use the dedicated storage host
  /// (`<ref>.storage.supabase.co`). Enables uploads larger than 50 GB by
  /// bypassing proxy buffering limits.
  ///
  /// Set to `true` only if your project has the dedicated storage host
  /// enabled; otherwise every storage request will fail with an
  /// `Invalid Storage request` error. Defaults to `false` (opt-in).
  final bool useNewHostname;

  const StorageClientOptions(
      {this.retryAttempts = 0, this.useNewHostname = false});
}

class FunctionsClientOptions {
  final String? region;

  const FunctionsClientOptions({this.region});
}

/// {@template realtime_client_options}
/// Options to pass to the RealtimeClient.
/// {@endtemplate}
class RealtimeClientOptions {
  /// How many events the RealtimeClient can push in a second
  ///
  /// Defaults to 10 events per second
  @Deprecated(
      'Client side rate limit has been removed. This option will be ignored.')
  final int? eventsPerSecond;

  /// Level of realtime server logs to be logged
  final RealtimeLogLevel? logLevel;

  /// The timeout to trigger push timeouts
  final Duration? timeout;

  /// Custom WebSocket implementation to use
  final WebSocketTransport? transport;

  /// {@macro realtime_client_options}
  const RealtimeClientOptions({
    this.eventsPerSecond,
    this.logLevel,
    this.timeout,
    this.transport,
  });

  RealtimeClientOptions copyWith({
    int? eventsPerSecond,
    RealtimeLogLevel? logLevel,
    Duration? timeout,
    WebSocketTransport? transport,
  }) {
    return RealtimeClientOptions(
      // ignore: deprecated_member_use_from_same_package
      eventsPerSecond: eventsPerSecond ?? this.eventsPerSecond,
      logLevel: logLevel ?? this.logLevel,
      timeout: timeout ?? this.timeout,
      transport: transport ?? this.transport,
    );
  }
}
