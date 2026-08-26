import 'package:supabase_auth/supabase_auth.dart';

/// Response which might or might not contain session and/or user
class AuthResponse {
  AuthResponse({
    this.session,
    User? user,
  }) : user = user ?? session?.user;

  /// Instantiates an `AuthResponse` object from json response.
  AuthResponse.fromJson(Map<String, dynamic> json)
    : session = Session.fromJson(json),
      user = User.fromJson(json) ?? Session.fromJson(json)?.user;

  /// The new session, `null` when the call did not create one, for example
  /// a sign-up that requires email confirmation first.
  final Session? session;

  /// The user, taken from [session] when not overridden.
  final User? user;
}

/// Response of OAuth signin
class OAuthResponse {
  /// Instantiates an `OAuthResponse` object from json response.
  const OAuthResponse({
    required this.provider,
    required this.url,
    this.flowId,
  });

  /// The provider the user was sent to.
  final OAuthProvider provider;

  /// The provider's authorization URL to send the user to.
  final Uri url;

  /// Identifier of the PKCE flow this call started.
  ///
  /// Pass it as the `flowId` of [AuthClient.exchangeCodeForSession] to
  /// exchange the auth code with this flow's code verifier when several flows
  /// are pending at the same time. `null` when the client is not using the PKCE
  /// flow.
  ///
  /// The id only selects a verifier held in storage, it never contains the
  /// verifier itself.
  final String? flowId;
}

/// Response that contains a user
class UserResponse {
  UserResponse.fromJson(Map<String, dynamic> json) : user = User.fromJson(json);

  /// The user.
  final User? user;
}

/// Response of [AuthAdminApi.listUsers], a page of users together with the
/// pagination metadata the server reports for it.
class ListUsersResponse {
  const ListUsersResponse({
    required this.users,
    this.total,
    this.nextPage,
    this.lastPage,
    this.audience,
  });

  /// The users on the requested page.
  final List<User> users;

  /// Total number of users across all pages, from the `X-Total-Count`
  /// response header.
  final int? total;

  /// The page to request next, or `null` when the requested page was the last
  /// one. Read from the `next` link of the `Link` response header.
  final int? nextPage;

  /// The number of the last page. Read from the `last` link of the `Link`
  /// response header.
  final int? lastPage;

  /// The audience the users belong to, from the `aud` field of the response
  /// body.
  final String? audience;
}

/// The response of `AuthClient.resend`.
class ResendResponse {
  const ResendResponse({
    this.messageId,
  });

  /// Only set for phone resend
  final String? messageId;
}

/// The response of `AuthClient.getSessionFromUrl`.
class AuthSessionUrlResponse {
  const AuthSessionUrlResponse({
    required this.session,
    required this.redirectType,
  });

  /// The session obtained from the URL.
  final Session session;

  /// The `type` query parameter of the URL, for example `'recovery'` or
  /// `'email_change'`, `null` when the URL did not carry one.
  final String? redirectType;
}

/// The response of `AuthAdminApi.generateLink`.
class GenerateLinkResponse {
  GenerateLinkResponse.fromJson(Map<String, dynamic> json)
    : properties = GenerateLinkProperties.fromJson(json),
      user = _parseUser(json);

  /// The generated link and its associated metadata.
  final GenerateLinkProperties properties;

  /// The user the link was generated for.
  final User user;

  static User _parseUser(Map<String, dynamic> json) {
    final user = User.fromJson(json);
    if (user == null) {
      throw FormatException(
        'Failed to parse user: missing required id field',
        json.toString(),
      );
    }
    return user;
  }
}

/// The generated link and its associated metadata, part of a
/// [GenerateLinkResponse].
class GenerateLinkProperties {
  GenerateLinkProperties.fromJson(Map<String, dynamic> json)
    : actionLink = json['action_link'] ?? '',
      emailOtp = json['email_otp'] ?? '',
      hashedToken = json['hashed_token'] ?? '',
      redirectTo = json['redirect_to'] ?? '',
      verificationType = GenerateLinkType.fromValue(
        json['verification_type'],
      );

  /// The email link to send to the user. The action_link follows the following
  /// format:
  /// auth/v1/verify?type={verification_type}&token={hashed_token}&redirect_to={redirect_to}
  final String actionLink;

  /// The raw email OTP. You should send this in the email if you want your
  /// users to verify using an OTP instead of the action link.
  final String emailOtp;

  /// The hashed token appended to the action link.
  final String hashedToken;

  /// The URL appended to the action link.
  final String redirectTo;

  /// The verification type that the email link is associated to.
  final GenerateLinkType verificationType;
}
