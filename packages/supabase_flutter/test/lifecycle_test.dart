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
    late List<FakeWebSocketChannel> createdChannels;
    late List<Completer<void>> readyCompleters;

    setUp(() {
      mockAppLink();
      createdChannels = [];
      readyCompleters = [];
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (_) {}
    });

    Future<void> initWithMockTransport() async {
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
            final channel = FakeWebSocketChannel(readyCompleter: completer);
            createdChannels.add(channel);
            return channel;
          },
        ),
      );
    }

    /// Helper: call connect() and immediately complete the
    /// ready future created by the transport factory.
    Future<void> connectAndReady(RealtimeClient realtime) async {
      // ignore: invalid_use_of_internal_member
      final future = realtime.connect();
      // The transport factory just added a completer
      readyCompleters.last.complete();
      await future;
    }

    test(
        'paused then resumed waits for disconnect '
        'before reconnecting', () async {
      await initWithMockTransport();
      final realtime = Supabase.instance.client.realtime;

      // Add a channel so onResumed() processes reconnection
      realtime.channel('test');

      // Connect with ready completed immediately
      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → triggers disconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      // resumed → waits for disconnect, then reconnects
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      // Complete any pending ready futures (reconnect)
      for (final c in readyCompleters) {
        if (!c.isCompleted) c.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(realtime.connState, SocketStates.open);
    });

    test(
        'paused → resumed → inactive → resumed '
        'still reconnects', () async {
      await initWithMockTransport();
      final realtime = Supabase.instance.client.realtime;

      realtime.channel('test');

      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → starts disconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      // first resumed → queues reconnect after disconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      // inactive → does nothing (not a tracked lifecycle state)
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);

      // second resumed → queues another reconnect (idempotent)
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      // Complete all pending ready futures
      for (final c in readyCompleters) {
        if (!c.isCompleted) c.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should have reconnected, not stuck disconnecting
      expect(realtime.connState, isNot(SocketStates.disconnecting));
      expect(realtime.conn, isNotNull);
    });

    test(
        'rapid paused → resumed → paused → resumed '
        'ends up connected', () async {
      await initWithMockTransport();
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
      for (final c in readyCompleters) {
        if (!c.isCompleted) c.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Also complete any new ready futures created during processing
      for (final c in readyCompleters) {
        if (!c.isCompleted) c.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(realtime.connState, SocketStates.open);
    });

    test(
        'resumed then paused before connect completes '
        'cancels reconnect', () async {
      await initWithMockTransport();
      final realtime = Supabase.instance.client.realtime;

      realtime.channel('test');

      await connectAndReady(realtime);
      expect(realtime.connState, SocketStates.open);

      // paused → triggers disconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      // resumed → queues reconnect
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      // paused again before connect completes → should cancel the
      // reconnect (target state is now paused)
      Supabase.instance.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Complete all pending ready futures
      for (final c in readyCompleters) {
        if (!c.isCompleted) c.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Should be disconnected since the last event was paused
      expect(realtime.connState, SocketStates.disconnected);
    });
  });
}
