import 'dart:convert';

import 'package:gotrue/src/types/user.dart';
import 'package:jwt_decode/jwt_decode.dart';

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

  const Session({
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
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'provider_token': providerToken,
      'provider_refresh_token': providerRefreshToken,
      'user': user.toJson(),
    };
  }

  /// A timestamp of when the token will expire. Returned when a login is
  /// confirmed.
  int? get expiresAt {
    try {
      final payload = Jwt.parseJwt(accessToken);
      return payload['exp'] as int;
    } catch (_) {
      return null;
    }
  }

  String get persistSessionString {
    final data = {'currentSession': toJson(), 'expiresAt': expiresAt};
    return json.encode(data);
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
}
