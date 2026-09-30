import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'widget_test_stubs.dart';

/// A minimal fake [WebSocketChannel] using [Fake] to avoid
/// implementing all [StreamChannelMixin] methods.
class FakeWebSocketChannel extends Fake implements WebSocketChannel {
  final Completer<void> readyCompleter;
  late final FakeWebSocketSink fakeSink = FakeWebSocketSink(_streamController);
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();

  FakeWebSocketChannel({Completer<void>? readyCompleter})
    : readyCompleter = readyCompleter ?? Completer<void>();

  @override
  Future<void> get ready => readyCompleter.future;

  @override
  // ignore: match-getter-setter-field-names
  WebSocketSink get sink => fakeSink;

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  int? get closeCode => fakeSink.closeCode;

  @override
  String? get closeReason => fakeSink.closeReason;
}

class FakeWebSocketSink extends Fake implements WebSocketSink {
  final StreamController<dynamic> _streamController;
  final Completer<void> _doneCompleter = Completer<void>();
  int? closeCode;
  String? closeReason;

  FakeWebSocketSink(this._streamController);

  @override
  Future<void> close([int? code, String? reason]) async {
    closeCode = code;
    closeReason = reason;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    if (!_streamController.isClosed) {
      await _streamController.close();
    }
  }

  @override
  Future<dynamic> get done => _doneCompleter.future;

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = '';
  const supabaseKey = '';

  late List<Completer<void>> readyCompleters;

  /// Walks the binding back to [AppLifecycleState.resumed] through valid
  /// transitions, since [AppLifecycleListener] asserts on them and the state
  /// carries over from the previous test.
  void resetLifecycleToResumed() {
    final binding = TestWidgetsFlutterBinding.instance;
    final steps = switch (binding.lifecycleState) {
      null || AppLifecycleState.resumed => const <AppLifecycleState>[],
      AppLifecycleState.paused => const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ],
      AppLifecycleState.hidden => const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ],
      AppLifecycleState.inactive ||
      AppLifecycleState.detached => const [AppLifecycleState.resumed],
    };
    for (final state in steps) {
      binding.handleAppLifecycleStateChanged(state);
    }
  }

  Future<void> initializeSupabase({
    RealtimeLifecycleOptions realtimeLifecycleOptions =
        const RealtimeLifecycleOptions(),
  }) async {
    mockAppLink();
    resetLifecycleToResumed();
    readyCompleters = [];
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: const MockEmptyLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      ),
      realtimeClientOptions: RealtimeClientOptions(
        transport: (url, headers) {
          final completer = Completer<void>();
          readyCompleters.add(completer);
          return FakeWebSocketChannel(readyCompleter: completer);
        },
      ),
      realtimeLifecycleOptions: realtimeLifecycleOptions,
    );
  }

  tearDown(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {}
  });

  /// Helper: call connect() and immediately complete the
  /// ready future created by the transport factory.
  Future<void> connectAndReady(RealtimeClient realtime) async {
    // ignore: invalid_use_of_internal_member
    final future = realtime.connect();
    // The transport factory just added a completer
    readyCompleters.last.complete();
    await future;
  }

  /// Repeatedly complete pending ready futures and pump the event queue
  /// until no new completers appear. This handles the case where lifecycle
  /// processing triggers a connect() that creates a new completer.
  Future<void> settleLifecycle() async {
    var previousCount = -1;
    while (readyCompleters.length != previousCount) {
      previousCount = readyCompleters.length;
      for (final completer in readyCompleters) {
        if (!completer.isCompleted) completer.complete();
      }
      await pumpEventQueue();
    }
  }

  void pause() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void resume() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  group('Lifecycle realtime reconnection', () {
    setUp(initializeSupabase);

    test('paused then resumed waits for disconnect '
        'before reconnecting', () async {
      final realtime = Supabase.instance.client.realtime;
      final binding = TestWidgetsFlutterBinding.instance;

      // Add a channel so onResumed() processes reconnection
      realtime.channel('test');

      // Connect with ready completed immediately
      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → triggers disconnect
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // resumed → waits for disconnect, then reconnects
      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // Complete any pending ready futures (reconnect)
      await settleLifecycle();

      expect(realtime.connState, SocketStates.open);
      expect(realtime.conn, isNotNull);
    });

    test('paused → resumed → inactive → resumed '
        'still reconnects', () async {
      final realtime = Supabase.instance.client.realtime;
      final binding = TestWidgetsFlutterBinding.instance;

      realtime.channel('test');

      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → starts disconnect
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // first resumed → queues reconnect after disconnect
      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // inactive → does nothing (not a tracked lifecycle state)
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      // second resumed → queues another reconnect (idempotent)
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // Complete all pending ready futures
      await settleLifecycle();

      // Should have reconnected, not stuck disconnecting
      expect(realtime.connState, SocketStates.open);
      expect(realtime.conn, isNotNull);
    });

    test('rapid paused → resumed → paused → resumed '
        'ends up connected', () async {
      final realtime = Supabase.instance.client.realtime;
      final binding = TestWidgetsFlutterBinding.instance;

      realtime.channel('test');

      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // Rapid lifecycle flapping
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // Complete all pending ready futures as they appear
      await settleLifecycle();

      expect(realtime.connState, SocketStates.open);
      expect(realtime.conn, isNotNull);
    });

    test('resumed then paused before connect completes '
        'cancels reconnect', () async {
      final realtime = Supabase.instance.client.realtime;
      final binding = TestWidgetsFlutterBinding.instance;

      realtime.channel('test');

      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → triggers disconnect
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // resumed → queues reconnect
      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // paused again before connect completes → should cancel the
      // reconnect (target state is now paused)
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // Complete all pending ready futures
      await settleLifecycle();

      // Should be disconnected since the last event was paused
      expect(realtime.connState, SocketStates.disconnected);
      expect(realtime.conn, isNull);
    });
  });
  group('RealtimeLifecycleOptions.disconnectAfterPause', () {
    const delay = Duration(milliseconds: 100);

    setUp(
      () => initializeSupabase(
        realtimeLifecycleOptions: const RealtimeLifecycleOptions(
          disconnectAfterPause: delay,
        ),
      ),
    );

    test('a pause shorter than the delay keeps the socket', () async {
      final realtime = Supabase.instance.client.realtime;
      realtime.channel('test');
      await connectAndReady(realtime);

      pause();
      await Future<void>.delayed(delay ~/ 2);
      resume();
      await settleLifecycle();

      expect(realtime.connState, SocketStates.open);
      expect(readyCompleters, hasLength(1), reason: 'no reconnect happened');
    });

    test('a pause longer than the delay disconnects, and resume '
        'reconnects', () async {
      final realtime = Supabase.instance.client.realtime;
      realtime.channel('test');
      await connectAndReady(realtime);

      pause();
      await pumpEventQueue();
      expect(realtime.connState, SocketStates.open);

      await Future<void>.delayed(delay * 2);
      await pumpEventQueue();
      expect(realtime.connState, SocketStates.disconnected);

      resume();
      await settleLifecycle();

      expect(realtime.connState, SocketStates.open);
      expect(readyCompleters, hasLength(2));
    });

    test('detached during the delay disconnects right away', () async {
      final realtime = Supabase.instance.client.realtime;
      realtime.channel('test');
      await connectAndReady(realtime);

      pause();
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.detached,
      );
      await pumpEventQueue();

      expect(realtime.connState, SocketStates.disconnected);
    });

    test('dispose during the delay cancels the pending disconnect', () async {
      final realtime = Supabase.instance.client.realtime;
      realtime.channel('test');
      await connectAndReady(realtime);

      final timers = <Timer>[];
      runZoned(
        pause,
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createTimer(zone, duration, callback);
            timers.add(timer);
            return timer;
          },
        ),
      );
      expect(timers.where((timer) => timer.isActive), hasLength(1));

      await Supabase.instance.dispose();

      expect(timers.where((timer) => timer.isActive), isEmpty);
    });
  });

  group('RealtimeLifecycleOptions.manual', () {
    setUp(
      () => initializeSupabase(
        realtimeLifecycleOptions: const RealtimeLifecycleOptions.manual(),
      ),
    );

    test('pausing leaves the socket open', () async {
      final realtime = Supabase.instance.client.realtime;
      realtime.channel('test');
      await connectAndReady(realtime);

      pause();
      await pumpEventQueue();

      expect(realtime.connState, SocketStates.open);
    });

    test('resuming does not reconnect a socket the app closed', () async {
      final realtime = Supabase.instance.client.realtime;
      realtime.channel('test');
      await connectAndReady(realtime);
      await realtime.disconnect();

      pause();
      resume();
      await settleLifecycle();

      expect(realtime.connState, SocketStates.disconnected);
      expect(readyCompleters, hasLength(1));
    });
  });
}
