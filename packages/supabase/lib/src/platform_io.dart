import 'dart:io';

String? get condPlatform {
  return Platform.operatingSystem;
}

String? get condPlatformVersion {
  return Platform.operatingSystemVersion;
}
