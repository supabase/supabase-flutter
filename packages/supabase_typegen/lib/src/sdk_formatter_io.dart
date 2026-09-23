import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

/// Formats [code] with the `dart format` of the Dart SDK running this program,
/// for [languageVersion], so the result is exactly what that formatter leaves
/// unchanged in a project on that language version. With [path], the path the
/// code is written to, the formatter also applies the `formatter` settings of
/// the `analysis_options.yaml` that governs that path, such as its page
/// width.
///
/// Returns `null` when the formatter cannot be started or does not accept
/// [code].
Future<String?> formatWithSdk(
  String code,
  Version languageVersion, {
  String? path,
}) async {
  final Process process;
  try {
    process = await Process.start(Platform.resolvedExecutable, [
      'format',
      '--language-version=${languageVersion.major}.${languageVersion.minor}',
      if (path != null) '--stdin-name=$path',
    ]);
  } on ProcessException {
    return null;
  }
  final output = utf8.decodeStream(process.stdout);
  final errors = utf8.decodeStream(process.stderr);
  try {
    process.stdin.write(code);
    await process.stdin.close();
  } on IOException {
    // The formatter exited before reading everything; its exit code tells.
  }
  final exitCode = await process.exitCode;
  await errors;
  return exitCode == 0 ? await output : null;
}
