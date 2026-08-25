import 'package:supabase_auth/src/auth_constants.dart';
import 'package:supabase_auth/src/helper.dart';
import 'package:supabase_auth/src/types/user.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

/// A signed-in user's authentication tokens.
class Session {
  /// Creates a session.
  Session({
    required this.accessToken,
    this.expiresIn,
    this.refreshToken,
    required this.tokenType,
    this.providerToken,
    this.providerRefreshToken,
    required this.user,
  });

  /// The third-party provider's OAuth access token, `null` unless the user
  /// signed in through OAuth.
  final String? providerToken;

  /// The third-party provider's OAuth refresh token, `null` unless the user
  /// signed in through OAuth and the provider issued one.
  final String? providerRefreshToken;

  /// The JWT used to authenticate requests, valid until [expiresAt].
  final String accessToken;

  /// The number of seconds until the token expires (since it was issued).
  /// Returned when a login is confirmed.
  final int? expiresIn;

  /// The token used to obtain a new session once [accessToken] expires.
  final String? refreshToken;

  /// The type of [accessToken], typically `'bearer'`.
  final String tokenType;

  /// The signed-in user.
  final User user;

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

  /// Converts this to a JSON-encodable map.
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
  late final DateTime? expiresAt = _expiresAt;

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
    return DateTime.now().add(AuthConstants.expiryMargin).isAfter(expiresAt);
  }

  /// Returns `true` if the token is expired right now, without applying the
  /// [AuthConstants.expiryMargin] buffer used by [isExpired].
  @internal
  bool get isExpiredWithoutMargin {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt);
  }

  /// Returns a copy with the given fields replaced.
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

  /// The tokens are redacted so that a logged session never exposes them;
  /// use the fields directly when the actual values are needed.
  @override
  String toString() {
    return 'Session(providerToken: ${_redactToken(providerToken)}, '
        'providerRefreshToken: ${_redactToken(providerRefreshToken)}, '
        'expiresIn: $expiresIn, tokenType: $tokenType, user: $user, '
        'accessToken: ${_redactToken(accessToken)}, '
        'refreshToken: ${_redactToken(refreshToken)})';
  }

  static String _redactToken(String? token) =>
      token == null ? 'null' : '<redacted>';

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
