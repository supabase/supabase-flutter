import 'dart:io';

String get conditionalPlatform => Platform.operatingSystem;

String get conditionalPlatformVersion => Platform.operatingSystemVersion;

String get conditionalRuntimeVersion => Platform.version.split(' ').first;
