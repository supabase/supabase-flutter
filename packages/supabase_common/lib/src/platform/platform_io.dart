import 'dart:io';

import '../client_info.dart';

String get conditionalPlatform =>
    normalizePlatformName(Platform.operatingSystem);

String get conditionalPlatformVersion => Platform.operatingSystemVersion;

String get conditionalRuntimeVersion => Platform.version.split(' ').first;

bool get isRunningInFlutterTest =>
    Platform.environment.containsKey('FLUTTER_TEST');
