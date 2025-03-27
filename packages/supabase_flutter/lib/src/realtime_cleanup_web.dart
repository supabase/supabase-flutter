import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

@JS()
external JSFunction? supabaseFlutterWSToClose;

/// Store a function to properly disconnect the previous [RealtimeClient] in
/// the js context.
///
/// WebSocket connections are not closed when Flutter is hot-restarted on web.
///
/// This causes old dart code that is still associated with the WebSocket
/// connection to be still running and causes unexpected behavior like type
/// errors and the fact that the events to the old connection may still be
/// logged.
void markRealtimeClientToBeDisconnected(RealtimeClient client) {
  void disconnect() {
    client.disconnect(
        code: 1000, reason: 'Closed due to Flutter Web hot-restart');
  }

  supabaseFlutterWSToClose = disconnect.toJS;
}

/// Disconnect the previous [RealtimeClient] if it exists.
///
/// This is done by calling the function stored by
/// [markRealtimeClientToBeDisconnected] from the js context
void disconnectPreviousRealtimeClient() {
  if (supabaseFlutterWSToClose != null) {
    supabaseFlutterWSToClose!.callAsFunction();
    supabaseFlutterWSToClose = null;
  }
}
