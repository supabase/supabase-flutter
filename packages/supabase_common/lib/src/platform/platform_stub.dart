/// The platform name. Always `browser` on web.
String get conditionalPlatform => 'browser';

/// The operating system version. Always `null` on web.
String? get conditionalPlatformVersion => null;

/// The processor architecture. `wasm` when compiled to WebAssembly, otherwise
/// `null`.
String? get conditionalPlatformArchitecture =>
    const bool.fromEnvironment('dart.tool.dart2wasm') ? 'wasm' : null;

/// The Dart runtime version. Only known on web when the Flutter tool compiled
/// the app, otherwise `null`.
String? get conditionalRuntimeVersion {
  const dartVersion = String.fromEnvironment('FLUTTER_DART_VERSION');
  return dartVersion.isEmpty ? null : dartVersion.split(' ').first;
}

/// Whether the current process is running under `flutter test`. Always
/// `false` on web.
bool get isRunningInFlutterTest => false;
