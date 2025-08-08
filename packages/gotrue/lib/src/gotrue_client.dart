import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:gotrue/gotrue.dart';
import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/fetch.dart';
import 'package:gotrue/src/helper.dart';
import 'package:gotrue/src/types/auth_response.dart';
import 'package:gotrue/src/types/fetch_options.dart';
import 'package:http/http.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:retry/retry.dart';
import 'package:rxdart/subjects.dart';

import 'broadcast_stub.dart' if (dart.library.js_interop) './broadcast_web.dart'
    as web;
import 'version.dart';

part 'gotrue_mfa_api.dart';

/// {@template gotrue_client}
/// API client to interact with gotrue server.
///
/// [url] URL of gotrue instance
///
/// [autoRefreshToken] whether to refresh the token automatically or not. Defaults to true.
///
/// [httpClient] custom http client.
///
/// [asyncStorage] local storage to store pkce code verifiers. Required when using the pkce flow.
///
/// Set [flowType] to [AuthFlowType.implicit] to perform old implicit auth flow.
/// {@endtemplate}
class GoTrueClient {
  /// Namespace for the GoTrue API methods.
  /// These can be used for example to get a user from a JWT in a server environment or reset a user's password.
  late final GoTrueAdminApi admin;

  /// Namespace for the GoTrue MFA API methods.
  late final GoTrueMFAApi mfa;

  /// The session object for the currently logged in user or null.
  Session? _currentSession;

  final String _url;
  final Map<String, String> _headers;
  final Client? _httpClient;
  late final GotrueFetch _fetch = GotrueFetch(_httpClient);

  late bool _autoRefreshToken;

  Timer? _autoRefreshTicker;

  /// Completer to combine multiple simultaneous token refresh requests.
  Completer<AuthResponse>? _refreshTokenCompleter;

  final _onAuthStateChangeController = BehaviorSubject<AuthState>();
  final _onAuthStateChangeControllerSync =
      BehaviorSubject<AuthState>(sync: true);

  /// Local storage to store pkce code verifiers.
  final GotrueAsyncStorage? _asyncStorage;

  /// Receive a notification every time an auth event happens.
  ///
  /// ```dart
  /// supabase.auth.onAuthStateChange.listen((data) {
  ///   final AuthChangeEvent event = data.event;
  ///   final Session? session = data.session;
  ///   if(event == AuthChangeEvent.signedIn) {
  ///     // handle signIn event
  ///   }
  /// });
  /// ```
  Stream<AuthState> get onAuthStateChange =>
      _onAuthStateChangeController.stream;

  /// Don't use this, it's for internal use only.
  @internal
  Stream<AuthState> get onAuthStateChangeSync =>
      _onAuthStateChangeControllerSync.stream;

  final AuthFlowType _flowType;

  final _log = Logger('supabase.auth');

  /// Proxy to the web BroadcastChannel API. Should be null on non-web platforms.
  BroadcastChannel? _broadcastChannel;

  StreamSubscription? _broadcastChannelSubscription;

  /// {@macro gotrue_client}
  GoTrueClient({
    String? url,
    Map<String, String>? headers,
    bool? autoRefreshToken,
    Client? httpClient,
    GotrueAsyncStorage? asyncStorage,
    AuthFlowType flowType = AuthFlowType.pkce,
  })  : _url = url ?? Constants.defaultGotrueUrl,
        _headers = {
          ...Constants.defaultHeaders,
          ...?headers,
        },
        _httpClient = httpClient,
        _asyncStorage = asyncStorage,
        _flowType = flowType {
    _autoRefreshToken = autoRefreshToken ?? true;

    final gotrueUrl = url ?? Constants.defaultGotrueUrl;
    _log.config(
        'Initialize GoTrueClient v$version with url: $_url, autoRefreshToken: $_autoRefreshToken, flowType: $_flowType, tickDuration: ${Constants.autoRefreshTickDuration}, tickThreshold: ${Constants.autoRefreshTickThreshold}');
    _log.finest('Initialize with headers: $_headers');
    admin = GoTrueAdminApi(
      gotrueUrl,
      headers: _headers,
      httpClient: httpClient,
    );
    mfa = GoTrueMFAApi(
      client: this,
      fetch: _fetch,
    );
    if (_autoRefreshToken) {
      startAutoRefresh();
    }

    _mayStartBroadcastChannel();
  }

  /// Getter for the headers
  Map<String, String> get headers => _headers;

  /// Returns the current logged in user, asociated to [currentSession] if any;
  User? get currentUser => _currentSession?.user;

  /// Returns the current session, if any;
  Session? get currentSession => _currentSession;

  /// Creates a new anonymous user.
  ///
  /// Returns An `AuthResponse` with a session where the `is_anonymous` claim
  /// in the access token JWT is set to true
  Future<AuthResponse> signInAnonymously({
    Map<String, dynamic>? data,
    String? captchaToken,
  }) async {
    final response = await _fetch.request(
      '$_url/signup',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
        body: {
          'data': data ?? {},
          'gotrue_meta_security': {'captcha_token': captchaToken},
        },
      ),
    );

    final authResponse = AuthResponse.fromJson(response);

    final session = authResponse.session;
    if (session != null) {
      _saveSession(session);
      notifyAllSubscribers(AuthChangeEvent.signedIn);
    }

    return authResponse;
  }

  /// Creates a new user.
  ///
  /// Be aware that if a user account exists in the system you may get back an
  /// error message that attempts to hide this information from the user.
  /// This method has support for PKCE via email signups. The PKCE flow cannot be used when autoconfirm is enabled.
  ///
  /// Returns a logged-in session if the server has "autoconfirm" ON, but only a user if the server has "autoconfirm" OFF
  ///
  /// [email] is the user's email address
  ///
  /// [phone] is the user's phone number WITH international prefix
  ///
  /// [password] is the password of the user
  ///
  /// [data] sets [User.userMetadata] without an extra call to [updateUser]
  ///
  /// [channel] Messaging channel to use (e.g. whatsapp or sms)
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    assert((email != null && phone == null) || (email == null && phone != null),
        'You must provide either an email or phone number');

    late final Map<String, dynamic> response;

    if (email != null) {
      String? codeChallenge;

      if (_flowType == AuthFlowType.pkce) {
        assert(_asyncStorage != null,
            'You need to provide asyncStorage to perform pkce flow.');
        final codeVerifier = generatePKCEVerifier();
        await _asyncStorage!.setItem(
            key: '${Constants.defaultStorageKey}-code-verifier',
            value: codeVerifier);
        codeChallenge = generatePKCEChallenge(codeVerifier);
      }

      response = await _fetch.request(
        '$_url/signup',
        RequestMethodType.post,
        options: GotrueRequestOptions(
          headers: _headers,
          redirectTo: emailRedirectTo,
          body: {
            'email': email,
            'password': password,
            'data': data,
            'gotrue_meta_security': {'captcha_token': captchaToken},
            'code_challenge': codeChallenge,
            'code_challenge_method': codeChallenge != null ? 's256' : null,
          },
        ),
      );
    } else if (phone != null) {
      final body = {
        'phone': phone,
        'password': password,
        'data': data,
        'gotrue_meta_security': {'captcha_token': captchaToken},
        'channel': channel.name,
      };
      final fetchOptions = GotrueRequestOptions(headers: _headers, body: body);
      response = await _fetch.request('$_url/signup', RequestMethodType.post,
          options: fetchOptions) as Map<String, dynamic>;
    } else {
      throw AuthException(
          'You must provide either an email or phone number and a password');
    }

    final authResponse = AuthResponse.fromJson(response);

    final session = authResponse.session;
    if (session != null) {
      _saveSession(session);
      notifyAllSubscribers(AuthChangeEvent.signedIn);
    }

    return authResponse;
  }

  /// Log in an existing user with an email and password or phone and password.
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    late final Map<String, dynamic> response;

    if (email != null) {
      response = await _fetch.request(
        '$_url/token',
        RequestMethodType.post,
        options: GotrueRequestOptions(
          headers: _headers,
          body: {
            'email': email,
            'password': password,
            'gotrue_meta_security': {'captcha_token': captchaToken},
          },
          query: {'grant_type': 'password'},
        ),
      );
    } else if (phone != null) {
      response = await _fetch.request(
        '$_url/token',
        RequestMethodType.post,
        options: GotrueRequestOptions(
          headers: _headers,
          body: {
            'phone': phone,
            'password': password,
            'gotrue_meta_security': {'captcha_token': captchaToken},
          },
          query: {'grant_type': 'password'},
        ),
      );
    } else {
      throw AuthException(
        'You must provide either an email, phone number, a third-party provider or OpenID Connect.',
      );
    }

    final authResponse = AuthResponse.fromJson(response);

    if (authResponse.session?.accessToken != null) {
      _saveSession(authResponse.session!);
      notifyAllSubscribers(AuthChangeEvent.signedIn);
    }
    return authResponse;
  }

  /// Generates a link to log in an user via a third-party provider.
  Future<OAuthResponse> getOAuthSignInUrl({
    required OAuthProvider provider,
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    return _getUrlForProvider(
      provider,
      url: '$_url/authorize',
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
    );
  }

  /// Verifies the PKCE code verifyer and retrieves a session.
  Future<AuthSessionUrlResponse> exchangeCodeForSession(String authCode) async {
    assert(_asyncStorage != null,
        'You need to provide asyncStorage to perform pkce flow.');

    final codeVerifierRawString = await _asyncStorage!
        .getItem(key: '${Constants.defaultStorageKey}-code-verifier');
    if (codeVerifierRawString == null) {
      throw AuthException('Code verifier could not be found in local storage.');
    }
    final codeVerifier = codeVerifierRawString.split('/').first;
    final eventName = codeVerifierRawString.split('/').last;
    final redirectType = AuthChangeEventExtended.fromString(eventName);

    final Map<String, dynamic> response = await _fetch.request(
      '$_url/token',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
        body: {
          'auth_code': authCode,
          'code_verifier': codeVerifier,
        },
        query: {
          'grant_type': 'pkce',
        },
      ),
    );

    await _asyncStorage.removeItem(
        key: '${Constants.defaultStorageKey}-code-verifier');

    final authSessionUrlResponse = AuthSessionUrlResponse(
        session: Session.fromJson(response)!, redirectType: redirectType?.name);

    final session = authSessionUrlResponse.session;
    _saveSession(session);
    if (redirectType == AuthChangeEvent.passwordRecovery) {
      notifyAllSubscribers(AuthChangeEvent.passwordRecovery);
    } else {
      notifyAllSubscribers(AuthChangeEvent.signedIn);
    }

    return authSessionUrlResponse;
  }

  /// Sign in with ID token (internal helper method).
  Future<AuthResponse> _signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
    required bool linkIdentity,
  }) async {
    if (provider != OAuthProvider.google &&
        provider != OAuthProvider.apple &&
        provider != OAuthProvider.kakao &&
        provider != OAuthProvider.keycloak) {
      throw AuthException('Provider must be '
          '${OAuthProvider.google.name}, ${OAuthProvider.apple.name}, ${OAuthProvider.kakao.name} or ${OAuthProvider.keycloak.name}.');
    }

    final body = {
      'provider': provider.snakeCase,
      'id_token': idToken,
      'nonce': nonce,
      'gotrue_meta_security': {'captcha_token': captchaToken},
      'access_token': accessToken,
    };

    if (linkIdentity) {
      body['link_identity'] = true;
    }

    final response = await _fetch.request(
      '$_url/token',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
        body: body,
        query: {'grant_type': 'id_token'},
      ),
    );

    final authResponse = AuthResponse.fromJson(response);

    if (authResponse.session == null) {
      throw AuthException(
        'An error occurred on token verification.',
      );
    }

    _saveSession(authResponse.session!);
    notifyAllSubscribers(AuthChangeEvent.signedIn);

    return authResponse;
  }

  /// Allows signing in with an ID token issued by certain supported providers.
  /// The [idToken] is verified for validity and a new session is established.
  /// This method of signing in only supports [OAuthProvider.google], [OAuthProvider.apple], [OAuthProvider.kakao] or [OAuthProvider.keycloak].
  ///
  /// If the ID token contains an `at_hash` claim, then [accessToken] must be
  /// provided to compare its hash with the value in the ID token.
  ///
  /// If the ID token contains a `nonce` claim, then [nonce] must be
  /// provided to compare its hash with the value in the ID token.
  ///
  /// [captchaToken] is the verification token received when the user
  /// completes the captcha on the app.
  Future<AuthResponse> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
  }) async {
    return _signInWithIdToken(
      provider: provider,
      idToken: idToken,
      accessToken: accessToken,
      nonce: nonce,
      captchaToken: captchaToken,
      linkIdentity: false,
    );
  }

  /// Log in a user using magiclink or a one-time password (OTP).
  ///
  /// If the `{{ .ConfirmationURL }}` variable is specified in the email template, a magiclink will be sent.
  ///
  /// If the `{{ .Token }}` variable is specified in the email template, an OTP will be sent.
  ///
  /// If you're using phone sign-ins, only an OTP will be sent. You won't be able to send a magiclink for phone sign-ins.
  ///
  /// If [shouldCreateUser] is set to false, this method will not create a new user. Defaults to true.
  ///
  /// [emailRedirectTo] can be used to specify the redirect URL embedded in the email link
  ///
  /// [data] can be used to set the user's metadata, which maps to the `auth.users.user_metadata` column.
  ///
  /// [captchaToken] Verification token received when the user completes the captcha on the site.
  ///
  /// [channel] Messaging channel to use (e.g. whatsapp or sms)
  Future<void> signInWithOtp({
    String? email,
    String? phone,
    String? emailRedirectTo,
    bool? shouldCreateUser,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    if (email != null) {
      String? codeChallenge;
      if (_flowType == AuthFlowType.pkce) {
        assert(_asyncStorage != null,
            'You need to provide asyncStorage to perform pkce flow.');
        final codeVerifier = generatePKCEVerifier();
        await _asyncStorage!.setItem(
            key: '${Constants.defaultStorageKey}-code-verifier',
            value: codeVerifier);
        codeChallenge = generatePKCEChallenge(codeVerifier);
      }
      await _fetch.request(
        '$_url/otp',
        RequestMethodType.post,
        options: GotrueRequestOptions(
          headers: _headers,
          redirectTo: emailRedirectTo,
          body: {
            'email': email,
            'data': data ?? {},
            'create_user': shouldCreateUser ?? true,
            'gotrue_meta_security': {'captcha_token': captchaToken},
            'code_challenge': codeChallenge,
            'code_challenge_method': codeChallenge != null ? 's256' : null,
          },
        ),
      );
      return;
    }
    if (phone != null) {
      final body = {
        'phone': phone,
        'data': data ?? {},
        'create_user': shouldCreateUser ?? true,
        'gotrue_meta_security': {'captcha_token': captchaToken},
        'channel': channel.name,
      };
      final fetchOptions = GotrueRequestOptions(headers: _headers, body: body);

      await _fetch.request(
        '$_url/otp',
        RequestMethodType.post,
        options: fetchOptions,
      );
      return;
    }
    throw AuthException(
      'You must provide either an email, phone number, a third-party provider or OpenID Connect.',
    );
  }

  /// Log in a user given a User supplied OTP received via mobile.
  ///
  /// [phone] is the user's phone number WITH international prefix
  ///
  /// [token] is the token that user was sent to their mobile phone
  ///
  /// [tokenHash] is the token used in an email link
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    assert(
        ((email != null && phone == null) ||
                (email == null && phone != null)) ||
            (tokenHash != null),
        '`email` or `phone` needs to be specified.');
    assert(token != null || tokenHash != null,
        '`token` or `tokenHash` needs to be specified.');

    final body = {
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (token != null) 'token': token,
      'type': type.snakeCase,
      'redirect_to': redirectTo,
      'gotrue_meta_security': {'captchaToken': captchaToken},
      if (tokenHash != null) 'token_hash': tokenHash,
    };
    final fetchOptions = GotrueRequestOptions(headers: _headers, body: body);
    final response = await _fetch
        .request('$_url/verify', RequestMethodType.post, options: fetchOptions);

    final authResponse = AuthResponse.fromJson(response);

    if (authResponse.session == null) {
      throw AuthException(
        'An error occurred on token verification.',
      );
    }

    _saveSession(authResponse.session!);
    notifyAllSubscribers(type == OtpType.recovery
        ? AuthChangeEvent.passwordRecovery
        : AuthChangeEvent.signedIn);

    return authResponse;
  }

  /// Obtains a URL to perform a single-sign on using an enterprise Identity
  /// Provider. The redirect URL is implementation and SSO protocol specific.
  ///
  /// You can use it by providing a SSO domain. Typically you can extract this
  /// domain by asking users for their email address. If this domain is
  /// registered on the Auth instance the redirect will use that organization's
  /// currently active SSO Identity Provider for the login.
  ///
  /// If you have built an organization-specific login page, you can use the
  /// organization's SSO Identity Provider UUID directly instead.
  Future<String> getSSOSignInUrl({
    String? providerId,
    String? domain,
    String? redirectTo,
    String? captchaToken,
  }) async {
    assert(
      providerId != null || domain != null,
      'providerId or domain has to be provided.',
    );

    String? codeChallenge;
    String? codeChallengeMethod;
    if (_flowType == AuthFlowType.pkce) {
      assert(_asyncStorage != null,
          'You need to provide asyncStorage to perform pkce flow.');
      final codeVerifier = generatePKCEVerifier();
      await _asyncStorage!.setItem(
          key: '${Constants.defaultStorageKey}-code-verifier',
          value: codeVerifier);
      codeChallenge = generatePKCEChallenge(codeVerifier);
      codeChallengeMethod = codeVerifier == codeChallenge ? 'plain' : 's256';
    }

    final res = await _fetch.request('$_url/sso', RequestMethodType.post,
        options: GotrueRequestOptions(
          body: {
            if (providerId != null) 'provider_id': providerId,
            if (domain != null) 'domain': domain,
            if (redirectTo != null) 'redirect_to': redirectTo,
            if (captchaToken != null)
              'gotrue_meta_security': {'captcha_token': captchaToken},
            'skip_http_redirect': true,
            'code_challenge': codeChallenge,
            'code_challenge_method': codeChallengeMethod,
          },
          headers: _headers,
        ));

    return res['url'] as String;
  }

  /// Returns a new session, regardless of expiry status.
  /// Takes in an optional current session. If not passed in, then refreshSession() will attempt to retrieve it from getSession().
  /// If the current session's refresh token is invalid, an error will be thrown.
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    if (currentSession?.accessToken == null) {
      _log.warning("Can't refresh session, no current session found.");
      throw AuthSessionMissingException();
    }
    _log.info('Refresh session');

    final currentSessionRefreshToken =
        refreshToken ?? _currentSession?.refreshToken;

    if (currentSessionRefreshToken == null) {
      throw AuthSessionMissingException();
    }

    return await _callRefreshToken(currentSessionRefreshToken);
  }

  /// Sends a reauthentication OTP to the user's email or phone number.
  ///
  /// Requires the user to be signed-in.
  Future<void> reauthenticate() async {
    final session = currentSession;
    if (session == null) {
      throw AuthSessionMissingException();
    }

    final options =
        GotrueRequestOptions(headers: headers, jwt: session.accessToken);

    await _fetch.request(
      '$_url/reauthenticate',
      RequestMethodType.get,
      options: options,
    );
  }

  /// Resends an existing signup confirmation email, email change email, SMS OTP or phone change OTP.
  ///
  /// For [type] of [OtpType.signup] or [OtpType.emailChange] [email] must be
  /// provided, and for [type] or [OtpType.sms] or [OtpType.phoneChange],
  /// [phone] must be provided
  Future<ResendResponse> resend({
    String? email,
    String? phone,
    required OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
    assert((email != null && phone == null) || (email == null && phone != null),
        '`email` or `phone` needs to be specified.');
    if (email != null) {
      assert([OtpType.signup, OtpType.emailChange].contains(type),
          'email must be provided for type ${type.name}');
    }
    if (phone != null) {
      assert([OtpType.sms, OtpType.phoneChange].contains(type),
          'phone must be provided for type ${type.name}');
    }

    final body = {
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'type': type.snakeCase,
      'gotrue_meta_security': {'captcha_token': captchaToken},
    };

    final options = GotrueRequestOptions(
      headers: _headers,
      body: body,
      redirectTo: emailRedirectTo,
    );

    final response = await _fetch.request(
      '$_url/resend',
      RequestMethodType.post,
      options: options,
    );

    if ((response as Map).containsKey(['message_id'])) {
      return ResendResponse(messageId: response['message_id']);
    } else {
      return ResendResponse();
    }
  }

  /// Gets the current user details from current session or custom [jwt]
  Future<UserResponse> getUser([String? jwt]) async {
    if (jwt == null && currentSession?.accessToken == null) {
      throw AuthSessionMissingException();
    }
    final options = GotrueRequestOptions(
      headers: _headers,
      jwt: jwt ?? currentSession?.accessToken,
    );
    final response = await _fetch.request(
      '$_url/user',
      RequestMethodType.get,
      options: options,
    );
    return UserResponse.fromJson(response);
  }

  /// Updates user data, if there is a logged in user.
  Future<UserResponse> updateUser(
    UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    final accessToken = currentSession?.accessToken;
    if (accessToken == null) {
      throw AuthSessionMissingException();
    }

    final body = attributes.toJson();
    final options = GotrueRequestOptions(
      headers: _headers,
      body: body,
      jwt: accessToken,
      redirectTo: emailRedirectTo,
    );
    final response = await _fetch.request('$_url/user', RequestMethodType.put,
        options: options);
    final userResponse = UserResponse.fromJson(response);

    _currentSession = currentSession?.copyWith(user: userResponse.user);
    notifyAllSubscribers(AuthChangeEvent.userUpdated);

    return userResponse;
  }

  /// Sets the session data from refresh_token and returns the current session.
  Future<AuthResponse> setSession(String refreshToken) async {
    if (refreshToken.isEmpty) {
      throw AuthSessionMissingException('Refresh token cannot be empty');
    }
    return await _callRefreshToken(refreshToken);
  }

  /// Gets the session data from a magic link or oauth2 callback URL
  Future<AuthSessionUrlResponse> getSessionFromUrl(
    Uri originUrl, {
    bool storeSession = true,
  }) async {
    var url = originUrl;
    if (originUrl.hasQuery) {
      final decoded = originUrl.toString().replaceAll('#', '&');
      url = Uri.parse(decoded);
    } else {
      final decoded = originUrl.toString().replaceAll('#', '?');
      url = Uri.parse(decoded);
    }

    final errorDescription = url.queryParameters['error_description'];
    final errorCode = url.queryParameters['error_code'];
    final error = url.queryParameters['error'];
    if (errorDescription != null) {
      throw AuthException(
        errorDescription,
        statusCode: errorCode,
        code: error,
      );
    }

    if (_flowType == AuthFlowType.pkce) {
      final authCode = originUrl.queryParameters['code'];
      if (authCode == null) {
        throw AuthPKCEGrantCodeExchangeError(
            'No code detected in query parameters.');
      }
      return await exchangeCodeForSession(authCode);
    }

    final accessToken = url.queryParameters['access_token'];
    final expiresIn = url.queryParameters['expires_in'];
    final refreshToken = url.queryParameters['refresh_token'];
    final tokenType = url.queryParameters['token_type'];
    final providerToken = url.queryParameters['provider_token'];
    final providerRefreshToken = url.queryParameters['provider_refresh_token'];

    if (accessToken == null) {
      throw AuthException('No access_token detected.');
    }
    if (expiresIn == null) {
      throw AuthException('No expires_in detected.');
    }
    if (refreshToken == null) {
      throw AuthException('No refresh_token detected.');
    }
    if (tokenType == null) {
      throw AuthException('No token_type detected.');
    }

    final user = (await getUser(accessToken)).user;
    if (user == null) {
      throw AuthException('No user found.');
    }

    final session = Session(
      providerToken: providerToken,
      providerRefreshToken: providerRefreshToken,
      accessToken: accessToken,
      expiresIn: int.parse(expiresIn),
      refreshToken: refreshToken,
      tokenType: tokenType,
      user: user,
    );

    final redirectType = url.queryParameters['type'];

    if (storeSession == true) {
      _saveSession(session);
      if (redirectType == 'recovery') {
        notifyAllSubscribers(AuthChangeEvent.passwordRecovery);
      } else {
        notifyAllSubscribers(AuthChangeEvent.signedIn);
      }
    }

    return AuthSessionUrlResponse(session: session, redirectType: redirectType);
  }

  /// Signs out the current user, if there is a logged in user.
  ///
  /// [scope] determines which sessions should be logged out.
  ///
  /// If using [SignOutScope.others] scope, no [AuthChangeEvent.signedOut] event is fired!
  Future<void> signOut({
    SignOutScope scope = SignOutScope.local,
  }) async {
    _log.info('Signing out user with scope: $scope');
    final accessToken = currentSession?.accessToken;

    if (scope != SignOutScope.others) {
      _removeSession();
      await _asyncStorage?.removeItem(
          key: '${Constants.defaultStorageKey}-code-verifier');
      notifyAllSubscribers(AuthChangeEvent.signedOut);
    }

    if (accessToken != null) {
      try {
        await admin.signOut(accessToken, scope: scope);
      } on AuthException catch (error) {
        // ignore 401s since an invalid or expired JWT should sign out the current session
        // ignore 403s since user might not exist anymore
        // ignore 404s since user might not exist anymore
        if (error.statusCode != '401' &&
            error.statusCode != '403' &&
            error.statusCode != '404') {
          rethrow;
        }
      }
    }
  }

  /// Sends a reset request to an email address.
  Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
    String? captchaToken,
  }) async {
    String? codeChallenge;
    if (_flowType == AuthFlowType.pkce) {
      assert(_asyncStorage != null,
          'You need to provide asyncStorage to perform pkce flow.');
      final codeVerifier = generatePKCEVerifier();
      await _asyncStorage!.setItem(
        key: '${Constants.defaultStorageKey}-code-verifier',
        value: '$codeVerifier/${AuthChangeEvent.passwordRecovery.name}',
      );
      codeChallenge = generatePKCEChallenge(codeVerifier);
    }

    final body = {
      'email': email,
      'gotrue_meta_security': {'captcha_token': captchaToken},
      'code_challenge': codeChallenge,
      'code_challenge_method': codeChallenge != null ? 's256' : null,
    };

    final fetchOptions = GotrueRequestOptions(
      headers: _headers,
      body: body,
      redirectTo: redirectTo,
    );
    await _fetch.request(
      '$_url/recover',
      RequestMethodType.post,
      options: fetchOptions,
    );
  }

  /// Gets all the identities linked to a user.
  Future<List<UserIdentity>> getUserIdentities() async {
    final res = await getUser();
    return res.user?.identities ?? [];
  }

  /// Link an identity to the current user using an ID token.
  ///
  /// [provider] is the OAuth provider (google, apple, kakao, or keycloak)
  ///
  /// [idToken] is the ID token from the OAuth provider
  ///
  /// [accessToken] is the access token from the OAuth provider
  ///
  /// [nonce] is the nonce used for the OAuth flow
  ///
  /// [captchaToken] is the verification token received when the user
  /// completes the captcha on the app.
  Future<AuthResponse> linkIdentityWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
  }) async {
    return _signInWithIdToken(
      provider: provider,
      idToken: idToken,
      accessToken: accessToken,
      nonce: nonce,
      captchaToken: captchaToken,
      linkIdentity: true,
    );
  }

  /// Returns the URL to link the user's identity with an OAuth provider.
  Future<OAuthResponse> getLinkIdentityUrl(
    OAuthProvider provider, {
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    final urlResponse = await _getUrlForProvider(
      provider,
      url: '$_url/user/identities/authorize',
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
      skipBrowserRedirect: true,
    );
    final res = await _fetch.request(urlResponse.url, RequestMethodType.get,
        options: GotrueRequestOptions(
          headers: _headers,
          jwt: _currentSession?.accessToken,
        ));
    return OAuthResponse(provider: provider, url: res['url']);
  }

  /// Unlinks an identity from a user by deleting it.
  ///
  /// The user will no longer be able to sign in with that identity once it's unlinked.
  Future<void> unlinkIdentity(UserIdentity identity) async {
    await _fetch.request(
      '$_url/user/identities/${identity.identityId}',
      RequestMethodType.delete,
      options: GotrueRequestOptions(
        headers: headers,
        jwt: _currentSession?.accessToken,
      ),
    );
  }

  /// Set the initial session to the session obtained from local storage
  Future<void> setInitialSession(String jsonStr) async {
    final session = Session.fromJson(json.decode(jsonStr));
    if (session == null) {
      // sign out to delete the local storage from supabase_flutter
      await signOut();
      throw notifyException(AuthException('Initial session is missing data.'));
    }

    _currentSession = session;
    notifyAllSubscribers(AuthChangeEvent.initialSession);
  }

  /// Recover session from stringified [Session].
  Future<AuthResponse> recoverSession(String jsonStr) async {
    try {
      final session = Session.fromJson(json.decode(jsonStr));
      if (session == null) {
        _log.warning("Can't recover session from string, session is null");
        await signOut();
        throw notifyException(
          AuthException('Current session is missing data.'),
        );
      }

      if (session.isExpired) {
        _log.fine('Session from recovery is expired');
        final refreshToken = session.refreshToken;
        if (_autoRefreshToken && refreshToken != null) {
          return await _callRefreshToken(refreshToken);
        } else {
          await signOut();
          throw notifyException(AuthException('Session expired.'));
        }
      } else {
        final shouldEmitEvent = _currentSession == null ||
            _currentSession!.user.id != session.user.id;
        _saveSession(session);

        if (shouldEmitEvent) {
          notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);
        }

        return AuthResponse(session: session);
      }
    } catch (error, stackTrace) {
      notifyException(error, stackTrace);
      rethrow;
    }
  }

  /// Starts an auto-refresh process in the background. Close to the time of expiration a process is started to
  /// refresh the session. If refreshing fails it will be retried for as long as necessary.
  void startAutoRefresh() async {
    stopAutoRefresh();

    _log.fine('Starting auto refresh');
    _autoRefreshTicker = Timer.periodic(
      Constants.autoRefreshTickDuration,
      (Timer t) => _autoRefreshTokenTick(),
    );

    await Future.delayed(Duration.zero);
    await _autoRefreshTokenTick();
  }

  /// Stops an active auto refresh process running in the background (if any).
  void stopAutoRefresh() {
    _log.fine('Stopping auto refresh');
    _autoRefreshTicker?.cancel();
    _autoRefreshTicker = null;
  }

  Future<void> _autoRefreshTokenTick() async {
    try {
      final now = DateTime.now();
      final refreshToken = _currentSession?.refreshToken;
      if (refreshToken == null) {
        return;
      }

      final expiresAt = _currentSession?.expiresAt;
      if (expiresAt == null) {
        return;
      }

      final expiresInTicks =
          (DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
                      .difference(now)
                      .inMilliseconds /
                  Constants.autoRefreshTickDuration.inMilliseconds)
              .floor();

      _log.finer('Access token expires in $expiresInTicks ticks');

      // Only tick if the next tick comes after the retry threshold
      if (expiresInTicks <= Constants.autoRefreshTickThreshold) {
        await _callRefreshToken(refreshToken);
      }
    } catch (error) {
      // Do nothing. JS client prints here, but error is already tracked via
      // [notifyException]
    }
  }

  /// Generates a new JWT.
  /// [refreshToken] A valid refresh token that was returned on login.
  Future<AuthResponse> _refreshAccessToken(String refreshToken) async {
    final startedAt = DateTime.now();
    var attempt = 0;
    return await retry<AuthResponse>(
      // Make a GET request
      () async {
        attempt++;
        _log.fine('Attempt $attempt to refresh token');
        final options = GotrueRequestOptions(
            headers: _headers,
            body: {'refresh_token': refreshToken},
            query: {'grant_type': 'refresh_token'});
        final response = await _fetch
            .request('$_url/token', RequestMethodType.post, options: options);
        final authResponse = AuthResponse.fromJson(response);
        return authResponse;
      },
      retryIf: (e) {
        // Do not retry if the next retry comes after the next tick.
        final nextBackOff =
            Duration(milliseconds: (200 * pow(2, attempt - 1).floor()));

        return e is AuthRetryableFetchException &&
            (DateTime.now().millisecondsSinceEpoch +
                    nextBackOff.inMilliseconds -
                    startedAt.millisecondsSinceEpoch) <
                Constants.autoRefreshTickDuration.inMilliseconds;
      },
      maxDelay: Duration(seconds: 10),
      randomizationFactor: 0,

      // Max interval between retries is 10 sec, so just set the maxAttempts
      // to something that will yield a more than 10 sec interval.
      maxAttempts: 999,
    );
  }

  /// Returns the OAuth sign in URL constructed from the [url] parameter.
  Future<OAuthResponse> _getUrlForProvider(
    OAuthProvider provider, {
    required String url,
    required String? scopes,
    required String? redirectTo,
    required Map<String, String>? queryParams,
    bool skipBrowserRedirect = false,
  }) async {
    final urlParams = {'provider': provider.snakeCase};
    if (scopes != null) {
      urlParams['scopes'] = scopes;
    }
    if (redirectTo != null) {
      urlParams['redirect_to'] = redirectTo;
    }
    if (queryParams != null) {
      urlParams.addAll(queryParams);
    }
    if (_flowType == AuthFlowType.pkce) {
      assert(_asyncStorage != null,
          'You need to provide asyncStorage to perform pkce flow.');
      final codeVerifier = generatePKCEVerifier();
      await _asyncStorage!.setItem(
        key: '${Constants.defaultStorageKey}-code-verifier',
        value: codeVerifier,
      );

      final codeChallenge = generatePKCEChallenge(codeVerifier);
      final flowParams = {
        'flow_type': _flowType.name,
        'code_challenge': codeChallenge,
        'code_challenge_method': 's256',
      };
      urlParams.addAll(flowParams);
    }
    if (skipBrowserRedirect) {
      urlParams['skip_http_redirect'] = 'true';
    }
    final oauthUrl = '$url?${Uri(queryParameters: urlParams).query}';
    return OAuthResponse(provider: provider, url: oauthUrl);
  }

  /// set currentSession and currentUser
  void _saveSession(Session session) {
    _log.finest('Saving session: $session');
    _log.fine('Saving session');
    _currentSession = session;
  }

  void _removeSession() {
    _log.fine('Removing session');
    _currentSession = null;
  }

  void _mayStartBroadcastChannel() {
    if (const bool.fromEnvironment('dart.library.js_interop')) {
      // Used by the js library as well
      final broadcastKey =
          "sb-${Uri.parse(_url).host.split(".").first}-auth-token";

      assert(_broadcastChannel == null,
          'Broadcast channel should not be started more than once.');
      try {
        _broadcastChannel = web.getBroadcastChannel(broadcastKey);
        _broadcastChannelSubscription =
            _broadcastChannel?.onMessage.listen((messageEvent) {
          final rawEvent = messageEvent['event'];
          _log.finest('Received broadcast message: $messageEvent');
          _log.info('Received broadcast event: $rawEvent');
          final event = switch (rawEvent) {
            // This library sends the js name of the event to be comptabile with
            // the js library, so we need to convert it back to the dart name
            'INITIAL_SESSION' => AuthChangeEvent.initialSession,
            'PASSWORD_RECOVERY' => AuthChangeEvent.passwordRecovery,
            'SIGNED_IN' => AuthChangeEvent.signedIn,
            'SIGNED_OUT' => AuthChangeEvent.signedOut,
            'TOKEN_REFRESHED' => AuthChangeEvent.tokenRefreshed,
            'USER_UPDATED' => AuthChangeEvent.userUpdated,
            'MFA_CHALLENGE_VERIFIED' => AuthChangeEvent.mfaChallengeVerified,
            // This case should never happen though
            _ => AuthChangeEvent.values
                .firstWhereOrNull((event) => event.name == rawEvent),
          };

          if (event != null) {
            Session? session;
            if (messageEvent['session'] != null) {
              session = Session.fromJson(messageEvent['session']);
            }
            if (session != null) {
              _saveSession(session);
            } else {
              _removeSession();
            }
            notifyAllSubscribers(event, session: session, broadcast: false);
          }
        });
      } catch (error, stackTrace) {
        _log.warning('Failed to start broadcast channel', error, stackTrace);
        // Ignoring
      }
    }
  }

  @mustCallSuper
  void dispose() {
    _onAuthStateChangeController.close();
    _onAuthStateChangeControllerSync.close();
    _broadcastChannel?.close();
    _broadcastChannelSubscription?.cancel();
    _refreshTokenCompleter?.completeError(AuthException('Disposed'));
    _autoRefreshTicker?.cancel();
  }

  /// Generates a new JWT.
  ///
  /// To prevent multiple simultaneous requests it catches an already ongoing request by using the global [_refreshTokenCompleter].
  /// If that's not null and not completed it returns the future of the ongoing request.
  Future<AuthResponse> _callRefreshToken(String refreshToken) async {
    // Refreshing is already in progress
    if (_refreshTokenCompleter != null) {
      _log.finer("Don't call refresh token, already in progress");
      return _refreshTokenCompleter!.future;
    }

    try {
      _refreshTokenCompleter = Completer<AuthResponse>();

      // Catch any error in case nobody awaits the future
      _refreshTokenCompleter!.future.then(
        (_) => null,
        onError: (_, __) => null,
      );
      _log.fine('Refresh access token');

      final data = await _refreshAccessToken(refreshToken);

      final session = data.session;

      if (session == null) {
        throw AuthSessionMissingException();
      }

      _saveSession(session);
      notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);

      _refreshTokenCompleter?.complete(data);
      return data;
    } on AuthException catch (error, stack) {
      if (error is! AuthRetryableFetchException) {
        _removeSession();
        notifyAllSubscribers(AuthChangeEvent.signedOut);
      } else {
        notifyException(error, stack);
      }

      _refreshTokenCompleter?.completeError(error);

      rethrow;
    } catch (error, stack) {
      _refreshTokenCompleter?.completeError(error);
      notifyException(error, stack);
      rethrow;
    } finally {
      _refreshTokenCompleter = null;
    }
  }

  /// For internal use only.
  ///
  /// [broadcast] is used to determine if the event should be broadcasted to
  /// other tabs.
  @internal
  void notifyAllSubscribers(
    AuthChangeEvent event, {
    Session? session,
    bool broadcast = true,
  }) {
    session ??= currentSession;
    if (broadcast && event != AuthChangeEvent.initialSession) {
      _broadcastChannel?.postMessage({
        'event': event.jsName,
        'session': session?.toJson(),
      });
    }
    final state = AuthState(event, session, fromBroadcast: !broadcast);
    _log.finest('onAuthStateChange: $state');
    _onAuthStateChangeController.add(state);
    _onAuthStateChangeControllerSync.add(state);
  }

  /// For internal use only.
  @internal
  Object notifyException(Object exception, [StackTrace? stackTrace]) {
    _log.warning('Notifying exception', exception, stackTrace);
    _onAuthStateChangeController.addError(
      exception,
      stackTrace ?? StackTrace.current,
    );
    return exception;
  }
}
