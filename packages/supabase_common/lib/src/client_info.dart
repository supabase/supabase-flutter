/// Platform information used to build the richer, platform-aware form of the
/// `X-Client-Info` header.
class PlatformInfo {
  const PlatformInfo({
    this.platform,
    this.platformVersion,
    this.runtimeVersion,
  });
  final String? platform;
  final String? platformVersion;
  final String? runtimeVersion;
}

/// Platform names shared across the Supabase SDKs so per-platform stats can be
/// aggregated regardless of language or framework. The casing matches the
/// Swift SDK.
const _platformNames = {
  'android': 'Android',
  'ios': 'iOS',
  'linux': 'Linux',
  'macos': 'macOS',
  'windows': 'Windows',
  'fuchsia': 'Fuchsia',
};

/// Normalizes a `dart:io` `Platform.operatingSystem` value to the platform name
/// shared across the Supabase SDKs. Unknown values are returned unchanged so
/// they stay visible in stats.
String normalizePlatformName(String operatingSystem) =>
    _platformNames[operatingSystem] ?? operatingSystem;

/// Builds the value of the `X-Client-Info` header.
///
/// When [platformInfo] is `null` the minimal `'$clientName/$version'` form is
/// returned. Otherwise a `; `-joined list is returned, always including a
/// `runtime=dart` segment and appending `platform`, `platform-version` and
/// `runtime-version` segments for the non-null fields.
String buildClientInfoHeader(
  String clientName,
  String version, {
  PlatformInfo? platformInfo,
}) {
  if (platformInfo == null) {
    return '$clientName/$version';
  }
  final rawPlatformVersion = platformInfo.platformVersion;
  final platformVersion = rawPlatformVersion == null
      ? null
      : Uri.encodeFull(rawPlatformVersion).replaceAll('%20', ' ');
  return [
    '$clientName/$version',
    if (platformInfo.platform != null) 'platform=${platformInfo.platform}',
    if (platformVersion != null) 'platform-version=$platformVersion',
    'runtime=dart',
    if (platformInfo.runtimeVersion != null)
      'runtime-version=${platformInfo.runtimeVersion}',
  ].join('; ');
}
