// Platform detection primitives.
//
// On `dart:io` platforms these resolve to the real operating system, platform
// version and Dart runtime version. On web they resolve to `null`.
export 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';
