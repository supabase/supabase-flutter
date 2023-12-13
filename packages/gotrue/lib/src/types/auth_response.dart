import 'package:gotrue/gotrue.dart';
import 'package:gotrue/src/constants.dart';

/// Response which might or might not contain session and/or user
class AuthResponse {
  final Session? session;
  final User? user;

  AuthResponse({
    this.session,
    User? user,
  }) : user = user ?? session?.user;

  /// Instanciates an `AuthResponse` object from json response.
  AuthResponse.fromJson(Map<String, dynamic> json)
      : session = Session.fromJson(json),
        user = User.fromJson(json) ?? Session.fromJson(json)?.user;
}

/// Response of OAuth signin
class OAuthResponse {
  final OAuthProvider provider;
  final String? url;

  /// Instanciates an `OAuthResponse` object from json response.
  const OAuthResponse({
    required this.provider,
    this.url,
  });
}

/// Response that contains a user
class UserResponse {
  final User? user;

  UserResponse.fromJson(Map<String, dynamic> json) : user = User.fromJson(json);
}

class ResendResponse {
  /// Only set for phone resend
  String? messageId;

  ResendResponse({
    this.messageId,
  });
}

class AuthSessionUrlResponse {
  final Session session;
  final String? redirectType;

  const AuthSessionUrlResponse({
    required this.session,
    required this.redirectType,
  });
}

class GenerateLinkResponse {
  final GenerateLinkProperties properties;
  final User user;

  GenerateLinkResponse.fromJson(Map<String, dynamic> json)
      : properties = GenerateLinkProperties.fromJson(json),
        user = User.fromJson(json)!;
}

class GenerateLinkProperties {
  /// The email link to send to the user.
  /// The action_link follows the following format: auth/v1/verify?type={verification_type}&token={hashed_token}&redirect_to={redirect_to}
  final String actionLink;

  /// The raw email OTP.
  /// You should send this in the email if you want your users to verify using an OTP instead of the action link.
  final String emailOtp;

  /// The hashed token appended to the action link.
  final String hashedToken;

  /// The URL appended to the action link.
  final String redirectTo;

  /// The verification type that the email link is associated to.
  final GenerateLinkType verificationType;

  GenerateLinkProperties.fromJson(Map<String, dynamic> json)
      : actionLink = json['action_link'] ?? '',
        emailOtp = json['email_otp'] ?? '',
        hashedToken = json['hashed_token'] ?? '',
        redirectTo = json['redirect_to'] ?? '',
        verificationType =
            GenerateLinkTypeExtended.fromString(json['verification_type']);
}

extension ToSnakeCase on Enum {
  String get snakeCase {
    final a = 'a'.codeUnitAt(0), z = 'z'.codeUnitAt(0);
    final A = 'A'.codeUnitAt(0), Z = 'Z'.codeUnitAt(0);
    final result = StringBuffer()..write(name[0].toLowerCase());
    for (var i = 1; i < name.length; i++) {
      final char = name.codeUnitAt(i);
      if (A <= char && char <= Z) {
        final pChar = name.codeUnitAt(i - 1);
        if (a <= pChar && pChar <= z) {
          result.write('_');
        }
      }
      result.write(name[i].toLowerCase());
    }
    return result.toString();
  }
}
