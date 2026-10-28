import 'package:supabase_common/src/http_header.dart';

/// Platform information used to build the richer, platform-aware form of the
/// `X-Client-Info` header.
class PlatformInfo {
  const PlatformInfo({
    this.platform,
    this.platformVersion,
    this.runtimeVersion,
  });

  /// The normalized platform name, for example `'Android'` or `'iOS'`.
  final String? platform;

  /// The operating system version.
  final String? platformVersion;

  /// The Dart or Flutter runtime version.
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

/// The SDK features a request can list in the `features` parameter of the
/// `X-Client-Info` header.
abstract final class ClientInfoFeature {
  /// The request was built with the typed API, `client.table(...)` or a typed
  /// function call on `client.rpc`.
  static const typedApi = 'typed-api';
}

/// Builds the value of the `X-Client-Info` header.
///
/// When [platformInfo] is `null` the minimal `'$clientName/$version'` form is
/// returned. Otherwise a `; `-joined list is returned, always including a
/// `runtime=dart` segment and appending `platform`, `platform-version` and
/// `runtime-version` segments for the non-null fields.
///
/// [features] are rendered as a final `features` segment, sorted and
/// comma-separated, and left out when empty.
String buildClientInfoHeader(
  String clientName,
  String version, {
  PlatformInfo? platformInfo,
  Set<String> features = const {},
}) {
  final rawPlatformVersion = platformInfo?.platformVersion;
  final platformVersion = rawPlatformVersion == null
      ? null
      : Uri.encodeFull(rawPlatformVersion).replaceAll('%20', ' ');
  return [
    '$clientName/$version',
    if (platformInfo != null) ...[
      if (platformInfo.platform != null) 'platform=${platformInfo.platform}',
      if (platformVersion != null) 'platform-version=$platformVersion',
      'runtime=dart',
      if (platformInfo.runtimeVersion != null)
        'runtime-version=${platformInfo.runtimeVersion}',
    ],
    if (features.isNotEmpty) _featuresSegment(features),
  ].join('; ');
}

/// Returns a copy of [headers] whose `X-Client-Info` header also lists
/// [features] in its `features` parameter.
///
/// The header is matched case insensitively, and features it already lists
/// are kept. [headers] is returned unchanged when it has no `X-Client-Info`
/// header or [features] is empty.
Map<String, String> withClientInfoFeatures(
  Map<String, String> headers,
  Set<String> features,
) {
  if (features.isEmpty) return headers;
  final lowerCaseName = HttpHeader.clientInfo.toLowerCase();
  final key = headers.keys
      .where((name) => name.toLowerCase() == lowerCaseName)
      .firstOrNull;
  if (key == null) return headers;
  final segments = <String>[];
  final merged = {...features};
  for (final segment in headers[key]!.split(';')) {
    final trimmed = segment.trim();
    if (trimmed.startsWith('features=')) {
      merged.addAll(
        trimmed
            .substring('features='.length)
            .split(',')
            .map((feature) => feature.trim())
            .where((feature) => feature.isNotEmpty),
      );
    } else if (trimmed.isNotEmpty) {
      segments.add(trimmed);
    }
  }
  return {
    ...headers,
    key: [...segments, _featuresSegment(merged)].join('; '),
  };
}

String _featuresSegment(Set<String> features) =>
    'features=${(features.toList()..sort()).join(',')}';
