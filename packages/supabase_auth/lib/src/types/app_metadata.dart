import 'package:collection/collection.dart';

/// Metadata the auth server or an admin controls; the signed-in user cannot
/// modify it.
///
/// The server writes [providers] and [provider]. Any other key, such as a
/// claim added by an admin update or an auth hook, is read through
/// [operator []].
class AppMetadata {
  const AppMetadata({
    this.provider,
    this.providers = const [],
    Map<String, dynamic> additionalProperties = const {},
  }) : _additionalProperties = additionalProperties;

  /// Parses the `app_metadata` object of a user, keeping every key the server
  /// sent so [toJson] round-trips.
  factory AppMetadata.fromJson(Map<String, dynamic> json) {
    final additionalProperties = Map<String, dynamic>.of(json)
      ..remove('provider')
      ..remove('providers');
    return AppMetadata(
      provider: json['provider'] as String?,
      providers: List<String>.unmodifiable(
        (json['providers'] as List<dynamic>?)?.cast<String>() ?? const [],
      ),
      additionalProperties: Map.unmodifiable(additionalProperties),
    );
  }

  /// The provider the user first signed up with.
  ///
  /// Prefer [providers], which lists every provider linked to the user.
  final String? provider;

  /// Every provider the user has an identity for, such as `email` or
  /// `google`.
  final List<String> providers;

  final Map<String, dynamic> _additionalProperties;

  /// Reads any key of the metadata object, including the ones the typed
  /// fields expose.
  dynamic operator [](String key) => switch (key) {
    'provider' => provider,
    'providers' => providers,
    _ => _additionalProperties[key],
  };

  /// Converts this to a JSON-encodable map with every key the server sent.
  ///
  /// [providers] is always emitted, matching the server, while [provider] is
  /// omitted when null.
  Map<String, dynamic> toJson() {
    return {
      'provider': ?provider,
      'providers': providers,
      ..._additionalProperties,
    };
  }

  @override
  String toString() => 'AppMetadata(${toJson()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final collectionEquals = const DeepCollectionEquality().equals;

    return other is AppMetadata &&
        other.provider == provider &&
        collectionEquals(other.providers, providers) &&
        collectionEquals(other._additionalProperties, _additionalProperties);
  }

  @override
  int get hashCode {
    final collectionHash = const DeepCollectionEquality().hash;

    return provider.hashCode ^
        collectionHash(providers) ^
        collectionHash(_additionalProperties);
  }
}
