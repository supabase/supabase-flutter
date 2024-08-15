import 'dart:html' as html;

import 'package:gotrue/src/types/types.dart';

BroadcastChannel getBroadcastChannel(String broadcastKey) {
  final broadcast = html.BroadcastChannel(broadcastKey);
  return (
    onMessage: broadcast.onMessage.map((event) => event.data.toString()),
    postMessage: broadcast.postMessage,
    close: broadcast.close,
  );
}
