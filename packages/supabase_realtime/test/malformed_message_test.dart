import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:test/test.dart';

import 'socket_test_stubs.dart';

const _topic = 'realtime:room';

class _FakeConnection {
  _FakeConnection() {
    when(() => channel.sink).thenReturn(sink);
    when(() => channel.ready).thenAnswer((_) => Future.value());
    when(() => channel.stream).thenAnswer((_) => _incoming.stream);
    when(() => sink.add(any())).thenAnswer((invocation) {
      sent.add(jsonDecode(invocation.positionalArguments.first as String));
    });
    when(() => sink.close()).thenAnswer((_) => _incoming.close());
    when(() => sink.close(any(), any())).thenAnswer((_) => _incoming.close());
  }

  final channel = MockIOWebSocketChannel();
  final sink = MockWebSocketSink();
  final _incoming = StreamController<dynamic>();
  final List<dynamic> sent = [];

  String? get joinRef => sent
      .cast<List<dynamic>>()
      .where((frame) => frame[3] == ChannelEvent.join.eventName())
      .map((frame) => frame[1] as String)
      .lastOrNull;

  void receive(List<dynamic> frame) => _incoming.add(jsonEncode(frame));

  void reply(String ref, Object status, [Object? response]) {
    receive([
      ref,
      ref,
      _topic,
      ChannelEvent.reply.eventName(),
      {'status': status, 'response': response ?? {}},
    ]);
  }
}

/// Collects the errors of the warnings logged by the realtime logger for the
/// rest of the test.
List<Object?> _recordWarningErrors() {
  final records = <Object?>[];
  final subscription = Logger.root.onRecord
      .where(
        (record) =>
            record.loggerName == 'supabase.realtime' &&
            record.level == Level.WARNING,
      )
      .map((record) => record.error)
      .listen(records.add);
  addTearDown(subscription.cancel);
  return records;
}

Matcher _isFormatExceptionNaming(String key) => isA<FormatException>().having(
  (error) => error.message,
  'message',
  contains('"$key"'),
);

void main() {
  late _FakeConnection connection;
  late RealtimeClient client;
  late RealtimeChannel channel;
  late List<RealtimeSubscribeStatusChange> statuses;
  late List<Object?> warnings;

  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('condition not met within 5 seconds');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  setUp(() async {
    statuses = [];
    warnings = _recordWarningErrors();
    client = RealtimeClient(
      'wss://localhost:0/',
      heartbeatInterval: const Duration(minutes: 5),
      transport: (url, headers) => (connection = _FakeConnection()).channel,
    );
    channel = client.channel('room');
    channel.onStatusChange.listen(statuses.add);
    channel.subscribe();
    await waitUntil(() => connection.joinRef != null);
  });

  tearDown(() => client.disconnect());

  test('a reply with a non-string status is logged and dropped', () async {
    final joinRef = connection.joinRef!;
    connection.reply(joinRef, 1);
    await pumpEventQueue();

    expect(warnings, [_isFormatExceptionNaming('status')]);
    expect(channel.isJoined, isFalse);
    expect(statuses, isEmpty);
  });

  test('a reply that is not a map is logged and dropped', () async {
    final joinRef = connection.joinRef!;
    connection.receive([
      joinRef,
      joinRef,
      _topic,
      ChannelEvent.reply.eventName(),
      'ok',
    ]);
    await pumpEventQueue();

    expect(warnings, [isA<FormatException>()]);
    expect(channel.isJoined, isFalse);
  });

  test('a presence state with a non-string reference is logged', () async {
    final joinRef = connection.joinRef!;
    connection.reply(joinRef, 'ok');
    await waitUntil(() => channel.isJoined);

    connection.receive([
      joinRef,
      null,
      _topic,
      'presence_state',
      {
        'user': {
          'metas': [
            {'phx_ref': 1},
          ],
        },
      },
    ]);
    await pumpEventQueue();

    expect(warnings, [_isFormatExceptionNaming('phx_ref')]);
  });

  test('a presence diff without joins is logged', () async {
    final joinRef = connection.joinRef!;
    connection.reply(joinRef, 'ok');
    await waitUntil(() => channel.isJoined);
    connection.receive([
      joinRef,
      null,
      _topic,
      'presence_state',
      <String, Object?>{},
    ]);
    await pumpEventQueue();

    connection.receive([
      joinRef,
      null,
      _topic,
      'presence_diff',
      {'leaves': <String, Object?>{}},
    ]);
    await pumpEventQueue();

    expect(warnings, [_isFormatExceptionNaming('joins')]);
  });

  test('a presence state with a null entry is logged', () async {
    final joinRef = connection.joinRef!;
    connection.reply(joinRef, 'ok');
    await waitUntil(() => channel.isJoined);

    connection.receive([
      joinRef,
      null,
      _topic,
      'presence_state',
      {'user': null},
    ]);
    await pumpEventQueue();

    expect(warnings, [_isFormatExceptionNaming('user')]);
  });

  test('a join error still reports a RealtimeException', () async {
    final joinRef = connection.joinRef!;
    connection.reply(joinRef, 'error', {'reason': 'denied'});
    await waitUntil(() => statuses.isNotEmpty);

    expect(warnings, isEmpty);
    expect(statuses.single.status, RealtimeSubscribeStatus.channelError);
    expect(
      statuses.single.error,
      isA<RealtimeException>().having(
        (error) => error.message,
        'message',
        'denied',
      ),
    );
  });
}
