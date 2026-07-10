/// Platform information used to build the richer, platform-aware form of the
/// `X-Client-Info` header.
class PlatformInfo {
  final String? platform;
  final String? platformVersion;
  final String? runtimeVersion;

  const PlatformInfo({
    this.platform,
    this.platformVersion,
    this.runtimeVersion,
  });
}

/// Builds the value of the `X-Client-Info` header.
///
/// When [platformInfo] is `null` the minimal `'$clientName/$version'` form is
/// returned. Otherwise a `; `-joined list is returned, appending `platform`,
/// `platform-version`, `runtime` and `runtime-version` segments for the
/// non-null fields.
String buildClientInfoHeader(
  String clientName,
  String version, {
  PlatformInfo? platformInfo,
}) {
  if (platformInfo == null) {
    return '$clientName/$version';
  }
  return [
    '$clientName/$version',
    if (platformInfo.platform != null) 'platform=${platformInfo.platform}',
    if (platformInfo.platformVersion != null)
      'platform-version=${Uri.encodeFull(platformInfo.platformVersion!).replaceAll("%20", " ")}',
    'runtime=dart',
    if (platformInfo.runtimeVersion != null)
      'runtime-version=${platformInfo.runtimeVersion}',
  ].join('; ');
}
