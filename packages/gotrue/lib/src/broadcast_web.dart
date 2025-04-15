import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:gotrue/src/types/types.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

final _log = Logger('supabase.auth');

BroadcastChannel getBroadcastChannel(String broadcastKey) {
  final broadcast = web.BroadcastChannel(broadcastKey);
  final controller = StreamController<Map<String, dynamic>>();

  void onMessage(web.Event event) {
    if (event is web.MessageEvent) {
      final dataMap = event.data.dartify();
      controller.add(json.decode(json.encode(dataMap)));
    }
  }

  broadcast.onmessage = onMessage.toJS;

  return (
    onMessage: controller.stream,
    postMessage: (message) {
      _log.finest('Broadcasting message: $message');
      _log.fine('Broadcasting event: ${message['event']}');
      broadcast.postMessage(message.jsify() as JSAny);
    },
    close: () {
      broadcast.close();
      controller.close();
    },
  );
}
