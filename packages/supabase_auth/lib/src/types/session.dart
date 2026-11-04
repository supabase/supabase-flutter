import 'package:clock/clock.dart';
import 'package:supabase_auth/src/auth_constants.dart';
import 'package:supabase_auth/src/helper.dart';
import 'package:supabase_auth/src/types/auth_exception.dart';
import 'package:supabase_auth/src/types/user.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

/// A signed-in user's authentication tokens.
class Session {
  Session({
    required this.accessToken,
    this.expiresIn,
    this.refreshToken,
    required this.tokenType,
    this.providerToken,
    this.providerRefreshToken,
    required this.user,
    this.receivedAt,
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

  /// When this device received the session, on the device's clock.
  ///
  /// Together with [expiresIn] it sets when [isExpired] considers the session
  /// expired, so a device clock that differs from the server's does not change
  /// it. When `null`, [isExpired] compares the device's clock with
  /// [expiresAt] instead.
  final DateTime? receivedAt;

  /// Returns a `Session` object from a map of json
  /// returns `null` if there is no `access_token` present
  ///
  /// [receivedAt] is used when [json] does not hold a `received_at` value,
  /// as in a response from the server.
  static Session? fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
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
      accessToken: json.field('access_token'),
      expiresIn: json.field<num?>('expires_in')?.toInt(),
      refreshToken: json.field('refresh_token'),
      tokenType: json.field('token_type'),
      providerToken: json.field('provider_token'),
      providerRefreshToken: json.field('provider_refresh_token'),
      user: user,
      receivedAt: tryParseUnixSeconds(json, 'received_at') ?? receivedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final expiresAt = this.expiresAt;
    final receivedAt = this.receivedAt;
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
      'received_at': receivedAt == null
          ? null
          : unixSecondsFromDateTime(receivedAt),
    };
  }

  /// The point in time, in UTC, when [accessToken] expires on the server's
  /// clock.
  ///
  /// Derived from the `exp` claim of [accessToken], not read from the login
  /// response's JSON body. `null` when [accessToken] carries no expiry or
  /// cannot be decoded. A device clock that differs from the server's makes
  /// it unsuitable for a comparison with the device's time, use [isExpired]
  /// for that.
  late final DateTime? expiresAt = _expiresAt;

  DateTime? get _expiresAt {
    try {
      final expiresAtSeconds = decodeJwtPayload(accessToken).expiresAt;
      return expiresAtSeconds == null
          ? null
          : dateTimeFromUnixSeconds(expiresAtSeconds);
    } on AuthInvalidJwtException {
      return null;
    }
  }

  /// When [accessToken] expires on the device's clock.
  ///
  /// This is [receivedAt] plus [expiresIn]. [expiresAt] moves it earlier when
  /// the two lie at most [AuthConstants.clockSkewTolerance] apart, which
  /// covers the time the response took to arrive. A larger difference comes
  /// from a device clock that differs from the server's, and is ignored.
  /// Without [receivedAt] or [expiresIn], this is [expiresAt].
  @internal
  late final DateTime? expiresAtOnDevice = _expiresAtOnDevice;

  DateTime? get _expiresAtOnDevice {
    final receivedAt = this.receivedAt;
    final expiresIn = this.expiresIn;
    final expiresAt = this.expiresAt;
    if (receivedAt == null || expiresIn == null) return expiresAt;
    final local = receivedAt.add(Duration(seconds: expiresIn));
    if (expiresAt != null &&
        expiresAt.isBefore(local) &&
        local.difference(expiresAt) <= AuthConstants.clockSkewTolerance) {
      return expiresAt;
    }
    return local;
  }

  /// Returns `true` if the token is expired or will expire in the next 30
  /// seconds.
  ///
  /// The 30 second buffer is to account for latency issues. The expiry is
  /// judged from [receivedAt] and [expiresIn] on the device's clock, so a
  /// device clock that differs from the server's does not make a new session
  /// look expired.
  bool get isExpired => _isExpiredWithin(AuthConstants.expiryMargin);

  /// Returns `true` if the token is expired right now, without applying the
  /// [AuthConstants.expiryMargin] buffer used by [isExpired].
  @internal
  bool get isExpiredWithoutMargin => _isExpiredWithin(Duration.zero);

  bool _isExpiredWithin(Duration margin) {
    final deadline = expiresAtOnDevice;
    if (deadline == null) return false;
    final now = clock.now();
    // A device clock set back after the session was received would stretch
    // the deadline by as much.
    final receivedAt = this.receivedAt;
    if (receivedAt != null && now.isBefore(receivedAt)) return true;
    return now.add(margin).isAfter(deadline);
  }

  Session copyWith({
    String? accessToken,
    int? expiresIn,
    String? refreshToken,
    String? tokenType,
    String? providerToken,
    String? providerRefreshToken,
    User? user,
    DateTime? receivedAt,
  }) {
    return Session(
      accessToken: accessToken ?? this.accessToken,
      expiresIn: expiresIn ?? this.expiresIn,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      providerToken: providerToken ?? this.providerToken,
      providerRefreshToken: providerRefreshToken ?? this.providerRefreshToken,
      user: user ?? this.user,
      receivedAt: receivedAt ?? this.receivedAt,
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
