// This file is invoked by the flutter/tests registry entry for supabase-flutter
// (https://github.com/flutter/tests/blob/main/registry/supabase_flutter.test) to run
// this repository's tests as a presubmit against flutter/flutter framework changes.
// Changes here are only honored after the commit hash in that registry entry is
// updated.

import 'dart:io';

Future<void> main() async {
  // supabase-flutter is a pub workspace, so analyzing the repository root covers
  // every member package.
  await _run('flutter', ['analyze', '--no-fatal-infos']);

  // Only supabase_flutter is exercised here. The other packages' tests require a
  // live Supabase backend and are therefore not hermetic enough for the registry.
  await _run('flutter', ['test'],
      workingDirectory: 'packages/supabase_flutter');
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    exit(exitCode);
  }
}
