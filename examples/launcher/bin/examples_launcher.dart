import 'dart:io';

import 'package:examples_launcher/launcher.dart' as launcher;

Future<void> main(List<String> args) async {
  exitCode = await launcher.run(args);
}
