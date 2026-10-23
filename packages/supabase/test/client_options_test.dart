import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  test('PostgrestClientOptions.copyWith replaces only the given fields', () {
    const options = PostgrestClientOptions(
      schema: 'private',
      requestTimeout: Duration(seconds: 5),
    );

    final copy = options.copyWith(
      retryOptions: const SupabaseRetryOptions(count: 0),
    );

    expect(copy.schema, 'private');
    expect(copy.requestTimeout, const Duration(seconds: 5));
    expect(copy.retryOptions.count, 0);
  });

  test('AuthClientOptions.copyWith replaces only the given fields', () {
    final storage = MemoryAuthAsyncStorage();
    final options = AuthClientOptions(
      asyncStorage: storage,
      authFlowType: AuthFlowType.implicit,
      storageKey: 'key',
    );

    final copy = options.copyWith(persistSession: true);

    expect(copy.asyncStorage, same(storage));
    expect(copy.authFlowType, AuthFlowType.implicit);
    expect(copy.storageKey, 'key');
    expect(copy.persistSession, isTrue);
    expect(copy.autoRefreshToken, isTrue);
  });

  test('FunctionsClientOptions.copyWith replaces only the given fields', () {
    const options = FunctionsClientOptions(region: FunctionsRegion.euWest1);

    final copy = options.copyWith(requestTimeout: const Duration(seconds: 5));

    expect(copy.region, FunctionsRegion.euWest1);
    expect(copy.requestTimeout, const Duration(seconds: 5));
  });

  test('RealtimeClientOptions.copyWith replaces only the given fields', () {
    const options = RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
      timeout: Duration(seconds: 5),
    );

    final copy = options.copyWith(
      heartbeatInterval: const Duration(seconds: 1),
    );

    expect(copy.logLevel, RealtimeLogLevel.info);
    expect(copy.timeout, const Duration(seconds: 5));
    expect(copy.heartbeatInterval, const Duration(seconds: 1));
  });

  test('YAJsonIsolate is exported to build a realtime codec with', () async {
    final isolate = YAJsonIsolate();
    addTearDown(isolate.dispose);
    final options = RealtimeClientOptions(
      encode: (message) => isolate.encode(message.toJson()),
      decode: (frame) async =>
          RealtimeMessage.fromJson(await isolate.decode(frame as String)),
    );

    final frame = await options.encode!(
      const RealtimeMessage(topic: 'room', event: 'ping'),
    );
    final message = await options.decode!(frame);

    expect(message.topic, 'room');
    expect(message.event, 'ping');
  });
}
