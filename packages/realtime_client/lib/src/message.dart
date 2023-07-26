import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';

class Message {
  final String topic;
  final ChannelEvents event;
  final dynamic payload;
  final String ref;
  final String? joinRef;

  Message({
    required this.topic,
    required this.event,
    required this.payload,
    required this.ref,
    this.joinRef,
  });

  /// Converting to JSON while removing functions
  Map<String, dynamic> toJson() {
    late final dynamic processedPayload;
    if (payload is Map) {
      processedPayload = <String, dynamic>{};
      for (final outerKey in payload.keys) {
        final outerValue = payload[outerKey];
        if (outerValue is Map) {
          for (final innerKey in outerValue.keys) {
            final innerValue = outerValue[innerKey];
            processedPayload[outerKey] ??= {};
            if (innerValue is Binding) {
              processedPayload[outerKey][innerKey] = <String, dynamic>{
                'type': innerValue.type,
                'filter': innerValue.filter,
              };
            } else {
              processedPayload[outerKey][innerKey] = innerValue;
            }
          }
        } else {
          processedPayload[outerKey] = outerValue;
        }
      }
    } else {
      processedPayload = payload;
    }
    return {
      'topic': topic,
      'event':
          event != ChannelEvents.heartbeat ? event.eventName() : 'heartbeat',
      'payload': processedPayload,
      'ref': ref,
      if (joinRef != null) 'join_ref': joinRef,
    };
  }
}
