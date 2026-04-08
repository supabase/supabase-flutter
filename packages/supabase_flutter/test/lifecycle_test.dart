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

  group('Lifecycle realtime reconnection', () {
    late List<Completer<void>> readyCompleters;

    setUp(() async {
      mockAppLink();
      readyCompleters = [];
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockEmptyLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
        realtimeClientOptions: RealtimeClientOptions(
          transport: (url, headers) {
            final completer = Completer<void>();
            readyCompleters.add(completer);
            return FakeWebSocketChannel(readyCompleter: completer);
          },
        ),
      );
    });

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
        for (final c in readyCompleters) {
          if (!c.isCompleted) c.complete();
        }
        await pumpEventQueue();
      }
    }

    test(
        'paused then resumed waits for disconnect '
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

    test(
        'paused → resumed → inactive → resumed '
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

    test(
        'rapid paused → resumed → paused → resumed '
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

    test(
        'resumed then paused before connect completes '
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
}
