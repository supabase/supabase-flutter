import 'dart:io';

String? get condPlatform => Platform.operatingSystem;

String? get condPlatformVersion => Platform.operatingSystemVersion;

String? get condRuntimeVersion => Platform.version.split(' ').first;
