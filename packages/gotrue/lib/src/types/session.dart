import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/user.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:logging/logging.dart';

class Session {
  static final _log = Logger('supabase.auth.session');

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
    return Session(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int?,
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String,
      providerToken: json['provider_token'] as String?,
      providerRefreshToken: json['provider_refresh_token'] as String?,
      user: User.fromJson(json['user'] as Map<String, dynamic>)!,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'expires_in': expiresIn,
      'expires_at': expiresAt,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'provider_token': providerToken,
      'provider_refresh_token': providerRefreshToken,
      'user': user.toJson(),
    };
  }

  /// A timestamp of when the token will expire. Returned when a login is
  /// confirmed.
  late int? expiresAt = _expiresAt;

  int? get _expiresAt {
    try {
      final payload = Jwt.parseJwt(accessToken);
      final exp = payload['exp'] as int;
      _log.finest('Parsed expiresAt from JWT: $exp');
      return exp;
    } catch (error) {
      _log.warning('Failed to parse expiresAt from JWT: $error');
      return null;
    }
  }

  /// Returns 'true` if the token is expired or will expire in the next 30 seconds.
  ///
  /// The 30 second buffer is to account for latency issues.
  bool get isExpired {
    if (expiresAt == null) {
      _log.finest('Session.isExpired: false (no expiresAt)');
      return false;
    }
    final now = DateTime.now();
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt! * 1000);
    final timeWithMargin = now.add(Constants.expiryMargin);
    final expired = timeWithMargin.isAfter(expiryTime);
    final secondsUntilExpiry = expiryTime.difference(now).inSeconds;

    _log.finest(
        'Session.isExpired: $expired (secondsUntilExpiry=$secondsUntilExpiry, expiryMargin=${Constants.expiryMargin.inSeconds}s, expiresAt=${expiryTime.toIso8601String()})');

    return expired;
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
    return 'Session(providerToken: $providerToken, providerRefreshToken: $providerRefreshToken, expiresIn: $expiresIn, tokenType: $tokenType, user: $user, accessToken: $accessToken, refreshToken: $refreshToken)';
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
