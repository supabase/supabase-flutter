import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/src/join_error.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'socket_test_stubs.dart';

const _unauthorized =
    'Unauthorized: You do not have permissions to read from this Channel '
    'topic: room';
const _expiredToken = 'InvalidJWTToken: Token has expired 30 seconds ago';

void main() {
  group('JoinRecovery.classify', () {
    final cases = {
      _unauthorized: JoinRecovery.fail,
      'PrivateOnly: This project only allows private channels':
          JoinRecovery.fail,
      'TenantNotFound: Tenant not found': JoinRecovery.fail,
      'InvalidJWTToken: Fields `role` and `exp` are required in JWT':
          JoinRecovery.fail,
      'You no longer have permission to access this channel': JoinRecovery.fail,
      _expiredToken: JoinRecovery.refreshToken,
      'Token has expired 5 seconds ago': JoinRecovery.refreshToken,
      'ClientJoinRateLimitReached: Too many joins per second':
          JoinRecovery.backOff,
      'Too many joins per second': JoinRecovery.backOff,
      'UnableToConnectToProject: Realtime was unable to connect':
          JoinRecovery.retry,
      'Unauthorized': JoinRecovery.retry,
      'Something went wrong: try again': JoinRecovery.retry,
      '': JoinRecovery.retry,
    };
    for (final MapEntry(key: reason, value: recovery) in cases.entries) {
      test('"$reason" is ${recovery.name}', () {
        expect(JoinRecovery.classify(reason), recovery);
      });
    }
  });

  group('a rejected join', () {
    late MockRealtimeTransport transport;

    setUp(() => transport = MockRealtimeTransport());

    Iterable<RealtimeMessage> joins() =>
        transport.sent.where((message) => message.event == 'phx_join');

    test('ends in channelError without rejoining', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          'ws://localhost:0',
          transport: transport.call,
        );
        transport.rejectNextJoin('room', reason: _unauthorized);
        final channel = client.channel('room');
        final changes = <RealtimeSubscribeStatusChange>[];
        channel.onStatusChange.listen(changes.add);

        channel.subscribe();
        async.elapse(const Duration(minutes: 5));

        expect(joins(), hasLength(1));
        expect(changes.map((change) => change.status), [
          RealtimeSubscribeStatus.channelError,
        ]);
        expect(
          changes.single.error,
          isA<RealtimeException>()
              .having((error) => error.message, 'message', _unauthorized)
              .having((error) => error.errorCode, 'errorCode', 'Unauthorized'),
        );
        expect(channel.isErrored, isTrue);

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });

    test('is not rejoined when the socket reconnects', () async {
      final client = RealtimeClient(
        'ws://localhost:0',
        transport: transport.call,
        reconnectAfter: (_) => Duration.zero,
      );
      addTearDown(client.disconnect);
      transport.rejectNextJoin('room', reason: _unauthorized);
      client.channel('room').subscribe();
      await pumpEventQueue();

      await transport.closeConnection(code: 1006);
      await pumpEventQueue();

      expect(transport.connectionCount, 2);
      expect(client.isConnected, isTrue);
      expect(joins(), hasLength(1));
    });

    test('is joined again by another subscribe', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          'ws://localhost:0',
          transport: transport.call,
        );
        transport.rejectNextJoin('room', reason: _unauthorized);
        final channel = client.channel('room').subscribe();
        async.flushMicrotasks();
        final statuses = <RealtimeSubscribeStatus>[];
        channel.onStatusChange.listen((change) => statuses.add(change.status));

        expect(identical(channel.subscribe(), channel), isTrue);
        async.flushMicrotasks();

        expect(joins(), hasLength(2));
        expect(statuses, [RealtimeSubscribeStatus.subscribed]);
        expect(channel.isJoined, isTrue);

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });

    test('is joined again with a new access token', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          'ws://localhost:0',
          transport: transport.call,
        );
        transport.rejectNextJoin('room', reason: _unauthorized);
        final channel = client.channel('room').subscribe();
        async.flushMicrotasks();

        unawaited(client.setAccessToken(unsignedTestJwt({'sub': 'user'})));
        async.flushMicrotasks();

        expect(joins(), hasLength(2));
        expect(
          (joins().last.payload as Map)['access_token'],
          unsignedTestJwt({'sub': 'user'}),
        );
        expect(channel.isJoined, isTrue);

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });

    test('with an expired token refreshes the token and rejoins once', () {
      fakeAsync((async) {
        var refreshes = 0;
        final client = RealtimeClient(
          'ws://localhost:0',
          transport: transport.call,
          heartbeatInterval: const Duration(hours: 1),
          customAccessToken: () async =>
              unsignedTestJwt({'sub': 'user', 'refresh': ++refreshes}),
        );
        transport.rejectNextJoin('room', reason: _expiredToken);
        final channel = client.channel('room').subscribe();
        async.flushMicrotasks();

        expect(channel.isJoined, isTrue);
        expect(joins(), hasLength(2));
        expect(refreshes, 2);
        expect(
          (joins().last.payload as Map)['access_token'],
          unsignedTestJwt({'sub': 'user', 'refresh': 2}),
        );

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });

    test('with a token that is still expired after the refresh stops', () {
      fakeAsync((async) {
        var refreshes = 0;
        final client = RealtimeClient(
          'ws://localhost:0',
          transport: transport.call,
          heartbeatInterval: const Duration(hours: 1),
          customAccessToken: () async {
            refreshes++;
            return unsignedTestJwt({'sub': 'user'});
          },
        );
        for (var rejection = 0; rejection < 2; rejection++) {
          transport.rejectNextJoin('room', reason: _expiredToken);
        }
        final channel = client.channel('room');
        final statuses = <RealtimeSubscribeStatus>[];
        channel.onStatusChange.listen((change) => statuses.add(change.status));

        channel.subscribe();
        async.elapse(const Duration(minutes: 5));

        expect(joins(), hasLength(2));
        expect(refreshes, 2);
        expect(statuses, [
          RealtimeSubscribeStatus.channelError,
          RealtimeSubscribeStatus.channelError,
        ]);
        expect(channel.isErrored, isTrue);

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });

    test('with a transient error rejoins after the backoff', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          'ws://localhost:0',
          transport: transport.call,
        );
        transport.rejectNextJoin(
          'room',
          reason: 'UnableToConnectToProject: Realtime was unable to connect',
        );
        final channel = client.channel('room').subscribe();
        async.flushMicrotasks();
        expect(joins(), hasLength(1));

        async.elapse(const Duration(seconds: 1));

        expect(joins(), hasLength(2));
        expect(channel.isJoined, isTrue);

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });
  });

  group('a refused upgrade', () {
    late MockRealtimeTransport transport;
    late List<int?> refusals;

    setUp(() {
      transport = MockRealtimeTransport();
      refusals = [];
    });

    WebSocketChannel connect(String url, Map<String, String> headers) {
      if (refusals.isEmpty) {
        return transport(url, headers);
      }
      final statusCode = refusals.removeAt(0);
      final channel = MockIOWebSocketChannel();
      final sink = MockWebSocketSink();
      when(() => channel.ready).thenAnswer(
        (_) => Future.error(
          WebSocketChannelException.from(
            WebSocketException(
              "Connection to '$url' was not upgraded to websocket",
              statusCode,
            ),
          ),
        ),
      );
      when(() => channel.stream).thenAnswer((_) => const Stream.empty());
      when(() => channel.sink).thenReturn(sink);
      when(sink.close).thenAnswer((_) => Future.value());
      when(() => sink.close(any(), any())).thenAnswer((_) => Future.value());
      return channel;
    }

    for (final statusCode in [401, 403, 404]) {
      test('with HTTP status $statusCode is reported and not retried', () {
        fakeAsync((async) {
          var connects = 0;
          refusals.add(statusCode);
          final client = RealtimeClient(
            'ws://localhost:0',
            transport: (url, headers) {
              connects++;
              return connect(url, headers);
            },
            reconnectAfter: (_) => const Duration(seconds: 1),
          );
          final errors = <Object>[];
          client.onStatusChange.listen((_) {}, onError: errors.add);
          final channel = client.channel('room');
          final statuses = <RealtimeSubscribeStatus>[];
          channel.onStatusChange.listen(
            (change) => statuses.add(change.status),
          );

          channel.subscribe();
          async.elapse(const Duration(minutes: 1));

          expect(connects, 1);
          expect(client.connectionState, SocketState.closed);
          expect(errors, [isA<WebSocketChannelException>()]);
          expect(statuses.first, RealtimeSubscribeStatus.channelError);

          final other = client.channel('other').subscribe();
          async.flushMicrotasks();
          expect(connects, 2);
          expect(channel.isJoined, isTrue);
          expect(other.isJoined, isTrue);

          unawaited(client.disconnect());
          async.flushMicrotasks();
        });
      });
    }

    test('with another HTTP status is retried', () {
      fakeAsync((async) {
        var connects = 0;
        refusals.add(503);
        final client = RealtimeClient(
          'ws://localhost:0',
          transport: (url, headers) {
            connects++;
            return connect(url, headers);
          },
          reconnectAfter: (_) => const Duration(seconds: 1),
        );
        final channel = client.channel('room').subscribe();
        async.flushMicrotasks();
        expect(connects, 1);

        async.elapse(const Duration(seconds: 1));

        expect(connects, 2);
        expect(channel.isJoined, isTrue);

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });
  });
}
