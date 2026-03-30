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
  final FakeWebSocketSink fakeSink = FakeWebSocketSink();
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
  final Completer<void> _doneCompleter = Completer<void>();
  int? closeCode;
  String? closeReason;

  @override
  Future<void> close([int? code, String? reason]) async {
    closeCode = code;
    closeReason = reason;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
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

    // Helper: complete all pending ready futures to unblock connect()
    void completeReadyCompleters() async {
      for (final completer in readyCompleters) {
        if (!completer.isCompleted) completer.complete();
      }
      readyCompleters.clear();
    }

    test(
        'paused then resumed waits for disconnect '
        'before reconnecting', () async {
      final realtime = Supabase.instance.client.realtime;

      // Add a channel so onResumed() processes reconnection
      realtime.channel('test');

      // Connect with ready completed immediately
      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → triggers disconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();

      // resumed → waits for disconnect, then reconnects
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      // Complete any pending ready futures (reconnect)
      completeReadyCompleters();
      await Supabase.instance.pendingLifecycleOperation;

      expect(realtime.connState, SocketStates.open);
      expect(realtime.conn, isNotNull);
    });

    test(
        'paused → resumed → inactive → resumed '
        'still reconnects', () async {
      final realtime = Supabase.instance.client.realtime;

      realtime.channel('test');

      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → starts disconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();

      // first resumed → queues reconnect after disconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      // inactive → does nothing (not a tracked lifecycle state)
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await pumpEventQueue();

      // second resumed → queues another reconnect (idempotent)
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      // Complete all pending ready futures
      completeReadyCompleters();
      await Supabase.instance.pendingLifecycleOperation;

      // Should have reconnected, not stuck disconnecting
      expect(realtime.connState, SocketStates.open);
      expect(realtime.conn, isNotNull);
    });

    test(
        'rapid paused → resumed → paused → resumed '
        'ends up connected', () async {
      final realtime = Supabase.instance.client.realtime;

      realtime.channel('test');

      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // Rapid lifecycle flapping
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Complete all pending ready futures as they appear
      completeReadyCompleters();
      await Supabase.instance.pendingLifecycleOperation;

      expect(realtime.connState, SocketStates.open);
      expect(realtime.conn, isNotNull);
    });

    test(
        'resumed then paused before connect completes '
        'cancels reconnect', () async {
      final realtime = Supabase.instance.client.realtime;

      realtime.channel('test');

      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → triggers disconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();

      // resumed → queues reconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      // paused again before connect completes → should cancel the
      // reconnect (target state is now paused)
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Complete all pending ready futures
      completeReadyCompleters();
      await Supabase.instance.pendingLifecycleOperation;

      // Should be disconnected since the last event was paused
      expect(realtime.connState, SocketStates.disconnected);
      expect(realtime.conn, isNull);
    });
  });
}
