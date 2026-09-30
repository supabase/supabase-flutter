/// How the realtime socket follows the app lifecycle.
///
/// `Supabase` disconnects the realtime socket when the app is paused and, when
/// the app is resumed, reconnects it and rejoins every channel that was
/// joined. The default options do that as soon as the app is paused.
///
/// Set [disconnectAfterPause] to keep the socket open through short pauses.
/// On iOS a full-screen view such as a video ad or a system sheet reports the
/// app as paused while it is on screen, so without a grace period each one
/// costs a new socket and a rejoin, with a fresh authorization, of every
/// channel. Use [RealtimeLifecycleOptions.manual] to keep the socket out of
/// the app lifecycle altogether.
class RealtimeLifecycleOptions {
  const RealtimeLifecycleOptions({this.disconnectAfterPause = Duration.zero})
    : managed = true;

  /// Leaves the realtime socket alone when the app is paused or resumed.
  ///
  /// The socket stays open in the background until the operating system
  /// closes it, after which the realtime client reconnects and rejoins its
  /// channels by itself once the app runs again.
  const RealtimeLifecycleOptions.manual()
    : managed = false,
      disconnectAfterPause = Duration.zero;

  /// Whether the realtime socket is disconnected and reconnected as the app is
  /// paused and resumed.
  final bool managed;

  /// How long the app has to stay paused before the socket is disconnected.
  ///
  /// When the app is resumed before this has passed the socket stays open, so
  /// nothing is reconnected or rejoined. The app being detached disconnects
  /// the socket right away regardless. The pause is measured in wall-clock
  /// time, so a pause that outlasted this while the operating system had the
  /// app suspended still disconnects and reconnects the socket when the app
  /// is next resumed.
  final Duration disconnectAfterPause;
}
