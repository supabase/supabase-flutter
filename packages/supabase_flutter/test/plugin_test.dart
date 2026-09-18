// The plugin seam is @experimental.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
import 'widget_test_stubs.dart';

class CountingPlugin extends SupabaseClientPlugin {
  SupabaseClient? attachedClient;
  int resumes = 0;
  int disposals = 0;
  bool failNextResume = false;

  @override
  void attach(SupabaseClient client) {
    attachedClient = client;
  }

  @override
  Future<void> resume() async {
    resumes++;
    if (failNextResume) {
      failNextResume = false;
      throw StateError('resume failed');
    }
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingPlugin plugin;

  setUp(() async {
    mockSharedPreferences();
    mockAppLink();
    plugin = CountingPlugin();
    await Supabase.initialize(
      url: '',
      publishableKey: '',
      authOptions: FlutterAuthClientOptions(asyncStorage: MockAsyncStorage()),
      plugins: [plugin],
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

  test('plugins reach the client and are attached', () {
    expect(Supabase.instance.client.plugins, [plugin]);
    expect(plugin.attachedClient, same(Supabase.instance.client));
  });

  test('resume runs on resumed even without realtime channels', () async {
    expect(Supabase.instance.client.realtime.channels, isEmpty);

    await cycleToResumed();

    expect(plugin.resumes, 1);
  });

  test('a failing resume is logged and later resumes still run', () async {
    plugin.failNextResume = true;

    await cycleToResumed();
    await cycleToResumed();

    expect(plugin.resumes, 2);
  });

  test('dispose runs the plugin and stops resume events', () async {
    await Supabase.instance.dispose();

    await cycleToResumed();

    expect(plugin.disposals, 1);
    expect(plugin.resumes, 0);
  });
}
