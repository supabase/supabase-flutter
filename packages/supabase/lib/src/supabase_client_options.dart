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

  const StorageClientOptions({this.retryAttempts = 0});
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

  /// the timeout to trigger push timeouts
  final Duration? timeout;

  /// The WebSocket implementation to use
  final WebSocketTransport? webSocketTransport;

  /// {@macro realtime_client_options}
  const RealtimeClientOptions({
    this.eventsPerSecond,
    this.logLevel,
    this.timeout,
    this.webSocketTransport,
  });

  RealtimeClientOptions copyWith({
    int? eventsPerSecond,
    RealtimeLogLevel? logLevel,
    Duration? timeout,
    WebSocketTransport? webSocketTransport,
  }) {
    return RealtimeClientOptions(
      // ignore: deprecated_member_use_from_same_package
      eventsPerSecond: eventsPerSecond ?? this.eventsPerSecond,
      logLevel: logLevel ?? this.logLevel,
      timeout: timeout ?? this.timeout,
      webSocketTransport: webSocketTransport ?? this.webSocketTransport,
    );
  }
}
