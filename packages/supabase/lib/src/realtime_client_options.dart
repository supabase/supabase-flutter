/// {@template realtime_client_options}
/// Options to pass to the RealtimeClient.
/// Default is 10 per second
/// {@endtemplate}
class RealtimeClientOptions {
  /// How many events the RealtimeClient can push in a second
  final int? eventsPerSecond;

  /// {@macro realtime_client_options}
  const RealtimeClientOptions({this.eventsPerSecond});
}
