import 'package:realtime_client/realtime_client.dart';

/// {@template realtime_client_options}
/// Options to pass to the RealtimeClient.
/// {@endtemplate}
class RealtimeClientOptions {
  /// How many events the RealtimeClient can push in a second
  ///
  /// Defaults to 10 events per second
  final int? eventsPerSecond;

  /// Level of realtime server logs to to be logged
  final RealtimeLogLevel? logLevel;

  /// {@macro realtime_client_options}
  const RealtimeClientOptions({
    this.eventsPerSecond,
    this.logLevel,
  });
}
