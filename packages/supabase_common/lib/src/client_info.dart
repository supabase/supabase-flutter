import 'dart:convert';

import 'package:supabase_common/src/http_header.dart';
import 'package:supabase_common/src/platform/platform_info.dart';

/// The environment an SDK describes in the `X-Client-Info` header.
class PlatformInfo {
  const PlatformInfo({
    this.platform,
    this.platformVersion,
    this.platformArchitecture,
    this.runtimeVersion,
    this.framework,
    this.frameworkVersion,
  });

  /// The environment of the running process.
  static final current = PlatformInfo(
    platform: conditionalPlatform,
    platformVersion: conditionalPlatformVersion,
    platformArchitecture: conditionalPlatformArchitecture,
    runtimeVersion: conditionalRuntimeVersion,
    framework: _isFlutter ? 'flutter' : null,
    frameworkVersion: _isFlutter ? _flutterVersion : null,
  );

  static const _isFlutter = bool.fromEnvironment('dart.library.ui');

  static const _flutterVersion = bool.hasEnvironment('FLUTTER_VERSION')
      ? String.fromEnvironment('FLUTTER_VERSION')
      : null;

  /// The normalized platform name, for example `'Android'`, `'iOS'` or
  /// `'browser'`.
  final String? platform;

  /// The operating system version.
  final String? platformVersion;

  /// The processor architecture, using Go's `GOARCH` names such as `'arm64'`.
  final String? platformArchitecture;

  /// The Dart runtime version.
  final String? runtimeVersion;

  /// The application framework, `'flutter'` in a Flutter app.
  final String? framework;

  /// The version of [framework].
  final String? frameworkVersion;
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

/// Builds the value of the `X-Client-Info` header for the SDK [clientName] at
/// [version], describing the environment in [platformInfo], or
/// [PlatformInfo.current] when it is `null`.
///
/// Parameters whose value is unknown are left out. Values are trimmed, and
/// `;`, `%` and every character outside printable ASCII are percent-encoded.
String buildClientInfoHeader(
  String clientName,
  String version, {
  PlatformInfo? platformInfo,
}) {
  final info = platformInfo ?? PlatformInfo.current;
  final parameters = {
    'platform': info.platform,
    'platform-version': info.platformVersion,
    'platform-architecture': info.platformArchitecture,
    'runtime': 'dart',
    'runtime-version': info.runtimeVersion,
    'framework': info.framework,
    'framework-version': info.frameworkVersion,
  };
  return [
    '$clientName/$version',
    for (final MapEntry(:key, :value) in parameters.entries)
      if (_encodeParameterValue(value) case final encoded?) '$key=$encoded',
  ].join('; ');
}

String? _encodeParameterValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final buffer = StringBuffer();
  for (final byte in utf8.encode(trimmed)) {
    final isPrintable = byte >= 0x20 && byte <= 0x7E;
    if (isPrintable && byte != _semicolon && byte != _percent) {
      buffer.writeCharCode(byte);
    } else {
      final hex = byte.toRadixString(16).toUpperCase().padLeft(2, '0');
      buffer.write('%$hex');
    }
  }
  return buffer.toString();
}

const _semicolon = 0x3B;
const _percent = 0x25;

/// Returns a copy of [headers] whose `X-Client-Info` header also lists
/// [features] in its `features` parameter.
///
/// The header is matched case insensitively. When [headers] holds it under
/// several casings, the last one, which is the one a request sends, is kept
/// and the others are dropped. Features it already lists are kept. [headers]
/// is returned unchanged when it has no `X-Client-Info` header or [features]
/// is empty.
Map<String, String> withClientInfoFeatures(
  Map<String, String> headers,
  Set<String> features,
) {
  if (features.isEmpty) return headers;
  final lowerCaseName = HttpHeader.clientInfo.toLowerCase();
  bool isClientInfo(String name) => name.toLowerCase() == lowerCaseName;
  final key = headers.keys.where(isClientInfo).lastOrNull;
  if (key == null) return headers;
  final segments = <String>[];
  final merged = {...features};
  for (final segment in headers[key]!.split(';')) {
    final trimmed = segment.trim();
    final separator = trimmed.indexOf('=');
    final isFeatures =
        separator != -1 &&
        trimmed.substring(0, separator).trim().toLowerCase() == 'features';
    if (isFeatures) {
      merged.addAll(
        trimmed
            .substring(separator + 1)
            .split(',')
            .map((feature) => feature.trim())
            .where((feature) => feature.isNotEmpty),
      );
    } else if (trimmed.isNotEmpty) {
      segments.add(trimmed);
    }
  }
  return {
    for (final MapEntry(key: name, :value) in headers.entries)
      if (!isClientInfo(name)) name: value,
    key: [
      ...segments,
      'features=${(merged.toList()..sort()).join(',')}',
    ].join('; '),
  };
}
