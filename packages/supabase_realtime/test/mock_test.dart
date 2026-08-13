import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';

void main() {
  late RealtimeClient client;
  late HttpServer mockServer;
  WebSocket? webSocket;
  bool hasListener = false;
  bool hasSentData = false;
  StreamSubscription<dynamic>? listener;

  // Version of realtime after adding broadcast and presence
  Future<void> handleMultitenantRealtimeRequests(HttpServer server) async {
    await for (final HttpRequest request in server) {
      final url = request.uri.toString();
      if (url.contains('realtime')) {
        webSocket = await WebSocketTransformer.upgrade(request);
        if (hasListener) {
          return;
        }
        hasListener = true;
        listener = webSocket!.listen((message) {
          unawaited(() async {
            if (hasSentData) {
              return;
            }
            hasSentData = true;

            /// Protocol 2.0.0 text frames are positional arrays:
            /// [join_ref, ref, topic, event, payload].
            ///
            /// `filter` might be there or not depending on whether is a filter
            /// set to the realtime subscription, so include the filter if the
            /// request includes a filter.
            final requestJson = jsonDecode(message as String) as List;
            final requestPayload = requestJson[4] as Map;
            final String? postgresFilter =
                requestPayload['config']['postgres_changes'].first['filter'];

            final topic = requestJson[2];

            // Send an insert event
            if (postgresFilter == null) {
              await Future.delayed(Duration(milliseconds: 300));
              final insertString = jsonEncode([
                null,
                null,
                topic,
                'postgres_changes',
                {
                  'ids': [77086988],
                  'data': {
                    'commit_timestamp': '2021-08-01T08:00:20Z',
                    'record': {'id': 3, 'task': 'task 3', 'status': 't'},
                    'schema': 'public',
                    'table': 'todos',
                    'type': 'INSERT',
                    'filter': ?postgresFilter,
                    'columns': [
                      {
                        'name': 'id',
                        'type': 'int4',
                        'type_modifier': 4294967295,
                      },
                      {
                        'name': 'task',
                        'type': 'text',
                        'type_modifier': 4294967295,
                      },
                      {
                        'name': 'status',
                        'type': 'bool',
                        'type_modifier': 4294967295,
                      },
                    ],
                  },
                },
              ]);
              webSocket!.add(insertString);
            }

            // Send an update event for id = 2
            await Future.delayed(Duration(milliseconds: 10));
            final updateString = jsonEncode([
              null,
              null,
              topic,
              'postgres_changes',
              {
                'ids': [25993878],
                'data': {
                  'columns': [
                    {'name': 'id', 'type': 'int4', 'type_modifier': 4294967295},
                    {
                      'name': 'task',
                      'type': 'text',
                      'type_modifier': 4294967295,
                    },
                    {
                      'name': 'status',
                      'type': 'bool',
                      'type_modifier': 4294967295,
                    },
                  ],
                  'commit_timestamp': '2021-08-01T08:00:30Z',
                  'errors': null,
                  'old_record': {'id': 2},
                  'record': {'id': 2, 'task': 'task 2 updated', 'status': 'f'},
                  'schema': 'public',
                  'table': 'todos',
                  'type': 'UPDATE',
                  'filter': ?postgresFilter,
                },
              },
            ]);
            webSocket!.add(updateString);

            // Send delete event for id=2
            await Future.delayed(Duration(milliseconds: 10));
            final deleteString = jsonEncode([
              null,
              null,
              topic,
              'postgres_changes',
              {
                'data': {
                  'columns': [
                    {'name': 'id', 'type': 'int4', 'type_modifier': 4294967295},
                    {
                      'name': 'task',
                      'type': 'text',
                      'type_modifier': 4294967295,
                    },
                    {
                      'name': 'status',
                      'type': 'bool',
                      'type_modifier': 4294967295,
                    },
                  ],
                  'commit_timestamp': '2022-09-14T02:12:52Z',
                  'errors': null,
                  'old_record': {'id': 2},
                  'schema': 'public',
                  'table': 'todos',
                  'type': 'DELETE',
                  'filter': ?postgresFilter,
                },
                'ids': [48673474],
              },
            ]);
            webSocket!.add(deleteString);
          }());
        });
      } else {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
      }
    }
  }

  tearDown(() async {
    await client.removeAllChannels();

    await listener?.cancel();

    // Wait for the realtime updates to come through
    await Future.delayed(Duration(milliseconds: 100));

    await webSocket?.close();
    await mockServer.close();
  });

  group('Multitenant Realtime', () {
    setUp(() async {
      mockServer = await HttpServer.bind('localhost', 0);
      client = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        parameters: {'apikey': 'supabaseKey'},
      );
      hasListener = false;
      hasSentData = false;
      unawaited(handleMultitenantRealtimeRequests(mockServer));
    });

    test('.on()', () {
      final channel = client.channel('public:todos');
      final changes = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'todos',
      );
      channel.subscribe();

      expect(
        changes,
        emitsInOrder([
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2021-08-01T08:00:20Z',
            'eventType': 'INSERT',
            'new': {'id': 3, 'task': 'task 3', 'status': true},
            'old': {},
            'errors': null,
          }),
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2021-08-01T08:00:30Z',
            'eventType': 'UPDATE',
            'new': {'id': 2, 'task': 'task 2 updated', 'status': false},
            'old': {'id': 2},
            'errors': null,
          }),
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2022-09-14T02:12:52Z',
            'eventType': 'DELETE',
            'new': {},
            'old': {'id': 2},
            'errors': null,
          }),
        ]),
      );
    });

    test('.on() with filter', () {
      final channel = client.channel('public:todos');
      final changes = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'todos',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: 2,
        ),
      );
      channel.subscribe();

      expect(
        changes,
        emitsInOrder([
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2021-08-01T08:00:30Z',
            'eventType': 'UPDATE',
            'new': {'id': 2, 'task': 'task 2 updated', 'status': false},
            'old': {'id': 2},
            'errors': null,
          }),
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2022-09-14T02:12:52Z',
            'eventType': 'DELETE',
            'new': {},
            'old': {'id': 2},
            'errors': null,
          }),
        ]),
      );
    });

    test("correct CHANNEL_ERROR data on heartbeat timeout", () async {
      final statusListener = expectAsync1((
        RealtimeSubscribeStatusChange change,
      ) {
        if (change.status == RealtimeSubscribeStatus.channelError) {
          expect(change.error, isA<RealtimeCloseEvent>());
          final error = change.error as RealtimeCloseEvent;
          expect(error.reason, "heartbeat timeout");
        } else {
          expect(change.status, RealtimeSubscribeStatus.closed);
        }
      }, count: 2);

      final channel = client.channel('public:todos');
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'todos',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: 2,
        ),
      );

      channel.onStatusChange.listen(statusListener);
      channel.subscribe();

      await Future.delayed(Duration(milliseconds: 200));
      await webSocket?.close(
        RealtimeConstants.webSocketCloseNormal,
        "heartbeat timeout",
      );
    });
  });

  // Version of realtime prior to adding broadcast and presence.
  // Will be deprecated at some point.
  Future<void> handleSingleTenantRealtimeRequests(HttpServer server) async {
    await for (final HttpRequest request in server) {
      final url = request.uri.toString();
      if (url.contains('realtime')) {
        webSocket = await WebSocketTransformer.upgrade(request);
        if (hasListener) {
          return;
        }
        hasListener = true;
        listener = webSocket!.listen((message) {
          unawaited(() async {
            if (hasSentData) {
              return;
            }
            hasSentData = true;

            /// Protocol 2.0.0 text frames are positional arrays:
            /// [join_ref, ref, topic, event, payload].
            ///
            /// `filter` might be there or not depending on whether is a filter
            /// set to the realtime subscription, so include the filter if the
            /// request includes a filter.
            final requestJson = jsonDecode(message as String) as List;
            final requestPayload = requestJson[4] as Map;

            final String? postgresFilter =
                requestPayload['config']['postgres_changes'].first['filter'];

            final topic = requestJson[2];

            final replyString = jsonEncode([
              null,
              "1",
              topic,
              "phx_reply",
              {"response": {}, "status": "ok"},
            ]);
            webSocket!.add(replyString);

            // Send an insert event
            if (postgresFilter == null) {
              await Future.delayed(Duration(milliseconds: 300));
              final insertString = jsonEncode([
                null,
                null,
                topic,
                "INSERT",
                {
                  "columns": [
                    {"name": "id", "type": "int4"},
                    {"name": "task", "type": "text"},
                    {"name": "status", "type": "bool"},
                  ],
                  "commit_timestamp": "2022-09-24T05:42:01.303668+00:00",
                  "errors": null,
                  "record": {"id": 1, "status": true, "task": "task 1"},
                  "schema": "public",
                  "table": "todos",
                  "type": "INSERT",
                },
              ]);
              webSocket!.add(insertString);
            }

            // Send an update event for id = 2
            await Future.delayed(Duration(milliseconds: 10));
            final updateString = jsonEncode([
              null,
              null,
              topic,
              "UPDATE",
              {
                "columns": [
                  {"name": "id", "type": "int4"},
                  {"name": "task", "type": "text"},
                  {"name": "status", "type": "bool"},
                ],
                "commit_timestamp": "2022-09-24T05:42:01.303668+00:00",
                "errors": null,
                "old_record": {"id": 2},
                "record": {"id": 2, "status": false, "task": "task 2 updated"},
                "schema": "public",
                "table": "todos",
                "type": "UPDATE",
              },
            ]);
            webSocket!.add(updateString);

            // Send delete event for id=2
            await Future.delayed(Duration(milliseconds: 10));
            final deleteString = jsonEncode([
              null,
              null,
              topic,
              "DELETE",
              {
                "columns": [
                  {"name": "id", "type": "int4"},
                  {"name": "task", "type": "text"},
                  {"name": "status", "type": "bool"},
                ],
                "commit_timestamp": "2022-09-24T05:42:01.303668+00:00",
                "errors": null,
                "old_record": {"id": 2},
                "record": {},
                "schema": "public",
                "table": "todos",
                "type": "DELETE",
              },
            ]);
            webSocket!.add(deleteString);
          }());
        });
      } else {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
      }
    }
  }

  group('Singletenant Realtime', () {
    setUp(() async {
      mockServer = await HttpServer.bind('localhost', 0);
      client = RealtimeClient(
        'ws://${mockServer.address.host}:${mockServer.port}/realtime/v1',
        parameters: {'apikey': 'supabaseKey'},
      );
      hasListener = false;
      hasSentData = false;
      unawaited(handleSingleTenantRealtimeRequests(mockServer));
    });

    test('.on()', () {
      final channel = client.channel('public:todos');
      final changes = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'todos',
      );
      channel.subscribe();

      expect(
        changes,
        emitsInOrder([
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2022-09-24T05:42:01.303668+00:00',
            'eventType': 'INSERT',
            'new': {'id': 1, 'task': 'task 1', 'status': true},
            'old': {},
            'errors': null,
          }),
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2022-09-24T05:42:01.303668+00:00',
            'eventType': 'UPDATE',
            'new': {'id': 2, 'task': 'task 2 updated', 'status': false},
            'old': {'id': 2},
            'errors': null,
          }),
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2022-09-24T05:42:01.303668+00:00',
            'eventType': 'DELETE',
            'new': {},
            'old': {'id': 2},
            'errors': null,
          }),
        ]),
      );
    });

    test('.on() with filter', () {
      final channel = client.channel('public:todos');
      final changes = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'todos',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: 2,
        ),
      );
      channel.subscribe();

      expect(
        changes,
        emitsInOrder([
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2022-09-24T05:42:01.303668+00:00',
            'eventType': 'UPDATE',
            'new': {'id': 2, 'task': 'task 2 updated', 'status': false},
            'old': {'id': 2},
            'errors': null,
          }),
          PostgresChangePayload.fromPayload({
            'schema': 'public',
            'table': 'todos',
            'commit_timestamp': '2022-09-24T05:42:01.303668+00:00',
            'eventType': 'DELETE',
            'new': {},
            'old': {'id': 2},
            'errors': null,
          }),
        ]),
      );
    });
  });
}
