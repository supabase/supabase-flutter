import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

const _ok = 0;
const _failure = 1;

const _noTerminalMessage =
    'The launcher needs an interactive terminal to pick an example. '
    'Run it directly in your terminal.';

final _logger = Logger();

/// A runnable example: a directory with a `pubspec.yaml` and a `lib/main.dart`.
class Example {
  const Example(this.name, this.directory);

  final String name;
  final Directory directory;
}

/// Boots the local Supabase stack, asks which example to run and runs it.
///
/// Any [args] are forwarded to `flutter run`, replacing the default
/// `-d chrome`, so `dart run -- -d macos` runs the chosen example on macOS.
Future<int> run(List<String> args) async {
  _printBanner();

  final root = _findExamplesRoot();
  if (root == null) {
    _logger.err(
      'Could not find the examples directory. Run this from inside the '
      'supabase-flutter "examples" folder.',
    );
    return _failure;
  }

  if (!stdin.hasTerminal) {
    _logger.err(_noTerminalMessage);
    return _failure;
  }

  for (final command in const ['supabase', 'flutter']) {
    if (!await _hasCommand(command)) {
      _logger.err('Required command "$command" was not found on your PATH.');
      return _failure;
    }
  }

  // Only stop Supabase on exit if the launcher is the one that started it.
  var env = await _supabaseStatus(root);
  var startedByLauncher = false;
  if (env.isEmpty) {
    if (!await _startSupabase(root)) {
      return _failure;
    }
    startedByLauncher = true;
    env = await _supabaseStatus(root);
  } else {
    _logger.info('Using the Supabase stack that is already running.');
  }

  try {
    final url = env['API_URL'];
    final key = env['PUBLISHABLE_KEY'] ?? env['ANON_KEY'];
    if (url == null || key == null) {
      _logger.err('Could not read the local Supabase credentials.');
      return _failure;
    }

    final examples = _discoverExamples(root);
    if (examples.isEmpty) {
      _logger.err('No runnable examples found in ${root.path}.');
      return _failure;
    }

    final Example selected;
    try {
      selected = _logger.chooseOne<Example>(
        'Which example do you want to run?',
        choices: examples,
        display: (example) => example.name,
      );
    } on StdinException {
      _logger.err(_noTerminalMessage);
      return _failure;
    }

    _logger
      ..info('')
      ..info(
        '${styleBold.wrap('Running')} ${cyan.wrap(selected.name)} '
        'against ${cyan.wrap(url)}',
      );

    // Serve on a fixed origin so it matches the WebAuthn rp_origins configured
    // in supabase/config.toml, which the passkeys example relies on.
    final flutterArgs = args.isNotEmpty
        ? args
        : const [
            '-d',
            'chrome',
            '--web-hostname',
            'localhost',
            '--web-port',
            '3000',
          ];
    final process = await Process.start(
      'flutter',
      [
        'run',
        ...flutterArgs,
        '--dart-define=SUPABASE_URL=$url',
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=$key',
      ],
      workingDirectory: selected.directory.path,
      mode: ProcessStartMode.inheritStdio,
    );

    // Forward Ctrl-C to flutter so it shuts down and control returns here,
    // letting the cleanup below stop Supabase, rather than killing the launcher.
    final sigint = ProcessSignal.sigint.watch().listen(
      (_) => process.kill(ProcessSignal.sigint),
    );
    final code = await process.exitCode;
    await sigint.cancel();
    return code;
  } finally {
    if (startedByLauncher) {
      await _stopSupabase(root);
    }
  }
}

void _printBanner() {
  _logger
    ..info('')
    ..info(lightCyan.wrap(styleBold.wrap('  Supabase Flutter examples')))
    ..info(styleDim.wrap('  Local Supabase + example launcher'))
    ..info('');
}

/// Walks up from the current directory until it finds the examples directory,
/// recognised by its shared `supabase/config.toml`.
Directory? _findExamplesRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    if (File('${directory.path}/supabase/config.toml').existsSync()) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) return null;
    directory = parent;
  }
}

Future<bool> _hasCommand(String command) async {
  try {
    final result = await Process.run(Platform.isWindows ? 'where' : 'which', [
      command,
    ]);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<bool> _startSupabase(Directory root) async {
  final progress = _logger.progress('Starting the local Supabase stack');
  final result = await Process.run('supabase', [
    'start',
    '--workdir',
    root.path,
  ]);
  if (result.exitCode == _ok) {
    progress.complete('Local Supabase is running');
    return true;
  }

  final output = '${result.stdout}${result.stderr}';
  if (output.contains('already running')) {
    progress.complete('Local Supabase is already running');
    return true;
  }

  progress.fail('Could not start Supabase');
  _logger.err(output.trim());
  return false;
}

Future<void> _stopSupabase(Directory root) async {
  final progress = _logger.progress('Stopping the local Supabase stack');
  final result = await Process.run('supabase', [
    'stop',
    '--workdir',
    root.path,
  ]);
  if (result.exitCode == _ok) {
    progress.complete('Stopped the local Supabase stack');
  } else {
    progress.fail('Could not stop Supabase');
    _logger.err('${result.stdout}${result.stderr}'.trim());
  }
}

Future<Map<String, String>> _supabaseStatus(Directory root) async {
  final result = await Process.run('supabase', [
    'status',
    '-o',
    'env',
    '--workdir',
    root.path,
  ]);
  if (result.exitCode != _ok) return {};
  return _parseEnv('${result.stdout}');
}

Map<String, String> _parseEnv(String output) {
  final env = <String, String>{};
  for (final line in const LineSplitter().convert(output)) {
    final index = line.indexOf('=');
    if (index <= 0) continue;
    final key = line.substring(0, index).trim();
    var value = line.substring(index + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    env[key] = value;
  }
  return env;
}

List<Example> _discoverExamples(Directory root) {
  final examples = <Example>[];
  for (final entity in root.listSync()) {
    if (entity is! Directory) continue;
    final hasPubspec = File('${entity.path}/pubspec.yaml').existsSync();
    final hasEntrypoint = File('${entity.path}/lib/main.dart').existsSync();
    if (hasPubspec && hasEntrypoint) {
      examples.add(Example(_basename(entity.path), entity));
    }
  }
  examples.sort((a, b) => a.name.compareTo(b.name));
  return examples;
}

String _basename(String path) =>
    path.split(Platform.pathSeparator).where((part) => part.isNotEmpty).last;
