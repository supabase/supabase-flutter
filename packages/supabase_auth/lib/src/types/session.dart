import 'package:supabase_auth/src/constants.dart';
import 'package:supabase_auth/src/helper.dart';
import 'package:supabase_auth/src/types/user.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

class Session {
  final String? providerToken;
  final String? providerRefreshToken;
  final String accessToken;

  /// The number of seconds until the token expires (since it was issued).
  /// Returned when a login is confirmed.
  final int? expiresIn;

  final String? refreshToken;
  final String tokenType;
  final User user;

  Session({
    required this.accessToken,
    this.expiresIn,
    this.refreshToken,
    required this.tokenType,
    this.providerToken,
    this.providerRefreshToken,
    required this.user,
  });

  /// Returns a `Session` object from a map of json
  /// returns `null` if there is no `access_token` present
  static Session? fromJson(Map<String, dynamic> json) {
    if (json['access_token'] == null) {
      return null;
    }
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw FormatException(
        'Expected user to be an object, got ${userJson.runtimeType}',
      );
    }
    final user = User.fromJson(userJson);
    if (user == null) {
      throw FormatException(
        'Failed to parse user: missing required id field',
      );
    }
    return Session(
      accessToken: json['access_token'] as String,
      expiresIn: (json['expires_in'] as num?)?.toInt(),
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String,
      providerToken: json['provider_token'] as String?,
      providerRefreshToken: json['provider_refresh_token'] as String?,
      user: user,
    );
  }

  Map<String, dynamic> toJson() {
    final expiresAt = this.expiresAt;
    return {
      'access_token': accessToken,
      'expires_in': expiresIn,
      'expires_at': expiresAt == null
          ? null
          : unixSecondsFromDateTime(expiresAt),
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'provider_token': providerToken,
      'provider_refresh_token': providerRefreshToken,
      'user': user.toJson(),
    };
  }

  /// The point in time, in UTC, when [accessToken] expires.
  ///
  /// Derived from the `exp` claim of [accessToken], not read from the login
  /// response's JSON body. `null` when [accessToken] carries no expiry or
  /// cannot be decoded.
  late DateTime? expiresAt = _expiresAt;

  DateTime? get _expiresAt {
    try {
      final expiresAtSeconds = decodeJwtPayload(accessToken).expiresAt;
      return expiresAtSeconds == null
          ? null
          : dateTimeFromUnixSeconds(expiresAtSeconds);
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` if the token is expired or will expire in the next 30
  /// seconds.
  ///
  /// The 30 second buffer is to account for latency issues.
  bool get isExpired {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().add(Constants.expiryMargin).isAfter(expiresAt);
  }

  /// Returns `true` if the token is expired right now, without applying the
  /// [Constants.expiryMargin] buffer used by [isExpired].
  @internal
  bool get isExpiredWithoutMargin {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt);
  }

  Session copyWith({
    String? accessToken,
    int? expiresIn,
    String? refreshToken,
    String? tokenType,
    String? providerToken,
    String? providerRefreshToken,
    User? user,
  }) {
    return Session(
      accessToken: accessToken ?? this.accessToken,
      expiresIn: expiresIn ?? this.expiresIn,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      providerToken: providerToken ?? this.providerToken,
      providerRefreshToken: providerRefreshToken ?? this.providerRefreshToken,
      user: user ?? this.user,
    );
  }

  @override
  String toString() {
    return 'Session(providerToken: $providerToken, providerRefreshToken: '
        '$providerRefreshToken, expiresIn: $expiresIn, tokenType: $tokenType, '
        'user: $user, accessToken: $accessToken, refreshToken: $refreshToken)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Session &&
        other.providerToken == providerToken &&
        other.providerRefreshToken == providerRefreshToken &&
        other.accessToken == accessToken &&
        other.expiresIn == expiresIn &&
        other.refreshToken == refreshToken &&
        other.tokenType == tokenType &&
        other.user == user;
  }

  @override
  int get hashCode {
    return providerToken.hashCode ^
        providerRefreshToken.hashCode ^
        accessToken.hashCode ^
        expiresIn.hashCode ^
        refreshToken.hashCode ^
        tokenType.hashCode ^
        user.hashCode;
  }
}
