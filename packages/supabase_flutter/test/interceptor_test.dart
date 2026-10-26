// The interceptor seam is @experimental.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
import 'widget_test_stubs.dart';

class CountingInterceptor extends SupabaseClientInterceptor {
  SupabaseClient? attachedClient;
  final events = <String>[];
  int pauses = 0;
  int resumes = 0;
  int disposals = 0;
  bool failNextPause = false;
  bool failNextResume = false;
  Completer<void>? gate;
  int finishedResumes = 0;

  @override
  void attach(SupabaseClient client) {
    attachedClient = client;
  }

  @override
  Future<void> pause() async {
    pauses++;
    events.add('pause');
    if (failNextPause) {
      failNextPause = false;
      throw StateError('pause failed');
    }
  }

  @override
  Future<void> resume() async {
    resumes++;
    events.add('resume');
    if (failNextResume) {
      failNextResume = false;
      throw StateError('resume failed');
    }
    await gate?.future;
    finishedResumes++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingInterceptor interceptor;

  setUp(() async {
    mockSharedPreferences();
    mockAppLink();
    interceptor = CountingInterceptor();
    await Supabase.initialize(
      url: '',
      publishableKey: '',
      authOptions: FlutterAuthClientOptions(asyncStorage: MockAsyncStorage()),
      interceptors: [interceptor],
    );
  });

  tearDown(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {}
  });

  /// Sends the app to the background and brings it back.
  Future<void> cycleToResumed() async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
  }

  test('interceptors reach the client and are attached', () {
    expect(Supabase.instance.client.interceptors, [interceptor]);
    expect(interceptor.attachedClient, same(Supabase.instance.client));
  });

  test('resume runs on resumed even without realtime channels', () async {
    expect(Supabase.instance.client.realtime.channels, isEmpty);

    await cycleToResumed();

    expect(interceptor.resumes, 1);
  });

  test('pause runs when the app is hidden', () async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await pumpEventQueue();

    expect(interceptor.events, ['pause']);
  });

  test('pause and resume run in the order of the lifecycle events', () async {
    await cycleToResumed();
    await cycleToResumed();

    expect(interceptor.events, ['pause', 'resume', 'pause', 'resume']);
  });

  test('resume runs without a pause when the app was only inactive', () async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(interceptor.events, ['resume']);
  });

  test('a pause waits for a running resume', () async {
    final gate = Completer<void>();
    interceptor.gate = gate;
    await cycleToResumed();

    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await pumpEventQueue();

    expect(interceptor.events, ['pause', 'resume']);

    gate.complete();
    await pumpEventQueue();

    expect(interceptor.events, ['pause', 'resume', 'pause']);
  });

  test('a failing pause is logged and the resume still runs', () async {
    interceptor.failNextPause = true;

    await cycleToResumed();

    expect(interceptor.pauses, 1);
    expect(interceptor.resumes, 1);
  });

  test('a failing resume is logged and later resumes still run', () async {
    interceptor.failNextResume = true;

    await cycleToResumed();
    await cycleToResumed();

    expect(interceptor.resumes, 2);
  });

  test('resumes of one interceptor run one at a time', () async {
    final gate = Completer<void>();
    interceptor.gate = gate;

    await cycleToResumed();
    await cycleToResumed();

    expect(interceptor.resumes, 1);

    gate.complete();
    interceptor.gate = null;
    await pumpEventQueue();

    expect(interceptor.resumes, 2);
    expect(interceptor.finishedResumes, 2);
  });

  test('dispose waits for a running resume', () async {
    final gate = Completer<void>();
    interceptor.gate = gate;
    await cycleToResumed();

    var disposed = false;
    final disposing = Supabase.instance.dispose().then((_) => disposed = true);
    await pumpEventQueue();

    expect(disposed, isFalse);
    expect(interceptor.disposals, 0);

    gate.complete();
    await disposing;

    expect(interceptor.finishedResumes, 1);
    expect(interceptor.disposals, 1);
  });

  test('dispose runs the interceptor and stops lifecycle events', () async {
    await Supabase.instance.dispose();

    await cycleToResumed();

    expect(interceptor.disposals, 1);
    expect(interceptor.events, isEmpty);
  });
}
