import 'dart:io';

import '../client_info.dart';

/// The normalized operating system name, for example `'Android'` or `'iOS'`.
String get conditionalPlatform =>
    normalizePlatformName(Platform.operatingSystem);

/// The operating system version.
String get conditionalPlatformVersion => Platform.operatingSystemVersion;

/// The Dart runtime version.
String get conditionalRuntimeVersion => Platform.version.split(' ').first;

/// Whether the current process is running under `flutter test`.
bool get isRunningInFlutterTest =>
    Platform.environment.containsKey('FLUTTER_TEST');
