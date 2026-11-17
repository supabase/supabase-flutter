import 'dart:io';

import '../client_info.dart';

/// The normalized operating system name, for example `'Android'` or `'iOS'`.
String get conditionalPlatform =>
    normalizePlatformName(Platform.operatingSystem);

/// The operating system version.
String get conditionalPlatformVersion => Platform.operatingSystemVersion;

/// The processor architecture, using Go's `GOARCH` names such as `'arm64'` or
/// `'amd64'`, or `null` for an architecture Go has no name for.
String? get conditionalPlatformArchitecture =>
    switch (_abiPattern.firstMatch(Platform.version)?.group(1)) {
      'x64' => 'amd64',
      'ia32' => '386',
      'arm' => 'arm',
      'arm64' => 'arm64',
      'riscv64' => 'riscv64',
      _ => null,
    };

final _abiPattern = RegExp(r'on "[a-z]+_([a-z0-9]+)"$');

/// The Dart runtime version.
String get conditionalRuntimeVersion => Platform.version.split(' ').first;

/// Whether the current process is running under `flutter test`.
bool get isRunningInFlutterTest =>
    Platform.environment.containsKey('FLUTTER_TEST');
