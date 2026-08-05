import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

import 'package:supabase_common/testing.dart';

/// Asserts how the filters of `stream()` are sent to the realtime server and to
/// PostgREST, without needing either of them to be running.
void main() {
  late HttpServer mockServer;
  late SupabaseClient supabase;
  late List<Map<String, dynamic>> postgresChanges;
  late List<Map<String, String>> restQueries;

  setUp(() async {
    postgresChanges = [];
    restQueries = [];
    // Bound to an explicit address, because `localhost` can resolve to `::1`,
    // which does not survive being interpolated into a URL unbracketed.
    mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    mockServer.listen((request) {
      unawaited(
        _handleRequest(
          request,
          postgresChanges: postgresChanges,
          restQueries: restQueries,
        ),
      );
    });

    supabase = SupabaseClient(
      'http://${InternetAddress.loopbackIPv4.address}:${mockServer.port}',
      localStackServiceRoleKey,
    );
  });

  tearDown(() async {
    await supabase.removeAllChannels();
    await supabase.dispose();
    await mockServer.close(force: true);
  });

  for (final testCase in _testCases) {
    test(testCase.name, () async {
      final subscription = testCase
          .filter(supabase.from('users').stream(primaryKey: ['username']))
          .listen(null);
      addTearDown(subscription.cancel);

      await _eventually(
        () => postgresChanges.isNotEmpty && restQueries.isNotEmpty,
        'the channel to join and the PostgREST request to arrive',
      );

      expect(postgresChanges.single['filter'], testCase.realtimeFilter);
      expect(restQueries.single, testCase.restQuery);
    });
  }
}

/// Records what the client sends and answers just enough for the channel to
/// reach the subscribed state and for the PostgREST request to succeed.
Future<void> _handleRequest(
  HttpRequest request, {
  required List<Map<String, dynamic>> postgresChanges,
  required List<Map<String, String>> restQueries,
}) async {
  if (WebSocketTransformer.isUpgradeRequest(request)) {
    final socket = IOWebSocketChannel(
      await WebSocketTransformer.upgrade(request),
    );
    socket.stream.listen((message) {
      // Realtime protocol 2.0.0 frames are the positional JSON array
      // `[joinRef, ref, topic, event, payload]`.
      final frame = json.decode(message as String) as List;
      if (frame[3] != 'phx_join') {
        return;
      }
      final config =
          (frame[4] as Map<String, dynamic>)['config'] as Map<String, dynamic>;
      final changes = (config['postgres_changes'] as List)
          .cast<Map<String, dynamic>>();
      postgresChanges.addAll(changes);
      socket.sink.add(
        json.encode([
          frame[0],
          frame[1],
          frame[2],
          'phx_reply',
          {
            'status': 'ok',
            'response': {
              'postgres_changes': changes.indexed
                  .map((entry) => {...entry.$2, 'id': entry.$1})
                  .toList(),
            },
          },
        ]),
      );
    });
    return;
  }

  restQueries.add(request.uri.queryParameters);
  request.response
    ..statusCode = 200
    ..headers.contentType = ContentType.json
    ..write('[]');
  await request.response.close();
}

typedef _TestCase = ({
  String name,
  SupabaseStreamBuilder Function(SupabaseStreamFilterBuilder stream) filter,
  String? realtimeFilter,
  Map<String, String> restQuery,
});

final _testCases = <_TestCase>[
  (
    name: 'without filters no filter is sent',
    filter: (stream) => stream,
    realtimeFilter: null,
    restQuery: {'select': '*'},
  ),
  (
    name: 'eq',
    filter: (stream) => stream.eq('status', 'ONLINE'),
    realtimeFilter: 'status=eq.ONLINE',
    restQuery: {'select': '*', 'status': 'eq.ONLINE'},
  ),
  (
    name: 'neq',
    filter: (stream) => stream.neq('status', 'ONLINE'),
    realtimeFilter: 'status=neq.ONLINE',
    restQuery: {'select': '*', 'status': 'neq.ONLINE'},
  ),
  (
    name: 'lt',
    filter: (stream) => stream.lt('age', 20),
    realtimeFilter: 'age=lt.20',
    restQuery: {'select': '*', 'age': 'lt.20'},
  ),
  (
    name: 'lte',
    filter: (stream) => stream.lte('age', 20),
    realtimeFilter: 'age=lte.20',
    restQuery: {'select': '*', 'age': 'lte.20'},
  ),
  (
    name: 'gt',
    filter: (stream) => stream.gt('age', 20),
    realtimeFilter: 'age=gt.20',
    restQuery: {'select': '*', 'age': 'gt.20'},
  ),
  (
    name: 'gte',
    filter: (stream) => stream.gte('age', 20),
    realtimeFilter: 'age=gte.20',
    restQuery: {'select': '*', 'age': 'gte.20'},
  ),
  (
    name: 'inFilter',
    filter: (stream) => stream.inFilter('status', ['ONLINE', 'OFFLINE']),
    realtimeFilter: 'status=in.(ONLINE,OFFLINE)',
    restQuery: {'select': '*', 'status': 'in.("ONLINE","OFFLINE")'},
  ),
  (
    name: 'like',
    filter: (stream) => stream.like('username', '%supa%'),
    realtimeFilter: 'username=like.%supa%',
    restQuery: {'select': '*', 'username': 'like.%supa%'},
  ),
  (
    name: 'ilike',
    filter: (stream) => stream.ilike('username', '%SUPA%'),
    realtimeFilter: 'username=ilike.%SUPA%',
    restQuery: {'select': '*', 'username': 'ilike.%SUPA%'},
  ),
  (
    name: 'matchRegex',
    filter: (stream) => stream.matchRegex('username', '^supa.*'),
    realtimeFilter: 'username=match.^supa.*',
    restQuery: {'select': '*', 'username': 'match.^supa.*'},
  ),
  (
    name: 'imatchRegex',
    filter: (stream) => stream.imatchRegex('username', '^SUPA.*'),
    realtimeFilter: 'username=imatch.^SUPA.*',
    restQuery: {'select': '*', 'username': 'imatch.^SUPA.*'},
  ),
  (
    name: 'isFilter with null',
    filter: (stream) => stream.isFilter('data', null),
    realtimeFilter: 'data=is.null',
    restQuery: {'select': '*', 'data': 'is.null'},
  ),
  (
    name: 'isFilter with a boolean',
    filter: (stream) => stream.isFilter('confirmed', true),
    realtimeFilter: 'confirmed=is.true',
    restQuery: {'select': '*', 'confirmed': 'is.true'},
  ),
  (
    name: 'isDistinct',
    filter: (stream) => stream.isDistinct('status', 'ONLINE'),
    realtimeFilter: 'status=isdistinct.ONLINE',
    restQuery: {'select': '*', 'status': 'isdistinct.ONLINE'},
  ),
  (
    name: 'multiple filters are combined with a comma',
    filter: (stream) =>
        stream.eq('status', 'ONLINE').like('username', '%supa%'),
    realtimeFilter: 'status=eq.ONLINE,username=like.%supa%',
    restQuery: {
      'select': '*',
      'status': 'eq.ONLINE',
      'username': 'like.%supa%',
    },
  ),
  (
    name: 'the values of an inFilter are not confused with further filters',
    filter: (stream) => stream
        .inFilter('status', ['ONLINE', 'OFFLINE'])
        .like('username', '%supa%'),
    realtimeFilter: 'status=in.(ONLINE,OFFLINE),username=like.%supa%',
    restQuery: {
      'select': '*',
      'status': 'in.("ONLINE","OFFLINE")',
      'username': 'like.%supa%',
    },
  ),
  // Realtime sends all filters as one comma separated string, so a comma in a
  // value has to be quoted there. PostgREST receives every filter as its own
  // query parameter, where quoting would become part of the value.
  (
    name: 'a value with a comma is only quoted for realtime',
    filter: (stream) => stream.eq('username', 'supa,bot'),
    realtimeFilter: 'username=eq."supa,bot"',
    restQuery: {'select': '*', 'username': 'eq.supa,bot'},
  ),
];

Future<void> _eventually(bool Function() condition, String description) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) {
      return;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for $description.');
}
