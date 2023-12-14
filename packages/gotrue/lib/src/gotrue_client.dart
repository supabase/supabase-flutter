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
import 'package:meta/meta.dart';
import 'package:rxdart/subjects.dart';

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

  /// The currently logged in user or null.
  User? _currentUser;

  /// The session object for the currently logged in user or null.
  Session? _currentSession;

  final String _url;
  final Map<String, String> _headers;
  final Client? _httpClient;
  late final GotrueFetch _fetch = GotrueFetch(_httpClient);

  late bool _autoRefreshToken;

  Timer? _refreshTokenTimer;

  int _refreshTokenRetryCount = 0;

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

  /// {@macro gotrue_client}
  GoTrueClient({
    String? url,
    Map<String, String>? headers,
    bool? autoRefreshToken,
    Client? httpClient,
    GotrueAsyncStorage? asyncStorage,
    AuthFlowType flowType = AuthFlowType.pkce,
  })  : _url = url ?? Constants.defaultGotrueUrl,
        _headers = headers ?? {},
        _httpClient = httpClient,
        _asyncStorage = asyncStorage,
        _flowType = flowType {
    _autoRefreshToken = autoRefreshToken ?? true;

    final gotrueUrl = url ?? Constants.defaultGotrueUrl;
    final gotrueHeader = {
      ...Constants.defaultHeaders,
      if (headers != null) ...headers,
    };
    admin = GoTrueAdminApi(
      gotrueUrl,
      headers: gotrueHeader,
      httpClient: httpClient,
    );
    mfa = GoTrueMFAApi(
      client: this,
      fetch: _fetch,
    );
  }

  /// Getter for the headers
  Map<String, String> get headers => _headers;

  /// Returns the current logged in user, if any;
  User? get currentUser => _currentUser;

  /// Returns the current session, if any;
  Session? get currentSession => _currentSession;

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

    _removeSession();

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
    _removeSession();

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
    _removeSession();
    return _handleProviderSignIn(
      provider,
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

    await _asyncStorage!
        .removeItem(key: '${Constants.defaultStorageKey}-code-verifier');

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

  /// Allows signing in with an ID token issued by certain supported providers.
  /// The [idToken] is verified for validity and a new session is established.
  /// This method of signing in only supports [OAuthProvider.google] or [OAuthProvider.apple].
  ///
  /// If the ID token contains an `at_hash` claim, then [accessToken] must be
  /// provided to compare its hash with the value in the ID token.
  ///
  /// If the ID token contains a `nonce` claim, then [nonce] must be
  /// provided to compare its hash with the value in the ID token.
  ///
  /// [captchaToken] is the verification token received when the user
  /// completes the captcha on the app.
  ///
  /// This method is experimental.
  @experimental
  Future<AuthResponse> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
  }) async {
    _removeSession();

    if (provider != OAuthProvider.google && provider != OAuthProvider.apple) {
      throw AuthException('Provider must either be '
          '${OAuthProvider.google.name} or ${OAuthProvider.apple.name}.');
    }

    final response = await _fetch.request(
      '$_url/token',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
        body: {
          'provider': provider.name,
          'id_token': idToken,
          'nonce': nonce,
          'gotrue_meta_security': {'captcha_token': captchaToken},
          'access_token': accessToken,
        },
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
    _removeSession();

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
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    required String token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
  }) async {
    assert((email != null && phone == null) || (email == null && phone != null),
        '`email` or `phone` needs to be specified.');

    if (type != OtpType.emailChange && type != OtpType.phoneChange) {
      _removeSession();
    }

    final body = {
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'token': token,
      'type': type.snakeCase,
      'redirect_to': redirectTo,
      'gotrue_meta_security': {'captchaToken': captchaToken},
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
    notifyAllSubscribers(AuthChangeEvent.signedIn);

    return authResponse;
  }

  /// Force refreshes the session including the user data in case it was updated
  /// in a different session.
  Future<AuthResponse> refreshSession() async {
    if (currentSession?.accessToken == null) {
      throw AuthException('Not logged in.');
    }

    return await _callRefreshToken();
  }

  /// Sends a reauthentication OTP to the user's email or phone number.
  ///
  /// Requires the user to be signed-in.
  Future<void> reauthenticate() async {
    final session = currentSession;
    if (session == null) {
      throw AuthException('Not logged in.');
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

    if (type != OtpType.emailChange && type != OtpType.phoneChange) {
      _removeSession();
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
      throw AuthException('Cannot get user: no current session.');
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
      throw AuthException('Not logged in.');
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

    _currentUser = userResponse.user;
    _currentSession = currentSession?.copyWith(user: userResponse.user);
    notifyAllSubscribers(AuthChangeEvent.userUpdated);

    return userResponse;
  }

  /// Sets the session data from refresh_token and returns the current session.
  Future<AuthResponse> setSession(String refreshToken) async {
    if (refreshToken.isEmpty) {
      throw AuthException('No current session.');
    }
    return await _callRefreshToken(refreshToken: refreshToken);
  }

  /// Gets the session data from a magic link or oauth2 callback URL
  Future<AuthSessionUrlResponse> getSessionFromUrl(
    Uri originUrl, {
    bool storeSession = true,
  }) async {
    if (_flowType == AuthFlowType.pkce) {
      final authCode = originUrl.queryParameters['code'];
      if (authCode == null) {
        throw AuthPKCEGrantCodeExchangeError(
            'No code detected in query parameters.');
      }
      return await exchangeCodeForSession(authCode);
    }
    var url = originUrl;
    if (originUrl.hasQuery) {
      final decoded = originUrl.toString().replaceAll('#', '&');
      url = Uri.parse(decoded);
    } else {
      final decoded = originUrl.toString().replaceAll('#', '?');
      url = Uri.parse(decoded);
    }

    final errorDescription = url.queryParameters['error_description'];
    if (errorDescription != null) {
      throw AuthException(errorDescription);
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
  /// [scope] dtermines which sessions should be logged out.
  ///
  /// If using [SignOutScope.others] scope, no [AuthChangeEvent.signedOut] event is fired!
  Future<void> signOut({
    SignOutScope scope = SignOutScope.local,
  }) async {
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
        // ignore 404s since user might not exist anymore
        if (error.statusCode != '401' && error.statusCode != '404') {
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
    final session = Session.fromJson(json.decode(jsonStr));
    if (session == null) {
      await signOut();
      throw notifyException(AuthException('Current session is missing data.'));
    }

    if (session.isExpired) {
      if (_autoRefreshToken && session.refreshToken != null) {
        return await _callRefreshToken(
          refreshToken: session.refreshToken,
          accessToken: session.accessToken,
        );
      } else {
        await signOut();
        throw notifyException(AuthException('Session expired.'));
      }
    } else {
      final shouldEmitEvent = _currentSession == null ||
          _currentSession?.user.id != session.user.id;
      _saveSession(session);

      if (shouldEmitEvent) notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);

      return AuthResponse(session: session);
    }
  }

  /// return provider url only
  Future<OAuthResponse> _handleProviderSignIn(
    OAuthProvider provider, {
    required String? scopes,
    required String? redirectTo,
    required Map<String, String>? queryParams,
  }) async {
    final urlParams = {'provider': provider.name};
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
    final url = '$_url/authorize?${Uri(queryParameters: urlParams).query}';
    return OAuthResponse(provider: provider, url: url);
  }

  void _saveSession(Session session) async {
    _currentSession = session;
    _currentUser = session.user;
    final expiresAt = session.expiresAt;

    if (_autoRefreshToken && expiresAt != null) {
      _refreshTokenTimer?.cancel();

      final timeNow = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      final expiresIn = expiresAt - timeNow;
      final refreshDurationBeforeExpires = expiresIn > 60 ? 60 : 1;
      final nextDuration = expiresIn - refreshDurationBeforeExpires;
      try {
        if (nextDuration > 0) {
          _refreshTokenRetryCount = 0;
          final timerDuration = Duration(seconds: nextDuration);
          _setTokenRefreshTimer(timerDuration);
        } else {
          await _callRefreshToken();
        }
      } catch (e) {
        // Catch any error, because in this case they should be handled by listening to [onAuthStateChange]
      }
    }
  }

  void _setTokenRefreshTimer(
    Duration timerDuration, {
    String? refreshToken,
    String? accessToken,
  }) {
    _refreshTokenTimer?.cancel();
    _refreshTokenRetryCount++;
    if (_refreshTokenRetryCount < Constants.maxRetryCount) {
      _refreshTokenTimer = Timer(timerDuration, () async {
        try {
          await _callRefreshToken(
            refreshToken: refreshToken,
            accessToken: accessToken,
            ignorePendingRequest: true,
          );
        } catch (_) {
          // Catch any error, because in this case they should be handled by listening to [onAuthStateChange]
        }
      });
    } else {
      throw AuthException('Access token refresh retry limit exceeded.');
    }
  }

  void _removeSession() {
    _currentSession = null;
    _currentUser = null;
    _refreshTokenRetryCount = 0;

    _refreshTokenTimer?.cancel();
  }

  /// Generates a new JWT.
  ///
  /// To prevent multiple simultaneous requests it catches an already ongoing request by using the global [_refreshTokenCompleter].
  /// If that's not null and not completed it returns the future of the ongoing request.
  ///
  /// To call [_callRefreshToken] during a running request [ignorePendingRequest] is used to bypass that check.
  ///
  /// When a [ClientException] occurs [_setTokenRefreshTimer] is used to schedule a retry in the background, which emits the result via [onAuthStateChange].
  Future<AuthResponse> _callRefreshToken({
    String? refreshToken,
    String? accessToken,
    bool ignorePendingRequest = false,
  }) async {
    if (_refreshTokenCompleter?.isCompleted ?? true) {
      _refreshTokenCompleter = Completer<AuthResponse>();
      // Catch any error in case nobody awaits the future
      _refreshTokenCompleter!.future.then(
        (value) => null,
        onError: (error, stack) => null,
      );
    } else if (!ignorePendingRequest) {
      return _refreshTokenCompleter!.future;
    }
    final token = refreshToken ?? currentSession?.refreshToken;
    if (token == null) {
      throw AuthException('No current session.');
    }

    final jwt = accessToken ?? currentSession?.accessToken;

    try {
      final body = {'refresh_token': token};
      if (jwt != null) {
        _headers['Authorization'] = 'Bearer $jwt';
      }
      final options = GotrueRequestOptions(
          headers: _headers,
          body: body,
          query: {'grant_type': 'refresh_token'});
      final response = await _fetch
          .request('$_url/token', RequestMethodType.post, options: options);
      final authResponse = AuthResponse.fromJson(response);

      if (authResponse.session == null) {
        throw AuthException('Invalid session data.');
      }

      _saveSession(authResponse.session!);
      if (!_refreshTokenCompleter!.isCompleted) {
        _refreshTokenCompleter!.complete(authResponse);
      }

      notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);
      return authResponse;
    } on ClientException catch (e, stack) {
      _setTokenRefreshTimer(
        Constants.retryInterval * pow(2, _refreshTokenRetryCount),
        refreshToken: token,
        accessToken: accessToken,
      );
      if (!_refreshTokenCompleter!.isCompleted) {
        _refreshTokenCompleter!.completeError(e, stack);
      }
      rethrow;
    } catch (error, stack) {
      if (error is AuthException) {
        if (error.message.startsWith('Invalid Refresh Token:')) {
          await signOut();
        }
      }
      if (!_refreshTokenCompleter!.isCompleted) {
        _refreshTokenCompleter!.completeError(error, stack);
      }
      _onAuthStateChangeController.addError(error, stack);
      rethrow;
    }
  }

  /// For internal use only.
  @internal
  void notifyAllSubscribers(AuthChangeEvent event) {
    final state = AuthState(event, currentSession);
    _onAuthStateChangeController.add(state);
    _onAuthStateChangeControllerSync.add(state);
  }

  /// For internal use only.
  @internal
  Exception notifyException(Exception exception, [StackTrace? stackTrace]) {
    _onAuthStateChangeController.addError(
      exception,
      stackTrace ?? StackTrace.current,
    );
    return exception;
  }
}
