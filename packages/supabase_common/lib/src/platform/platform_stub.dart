/// The normalized operating system name. Always `null` on web.
String? get conditionalPlatform => null;

/// The operating system version. Always `null` on web.
String? get conditionalPlatformVersion => null;

/// The Dart runtime version. Always `null` on web.
String? get conditionalRuntimeVersion => null;

/// Whether the current process is running under `flutter test`. Always
/// `false` on web.
bool get isRunningInFlutterTest => false;
