// Platform detection primitives.
//
// On `dart:io` platforms these resolve to the real operating system, its
// version, the processor architecture and the Dart runtime version. On web the
// platform is `browser`.
export 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';
