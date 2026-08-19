import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_auth/src/types/types.dart';
import 'package:supabase_auth/src/logger.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

@internal
BroadcastChannel getBroadcastChannel(String broadcastKey) {
  final broadcast = web.BroadcastChannel(broadcastKey);
  final controller = StreamController<Map<String, dynamic>>();

  void onMessage(web.MessageEvent event) {
    final dataMap = event.data.dartify();
    controller.add(json.decode(json.encode(dataMap)));
  }

  broadcast.onmessage = onMessage.toJS;

  return (
    onMessage: controller.stream,
    postMessage: (message) {
      authLogger.finest('Broadcasting message: $message');
      authLogger.fine('Broadcasting event: ${message['event']}');
      broadcast.postMessage(message.jsify()!);
    },
    close: () {
      broadcast.close();
      unawaited(controller.close());
    },
  );
}
