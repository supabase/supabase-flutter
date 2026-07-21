import 'dart:io';

const examples = ['database_crud', 'passkeys'];

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: run_example_integration_tests.dart <target>');
    exit(64);
  }
  final target = arguments.single;

  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final publishableKey = Platform.environment['SUPABASE_PUBLISHABLE_KEY'];
  if (supabaseUrl == null || publishableKey == null) {
    stderr.writeln(
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be set in the environment.',
    );
    exit(78);
  }

  final defines = [
    '--dart-define=SUPABASE_URL=$supabaseUrl',
    '--dart-define=SUPABASE_PUBLISHABLE_KEY=$publishableKey',
  ];

  Process? chromedriver;
  if (target == 'web') {
    chromedriver = await Process.start('chromedriver', [
      '--port=4444',
    ], mode: ProcessStartMode.inheritStdio);
  }

  try {
    for (final example in examples) {
      print('::group::$example ($target)');
      await _runTarget(target, 'examples/$example', defines);
      print('::endgroup::');
    }
  } finally {
    chromedriver?.kill();
  }
}

Future<void> _runTarget(
  String target,
  String directory,
  List<String> defines,
) async {
  switch (target) {
    case 'web':
      final driver = File('$directory/test_driver/integration_test.dart');
      await driver.parent.create(recursive: true);
      await driver.writeAsString(
        "import 'package:integration_test/integration_test_driver.dart';\n\n"
        'Future<void> main() => integrationDriver();\n',
      );
      final testFiles =
          Directory('$directory/integration_test')
              .listSync()
              .whereType<File>()
              .map((file) => file.uri.pathSegments.last)
              .where((name) => name.endsWith('_test.dart'))
              .toList()
            ..sort();
      for (final testFile in testFiles) {
        await _flutter(directory, [
          'drive',
          '--driver=test_driver/integration_test.dart',
          '--target=integration_test/$testFile',
          '-d',
          'web-server',
          '--browser-name=chrome',
          '--headless',
          ...defines,
        ]);
      }
    case 'linux':
      await _run(directory, 'xvfb-run', [
        '-a',
        'flutter',
        'test',
        'integration_test',
        '-d',
        'linux',
        ...defines,
      ]);
    case 'macos':
      await _flutter(directory, [
        'test',
        'integration_test',
        '-d',
        'macos',
        ...defines,
      ]);
    case 'windows':
      await _flutter(directory, [
        'test',
        'integration_test',
        '-d',
        'windows',
        ...defines,
      ]);
    case 'android':
      await _flutter(directory, ['test', 'integration_test', ...defines]);
    case 'ios':
      final device = Platform.environment['IOS_DEVICE'];
      if (device == null) {
        stderr.writeln('IOS_DEVICE must be set for the ios target.');
        exit(78);
      }
      await _flutter(directory, [
        'test',
        'integration_test',
        '-d',
        device,
        ...defines,
      ]);
    default:
      stderr.writeln('Unknown target: $target');
      exit(64);
  }
}

Future<void> _flutter(String directory, List<String> arguments) =>
    _run(directory, 'flutter', arguments);

Future<void> _run(
  String directory,
  String executable,
  List<String> arguments,
) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: directory,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln('$executable ${arguments.join(' ')} failed ($exitCode).');
    exit(exitCode);
  }
}
