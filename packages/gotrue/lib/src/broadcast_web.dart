import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:gotrue/src/types/types.dart';
import 'package:logging/logging.dart';

final _log = Logger('supabase.gotrue');

BroadcastChannel getBroadcastChannel(String broadcastKey) {
  final broadcast = html.BroadcastChannel(broadcastKey);
  return (
    onMessage: broadcast.onMessage.map((event) {
      final dataMap = js_util.dartify(event.data);

      // some parts have the wrong map type. This is an easy workaround and
      // should be efficient enough for the small session and user data
      return json.decode(json.encode(dataMap));
    }),
    postMessage: (message) {
      _log.finest('Broadcasting message: $message');
      _log.fine('Broadcasting event: ${message['event']}');
      final jsMessage = js_util.jsify(message);
      broadcast.postMessage(jsMessage);
    },
    close: broadcast.close,
  );
}
