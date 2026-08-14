import 'dart:io';

import 'package:examples_launcher/launcher.dart' as launcher;

Future<void> main(List<String> arguments) async {
  exitCode = await launcher.run(arguments);
}
