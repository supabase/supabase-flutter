import 'package:realtime_client/src/constants.dart';
import 'package:realtime_client/src/message.dart';
import 'package:test/test.dart';

void main() {
  group('Message', () {
    test('message with null refs serializes correctly', () {
      final message = Message(
        topic: 'phoenix',
        event: ChannelEvents.heartbeat,
        payload: {},
        ref: null,
        joinRef: null,
      );
      final json = message.toJson();
      expect(json['ref'], isNull);
      expect(json['join_ref'], isNull);
      expect(json['topic'], equals('phoenix'));
      expect(json['event'], equals('heartbeat'));
      expect(json['payload'], equals({}));
    });

    test('heartbeat message with null joinRef', () {
      final message = Message(
        topic: 'phoenix',
        event: ChannelEvents.heartbeat,
        payload: {},
        ref: '123',
        joinRef: null,
      );
      final json = message.toJson();
      expect(json['ref'], equals('123'));
      expect(json.containsKey('join_ref'), isFalse);
      expect(json['topic'], equals('phoenix'));
      expect(json['event'], equals('heartbeat'));
    });

    test('message with null ref but valid joinRef', () {
      final message = Message(
        topic: 'room:lobby',
        event: ChannelEvents.join,
        payload: {'user_id': '123'},
        ref: null,
        joinRef: 'join-456',
      );
      final json = message.toJson();
      expect(json.containsKey('ref'), isFalse);
      expect(json['join_ref'], equals('join-456'));
      expect(json['topic'], equals('room:lobby'));
      expect(json['payload'], equals({'user_id': '123'}));
    });

    test('message with both ref and joinRef', () {
      final message = Message(
        topic: 'room:lobby',
        event: ChannelEvents.join,
        payload: {'user_id': '123'},
        ref: 'ref-789',
        joinRef: 'join-456',
      );
      final json = message.toJson();
      expect(json['ref'], equals('ref-789'));
      expect(json['join_ref'], equals('join-456'));
      expect(json['topic'], equals('room:lobby'));
      expect(json['payload'], equals({'user_id': '123'}));
    });

    test('message with ref but null joinRef', () {
      final message = Message(
        topic: 'room:lobby',
        event: ChannelEvents.leave,
        payload: {},
        ref: 'ref-999',
        joinRef: null,
      );
      final json = message.toJson();
      expect(json['ref'], equals('ref-999'));
      expect(json.containsKey('join_ref'), isFalse);
      expect(json['topic'], equals('room:lobby'));
    });

    test('ref parameter is optional in constructor', () {
      final message = Message(
        topic: 'phoenix',
        event: ChannelEvents.heartbeat,
        payload: {},
        // ref is not provided, should be null
      );
      expect(message.ref, isNull);
      final json = message.toJson();
      expect(json.containsKey('ref'), isFalse);
    });
  });
}
