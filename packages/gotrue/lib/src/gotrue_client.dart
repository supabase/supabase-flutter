import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:gotrue/gotrue.dart';
import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/fetch.dart';
import 'package:gotrue/src/helper.dart';
import 'package:gotrue/src/types/fetch_options.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

import 'broadcast_stub.dart'
    if (dart.library.js_interop) './broadcast_web.dart'
    as web;
import 'version.dart';

part 'gotrue_oauth_api.dart';
part 'gotrue_mfa_api.dart';
part 'gotrue_passkey_api.dart';

class _SessionState {
  Session? _session;
  int version = 0;

  Session? get session => _session;
  set session(Session? value) {
    version++;
    _session = value;
  }
}

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

  /// Namespace for the GoTrue OAuth methods.
  late final GoTrueOAuthApi oauth;

  /// Namespace for the passkey (WebAuthn) API methods.
  ///
  /// {@macro gotrue_passkey_api}
  @experimental
  late final GoTruePasskeyApi passkey;

  final _sessionState = _SessionState();

  Session? get _currentSession => _sessionState.session;
  set _currentSession(Session? value) => _sessionState.session = value;
  int get _sessionVersion => _sessionState.version;

  final String _url;
  final Map<String, String> _headers;
  final Client? _httpClient;
  late final GotrueFetch _fetch = GotrueFetch(_httpClient);

  late bool _autoRefreshToken;

  Timer? _autoRefreshTicker;

  /// Tracks all pending (in-flight) refreshes keyed by token.
  /// Concurrent calls with the same token return the existing
  /// [Completer.future] instead of starting a duplicate request.
  final Map<String, Completer<AuthResponse>> _pendingRefreshes = {};

  /// Set by [dispose] to prevent [_doRefresh] from mutating state
  /// or emitting events on closed stream controllers.
  bool _isDisposed = false;

  JWKSet? _jwks;
  DateTime? _jwksCachedAt;

  final _onAuthStateChangeController = ReplaySubject<AuthState>();
  final _onAuthStateChangeControllerSync = ReplaySubject<AuthState>(
    sync: true,
  );

  /// Local storage to store pkce code verifiers.
  final GotrueAsyncStorage? _asyncStorage;

  /// Receive a notification every time an auth event happens.
  ///
  /// Network errors (e.g. when the device is offline) are emitted as stream
  /// errors. You **must** supply an `onError` handler when calling `.listen()`,
  /// otherwise Dart will rethrow the error as an unhandled zone exception and
  /// crash the app.
  ///
  /// When the user is signed out because the session could not be recovered
  /// (e.g. an invalid or expired refresh token), an
  /// [AuthChangeEvent.signedOut] event is emitted with [AuthState.signOutReason]
  /// set to the matching [SignOutReason], so you can tell it apart from an
  /// explicit [signOut] without relying on the `onError` handler.
  ///
  /// ```dart
  /// supabase.auth.onAuthStateChange.listen(
  ///   (data) {
  ///     final AuthChangeEvent event = data.event;
  ///     final Session? session = data.session;
  ///     if (event == AuthChangeEvent.signedIn) {
  ///       // handle signIn event
  ///     }
  ///   },
  ///   onError: (error, stackTrace) {
  ///     // Handle or log network / auth errors here.
  ///     // Omitting this handler causes an unhandled exception when the
  ///     // device has no connectivity and a token refresh is attempted.
  ///   },
  /// );
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

  StreamSubscription<dynamic>? _broadcastChannelSubscription;

  /// {@macro gotrue_client}
  GoTrueClient({
    String? url,
    Map<String, String>? headers,
    bool? autoRefreshToken,
    Client? httpClient,
    GotrueAsyncStorage? asyncStorage,
    AuthFlowType flowType = AuthFlowType.pkce,
  }) : _url = url ?? Constants.defaultGotrueUrl,
       _headers = {...Constants.defaultHeaders, ...?headers},
       _httpClient = httpClient,
       _asyncStorage = asyncStorage,
       _flowType = flowType {
    _autoRefreshToken = autoRefreshToken ?? true;

    final gotrueUrl = url ?? Constants.defaultGotrueUrl;
    _log.config(
      'Initialize GoTrueClient v$version with url: $_url, autoRefreshToken: $_autoRefreshToken, flowType: ${_flowType.name}, tickDuration: ${Constants.autoRefreshTickDuration}, tickThreshold: ${Constants.autoRefreshTickThreshold}',
    );
    _log.finest('Initialize with headers: $_headers');
    admin = GoTrueAdminApi(
      gotrueUrl,
      headers: _headers,
      httpClient: httpClient,
    );
    oauth = GoTrueOAuthApi(client: this, fetch: _fetch);
    mfa = GoTrueMFAApi(client: this, fetch: _fetch);
    passkey = GoTruePasskeyApi(client: this, fetch: _fetch);
    if (_autoRefreshToken) {
      startAutoRefresh();
    }

    _mayStartBroadcastChannel();
  }

  /// Getter for the headers
  Map<String, String> get headers => _headers;

  /// Returns the current logged in user, associated to [currentSession] if any;
  User? get currentUser => _currentSession?.user;

  /// Returns the current session, if any;
  Session? get currentSession => _currentSession;

  /// Returns the current session, refreshing it on demand when the access
  /// token has expired.
  ///
  /// Where the synchronous [currentSession] getter returns whatever session is
  /// stored, even one whose access token has already expired, this returns a
  /// session whose access token is guaranteed to be valid when it resolves: a
  /// still-valid session is returned as-is, while an expired one is refreshed
  /// first. If a refresh is already in flight, the expired session waits for it
  /// to settle instead of starting another one.
  ///
  /// Returns `null` when there is no session. Throws an [AuthException] when an
  /// expired session cannot be refreshed, unless its access token is still
  /// within its real validity window, in which case the still-valid session is
  /// returned.
  Future<Session?> getSession() async {
    final session = _currentSession;
    if (session == null) {
      return null;
    }

    if (!session.isExpired) {
      return session;
    }

    final refreshToken = session.refreshToken;
    if (refreshToken == null) {
      return session;
    }

    try {
      // Concurrent callers share a single refresh through the same
      // de-duplication used by [refreshSession], so an expired session's
      // refresh token is only spent once.
      final response = await _callRefreshToken(refreshToken);
      return response.session;
    } on AuthException {
      final current = _currentSession;
      if (current != null && !current.isExpiredWithoutMargin) {
        return current;
      }
      rethrow;
    }
  }

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
    assert(
      (email != null && phone == null) || (email == null && phone != null),
      'You must provide either an email or phone number',
    );

    final Map<String, dynamic> response;

    if (email != null) {
      final codeChallenge = await _generatePKCECodeChallenge();

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
      response =
          await _fetch.request(
                '$_url/signup',
                RequestMethodType.post,
                options: fetchOptions,
              )
              as Map<String, dynamic>;
    } else {
      throw AuthException(
        'You must provide either an email or phone number and a password',
      );
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
    final Map<String, dynamic> response;

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
  }) {
    return _getUrlForProvider(
      provider,
      url: '$_url/authorize',
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
    );
  }

  /// Verifies the PKCE code verifier and retrieves a session.
  Future<AuthSessionUrlResponse> exchangeCodeForSession(String authCode) async {
    assert(
      _asyncStorage != null,
      'You need to provide asyncStorage to perform pkce flow.',
    );

    final codeVerifierRawString = await _asyncStorage!.getItem(
      key: '${Constants.defaultStorageKey}-code-verifier',
    );
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
        body: {'auth_code': authCode, 'code_verifier': codeVerifier},
        query: {'grant_type': 'pkce'},
      ),
    );

    await _asyncStorage.removeItem(
      key: '${Constants.defaultStorageKey}-code-verifier',
    );

    final authSessionUrlResponse = AuthSessionUrlResponse(
      session: Session.fromJson(response)!,
      redirectType: redirectType?.name,
    );

    final session = authSessionUrlResponse.session;
    _saveSession(session);
    if (redirectType == AuthChangeEvent.passwordRecovery) {
      notifyAllSubscribers(AuthChangeEvent.passwordRecovery);
    } else {
      notifyAllSubscribers(AuthChangeEvent.signedIn);
    }

    return authSessionUrlResponse;
  }

  /// Generates a PKCE code verifier, persists it, and returns the derived code
  /// challenge.
  ///
  /// Returns `null` when the client is not using the PKCE flow. When
  /// [storageEventName] is provided it is appended to the stored verifier so it
  /// can be recovered in [exchangeCodeForSession].
  Future<String?> _generatePKCECodeChallenge({String? storageEventName}) async {
    if (_flowType != AuthFlowType.pkce) {
      return null;
    }
    assert(
      _asyncStorage != null,
      'You need to provide asyncStorage to perform pkce flow.',
    );
    final codeVerifier = generatePKCEVerifier();
    await _asyncStorage!.setItem(
      key: '${Constants.defaultStorageKey}-code-verifier',
      value: storageEventName == null
          ? codeVerifier
          : '$codeVerifier/$storageEventName',
    );
    return generatePKCEChallenge(codeVerifier);
  }

  /// Allows signing in with an ID token issued by supported providers.
  /// Common supported providers include Apple, Google, Facebook, Kakao, and Keycloak.
  /// The [idToken] is verified for validity and a new session is established.
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
      throw AuthException('An error occurred on token verification.');
    }

    _saveSession(authResponse.session!);
    notifyAllSubscribers(AuthChangeEvent.signedIn);

    return authResponse;
  }

  /// Signs in a user by verifying a message signed with their Web3 wallet.
  ///
  /// Supports Ethereum (Sign-In with Ethereum) and Solana (Sign-In with
  /// Solana), both of which derive from the EIP-4361 standard.
  ///
  /// Wallet interaction and message signing are performed by the caller using
  /// their wallet library of choice. Provide the signed [message] together with
  /// its [signature]. For [Web3Chain.ethereum] the signature is a hex encoded
  /// string, for [Web3Chain.solana] it is a base64url encoded string.
  ///
  /// [captchaToken] is the verification token received when the user
  /// completes the captcha on the app.
  ///
  /// See also https://eips.ethereum.org/EIPS/eip-4361
  Future<AuthResponse> signInWithWeb3({
    required Web3Chain chain,
    required String message,
    required String signature,
    String? captchaToken,
  }) async {
    final response = await _fetch.request(
      '$_url/token',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
        body: {
          'chain': chain.name,
          'message': message,
          'signature': signature,
          if (captchaToken != null)
            'gotrue_meta_security': {'captcha_token': captchaToken},
        },
        query: {'grant_type': 'web3'},
      ),
    );

    final authResponse = AuthResponse.fromJson(response);

    if (authResponse.session == null) {
      throw AuthException('An error occurred on token verification.');
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
    if (email != null) {
      final codeChallenge = await _generatePKCECodeChallenge();
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
    // For recovery type with tokenHash, only tokenHash and type are required
    final isRecoveryWithTokenHash =
        type == OtpType.recovery && tokenHash != null;

    if (!isRecoveryWithTokenHash) {
      assert(
        ((email != null && phone == null) ||
                (email == null && phone != null)) ||
            (tokenHash != null),
        '`email` or `phone` needs to be specified.',
      );
      assert(
        token != null || tokenHash != null,
        '`token` or `tokenHash` needs to be specified.',
      );
    } else {
      // For recovery with tokenHash, email/phone should not be provided
      assert(
        email == null && phone == null,
        'For recovery type with tokenHash, only tokenHash and type should be provided.',
      );
    }

    final body = {
      // For recovery type with tokenHash, exclude email/phone
      if (!isRecoveryWithTokenHash && email != null) 'email': email,
      if (!isRecoveryWithTokenHash && phone != null) 'phone': phone,
      'token': ?token,
      'type': type.snakeCase,
      'redirect_to': redirectTo,
      'gotrue_meta_security': {'captcha_token': captchaToken},
      'token_hash': ?tokenHash,
    };
    final fetchOptions = GotrueRequestOptions(headers: _headers, body: body);
    final response = await _fetch.request(
      '$_url/verify',
      RequestMethodType.post,
      options: fetchOptions,
    );

    final authResponse = AuthResponse.fromJson(response);

    // A secure email or phone change verifies in two steps: the server accepts
    // the first OTP without returning a session and only issues one once the
    // second OTP is verified. In that case there is nothing to persist yet, so
    // return the intermediate response instead of treating it as an error.
    final session = authResponse.session;
    if (session != null) {
      _saveSession(session);
      notifyAllSubscribers(
        type == OtpType.recovery
            ? AuthChangeEvent.passwordRecovery
            : AuthChangeEvent.signedIn,
      );
    }

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

    final codeChallenge = await _generatePKCECodeChallenge();

    final res = await _fetch.request(
      '$_url/sso',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        body: {
          'provider_id': ?providerId,
          'domain': ?domain,
          'redirect_to': ?redirectTo,
          if (captchaToken != null)
            'gotrue_meta_security': {'captcha_token': captchaToken},
          'skip_http_redirect': true,
          'code_challenge': codeChallenge,
          'code_challenge_method': codeChallenge != null ? 's256' : null,
        },
        headers: _headers,
      ),
    );

    return res['url'] as String;
  }

  /// Returns a new session, regardless of expiry status.
  /// Takes in an optional [refreshToken]. If not provided, then refreshSession() will attempt to retrieve it from the current session.
  /// If no refresh token is available (neither provided nor in current session), an error will be thrown.
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    _log.info('Refresh session');

    final currentSessionRefreshToken =
        refreshToken ?? _currentSession?.refreshToken;

    if (currentSessionRefreshToken == null) {
      _log.warning("Can't refresh session, no refresh token found.");
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

    final options = GotrueRequestOptions(
      headers: headers,
      jwt: session.accessToken,
    );

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
    assert(
      (email != null && phone == null) || (email == null && phone != null),
      '`email` or `phone` needs to be specified.',
    );
    if (email != null) {
      assert(
        [OtpType.signup, OtpType.emailChange].contains(type),
        'email must be provided for type ${type.name}',
      );
    }
    if (phone != null) {
      assert(
        [OtpType.sms, OtpType.phoneChange].contains(type),
        'phone must be provided for type ${type.name}',
      );
    }

    final codeChallenge = email != null
        ? await _generatePKCECodeChallenge()
        : null;

    final body = {
      'email': ?email,
      'phone': ?phone,
      'type': type.snakeCase,
      'gotrue_meta_security': {'captcha_token': captchaToken},
      if (email != null) ...{
        'code_challenge': codeChallenge,
        'code_challenge_method': codeChallenge != null ? 's256' : null,
      },
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

    if ((response as Map).containsKey('message_id')) {
      return ResendResponse(messageId: response['message_id']);
    }
    return ResendResponse();
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
    final response = await _fetch.request(
      '$_url/user',
      RequestMethodType.put,
      options: options,
    );
    final userResponse = UserResponse.fromJson(response);

    _currentSession = currentSession?.copyWith(user: userResponse.user);
    notifyAllSubscribers(AuthChangeEvent.userUpdated);

    return userResponse;
  }

  /// Sets the session data from [refreshToken] and returns the current session.
  ///
  /// If [accessToken] is provided and not yet expired, the session is restored
  /// directly from the supplied tokens, skipping the `/token` refresh round-trip.
  Future<AuthResponse> setSession(
    String refreshToken, {
    String? accessToken,
  }) async {
    if (refreshToken.isEmpty) {
      throw AuthSessionMissingException('Refresh token cannot be empty');
    }

    if (accessToken == null) {
      return await _callRefreshToken(refreshToken);
    }

    if (accessToken.isEmpty) {
      throw AuthSessionMissingException('Access token cannot be empty');
    }

    final timeNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Throws AuthInvalidJwtException if the token is malformed.
    final decoded = decodeJwt(accessToken);
    final exp = decoded.payload.exp;
    final hasExpired =
        exp == null || exp <= timeNow + Constants.expiryMargin.inSeconds;

    if (hasExpired) {
      return await _callRefreshToken(refreshToken);
    }

    final userResponse = await getUser(accessToken);
    final user = userResponse.user;
    if (user == null) {
      throw AuthSessionMissingException();
    }

    final iat = decoded.payload.iat;
    final session = Session(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
      tokenType: 'bearer',
      expiresIn: (iat != null) ? exp - iat : null,
    );

    _saveSession(session);
    notifyAllSubscribers(AuthChangeEvent.signedIn);

    final response = AuthResponse(session: session);
    return response;
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
    if (error != null || errorDescription != null || errorCode != null) {
      throw AuthException(
        errorDescription ?? 'Error in URL with unspecified error_description',
        statusCode: errorCode,
        code: error,
      );
    }

    final authCode = url.queryParameters['code'];
    if (authCode != null) {
      return await exchangeCodeForSession(authCode);
    }

    if (_flowType == AuthFlowType.pkce &&
        !url.queryParameters.containsKey('access_token')) {
      throw AuthPKCEGrantCodeExchangeError(
        'No code detected in query parameters.',
      );
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
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) =>
      _signOut(scope: scope, reason: SignOutReason.userInitiated);

  Future<void> _signOut({
    required SignOutScope scope,
    required SignOutReason reason,
  }) async {
    _log.info('Signing out user with scope: ${scope.name}');
    final accessToken = currentSession?.accessToken;

    if (scope != SignOutScope.others) {
      _removeSession();
      await _asyncStorage?.removeItem(
        key: '${Constants.defaultStorageKey}-code-verifier',
      );
      notifyAllSubscribers(
        AuthChangeEvent.signedOut,
        signOutReason: reason,
      );
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
    final codeChallenge = await _generatePKCECodeChallenge(
      storageEventName: AuthChangeEvent.passwordRecovery.name,
    );

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
  /// [provider] is the OAuth provider
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
    final response = await _fetch.request(
      '$_url/token',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _headers,
        jwt: _currentSession?.accessToken,
        body: {
          'provider': provider.name,
          'id_token': idToken,
          'nonce': nonce,
          'gotrue_meta_security': {'captcha_token': captchaToken},
          'access_token': accessToken,
          'link_identity': true,
        },
        query: {'grant_type': 'id_token'},
      ),
    );

    final authResponse = AuthResponse.fromJson(response);

    if (authResponse.session == null) {
      throw AuthException('An error occurred on token verification.');
    }

    _saveSession(authResponse.session!);
    notifyAllSubscribers(AuthChangeEvent.userUpdated);

    return authResponse;
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
    final res = await _fetch.request(
      urlResponse.url,
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _headers,
        jwt: _currentSession?.accessToken,
      ),
    );
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
      await _signOut(
        scope: SignOutScope.local,
        reason: SignOutReason.sessionMissing,
      );
      throw notifyException(
        AuthException(
          'Initial session is missing data.',
          code: ErrorCode.sessionMissing.code,
        ),
      );
    }

    _currentSession = session;
    notifyAllSubscribers(AuthChangeEvent.initialSession);
  }

  /// Recover session from stringified [Session].
  Future<AuthResponse> recoverSession(String jsonStr) async {
    final String refreshToken;
    try {
      final session = Session.fromJson(json.decode(jsonStr));
      if (session == null) {
        _log.warning("Can't recover session from string, session is null");
        await _signOut(
          scope: SignOutScope.local,
          reason: SignOutReason.sessionMissing,
        );
        // The `catch` below notifies subscribers, so throw without notifying
        // here to avoid emitting the error onto the stream twice.
        throw AuthException(
          'Current session is missing data.',
          code: ErrorCode.sessionMissing.code,
        );
      }

      if (!session.isExpired) {
        final shouldEmitEvent =
            _currentSession == null ||
            _currentSession!.user.id != session.user.id;
        _saveSession(session);

        if (shouldEmitEvent) {
          notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);
        }

        return AuthResponse(session: session);
      }

      _log.fine('Session from recovery is expired');

      final existingSession = _currentSession;
      if (existingSession != null &&
          !existingSession.isExpired &&
          existingSession.user.id == session.user.id) {
        _log.fine('Session was already refreshed elsewhere, skipping recovery');
        return AuthResponse(session: existingSession);
      }

      final token = session.refreshToken;
      if (!_autoRefreshToken || token == null) {
        await _signOut(
          scope: SignOutScope.local,
          reason: SignOutReason.sessionExpired,
        );
        throw AuthException(
          'Session expired.',
          code: ErrorCode.sessionExpired.code,
        );
      }
      refreshToken = token;
    } catch (error, stackTrace) {
      notifyException(error, stackTrace);
      rethrow;
    }

    // Run the refresh outside the try/catch above so its error is not
    // re-notified: `_callRefreshToken` already reports the outcome (a
    // `signedOut` event for an invalid token, or a stream exception for a
    // retryable failure). The refresh resolves through a completer, so its
    // error would otherwise be rooted at `_doRefresh`; rethrowing with the
    // current stack keeps `recoverSession` and the caller in the stack trace.
    try {
      return await _callRefreshToken(refreshToken);
    } catch (error) {
      Error.throwWithStackTrace(error, StackTrace.current);
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

      // Read the session once to avoid TOCTOU: both refreshToken and
      // expiresAt must come from the same snapshot.
      final session = _currentSession;
      final refreshToken = session?.refreshToken;
      if (refreshToken == null) {
        return;
      }

      final expiresAt = session?.expiresAt;
      if (expiresAt == null) {
        return;
      }

      final expiresInTicks =
          (DateTime.fromMillisecondsSinceEpoch(
                    expiresAt * 1000,
                  ).difference(now).inMilliseconds /
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
    return await retry(
      // Make a GET request
      () async {
        attempt++;
        _log.fine('Attempt $attempt to refresh token');
        final options = GotrueRequestOptions(
          headers: _headers,
          body: {'refresh_token': refreshToken},
          query: {'grant_type': 'refresh_token'},
        );
        final response = await _fetch.request(
          '$_url/token',
          RequestMethodType.post,
          options: options,
        );
        final authResponse = AuthResponse.fromJson(response);
        return authResponse;
      },
      retryIf: (e) {
        // Do not retry if the next retry comes after the next tick.
        final nextBackOff = Duration(
          milliseconds: (200 * pow(2, attempt - 1).floor()),
        );

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
    final codeChallenge = await _generatePKCECodeChallenge();
    final urlParams = {
      'provider': provider.name,
      'scopes': ?scopes,
      'redirect_to': ?redirectTo,
      ...?queryParams,
      if (codeChallenge != null) ...{
        'flow_type': _flowType.name,
        'code_challenge': codeChallenge,
        'code_challenge_method': 's256',
      },
      if (skipBrowserRedirect) 'skip_http_redirect': 'true',
    };
    final oauthUrl = '$url?${Uri(queryParameters: urlParams).query}';
    return OAuthResponse(provider: provider, url: oauthUrl);
  }

  /// set currentSession and currentUser
  void _saveSession(Session session) {
    _log.fine('Saving session');
    _log.finest('Saving session: $session');
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

      assert(
        _broadcastChannel == null,
        'Broadcast channel should not be started more than once.',
      );
      try {
        _broadcastChannel = web.getBroadcastChannel(broadcastKey);
        _broadcastChannelSubscription = _broadcastChannel?.onMessage.listen((
          messageEvent,
        ) {
          final rawEvent = messageEvent['event'];
          _log.finest('Received broadcast message: $messageEvent');
          _log.info('Received broadcast event: $rawEvent');
          final event = switch (rawEvent) {
            // This library sends the js name of the event to be compatible with
            // the js library, so we need to convert it back to the dart name
            'INITIAL_SESSION' => AuthChangeEvent.initialSession,
            'PASSWORD_RECOVERY' => AuthChangeEvent.passwordRecovery,
            'SIGNED_IN' => AuthChangeEvent.signedIn,
            'SIGNED_OUT' => AuthChangeEvent.signedOut,
            'TOKEN_REFRESHED' => AuthChangeEvent.tokenRefreshed,
            'USER_UPDATED' => AuthChangeEvent.userUpdated,
            'MFA_CHALLENGE_VERIFIED' => AuthChangeEvent.mfaChallengeVerified,
            // This case should never happen though
            _ => AuthChangeEvent.values.firstWhereOrNull(
              (changeEvent) => changeEvent.name == rawEvent,
            ),
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
    _isDisposed = true;
    unawaited(_onAuthStateChangeController.close());
    unawaited(_onAuthStateChangeControllerSync.close());
    _broadcastChannel?.close();
    unawaited(_broadcastChannelSubscription?.cancel());
    for (final completer in _pendingRefreshes.values) {
      if (!completer.isCompleted) {
        completer.completeError(AuthException('Disposed'), StackTrace.current);
      }
    }
    _pendingRefreshes.clear();
    _autoRefreshTicker?.cancel();
  }

  /// Generates a new JWT.
  ///
  /// Concurrent calls with the **same** [refreshToken] are de-duplicated:
  /// only the first starts a network request; subsequent callers receive
  /// the same [Future].
  ///
  /// After the network round-trip, the result is only applied (session
  /// saved, [AuthChangeEvent.tokenRefreshed] emitted) when
  /// [_sessionVersion] has not changed — meaning no sign-in, sign-out,
  /// or other session mutation occurred while the request was in-flight.
  Future<AuthResponse> _callRefreshToken(String refreshToken) {
    // De-duplicate: return existing future if this token is already
    // in-flight.
    final existing = _pendingRefreshes[refreshToken];
    if (existing != null) {
      _log.finer('Refresh already pending for this token');
      return existing.future;
    }

    // The completer is kept as an external handle so [dispose] can cancel an
    // in-flight refresh: the network request itself cannot be interrupted, so
    // a hung refresh can only be resolved by completing this completer.
    final completer = Completer<AuthResponse>();
    completer.future.ignore();
    _pendingRefreshes[refreshToken] = completer;

    unawaited(
      _doRefresh(refreshToken)
          .then(
            (response) {
              if (!completer.isCompleted) completer.complete(response);
            },
            onError: (Object error, StackTrace stack) {
              if (!completer.isCompleted) completer.completeError(error, stack);
            },
          )
          .whenComplete(() => _pendingRefreshes.remove(refreshToken)),
    );

    return completer.future;
  }

  /// Performs a single token refresh, applies the outcome to the local session
  /// and notifies subscribers.
  ///
  /// Returns the refreshed [AuthResponse] or throws the underlying error. This
  /// is the single place that emits refresh outcomes: [AuthChangeEvent.tokenRefreshed]
  /// on success, [AuthChangeEvent.signedOut] when the refresh token is invalid,
  /// or a stream error ([notifyException]) for a retryable/unexpected failure.
  Future<AuthResponse> _doRefresh(String refreshToken) async {
    final versionBeforeRefresh = _sessionVersion;
    _log.fine('Refresh access token');

    try {
      final data = await _refreshAccessToken(refreshToken);

      final session = data.session;
      if (session == null) {
        throw AuthSessionMissingException();
      }

      // Discard the result if the client was disposed or the session was
      // mutated (e.g. a concurrent signIn or signOut) while we were awaiting
      // the network request, so we don't overwrite the newer session.
      if (_isDisposed || _sessionVersion != versionBeforeRefresh) {
        _log.fine('Session changed during refresh, discarding stale result.');
        return data;
      }

      _saveSession(session);
      notifyAllSubscribers(AuthChangeEvent.tokenRefreshed);
      return data;
    } on AuthException catch (error, stack) {
      final existingSession = _currentSession;
      if (error is AuthApiException &&
          error.code == 'refresh_token_already_used' &&
          existingSession != null &&
          !existingSession.isExpired) {
        _log.fine(
          'Refresh token already used but current session is still '
          'valid, returning it instead of signing out',
        );
        return AuthResponse(session: existingSession);
      }

      if (error is! AuthRetryableFetchException) {
        // Only remove the session if it hasn't been replaced while we were
        // refreshing, otherwise we'd sign out a user who just signed in.
        if (!_isDisposed && _sessionVersion == versionBeforeRefresh) {
          _removeSession();
          notifyAllSubscribers(
            AuthChangeEvent.signedOut,
            signOutReason: SignOutReason.sessionExpired,
          );
        }
      } else if (!_isDisposed) {
        notifyException(error, stack);
      }
      rethrow;
    } catch (error, stack) {
      if (!_isDisposed) {
        notifyException(error, stack);
      }
      rethrow;
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
    SignOutReason? signOutReason,
  }) {
    session ??= currentSession;
    if (broadcast && event != AuthChangeEvent.initialSession) {
      _broadcastChannel?.postMessage({
        'event': event.jsName,
        'session': session?.toJson(),
      });
    }
    final state = AuthState(
      event,
      session,
      fromBroadcast: !broadcast,
      signOutReason: signOutReason,
    );
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

  Future<JWK?> _fetchJwk(String kid, JWKSet suppliedJwks) async {
    // try fetching from the supplied jwks
    final jwk = suppliedJwks.keys.firstWhereOrNull((key) => key.kid == kid);
    if (jwk != null) {
      return jwk;
    }

    final now = DateTime.now();

    // try fetching from cache
    final cachedJwk = _jwks?.keys.firstWhereOrNull((key) => key.kid == kid);

    // jwks exists and it isn't stale
    if (cachedJwk != null &&
        _jwksCachedAt != null &&
        _jwksCachedAt!.add(Constants.jwksTtl).isAfter(now)) {
      return cachedJwk;
    }

    // jwk isn't cached in memory so we need to fetch it from the well-known endpoint
    final jwksResponse = await _fetch.request(
      '$_url/.well-known/jwks.json',
      RequestMethodType.get,
      options: GotrueRequestOptions(headers: _headers),
    );

    final jwks = JWKSet.fromJson(jwksResponse as Map<String, dynamic>);

    if (jwks.keys.isEmpty) {
      return null;
    }

    _jwks = jwks;
    _jwksCachedAt = now;

    // find the signing key
    return jwks.keys.firstWhereOrNull((key) => key.kid == kid);
  }

  /// Extracts the JWT claims present in the access token by first verifying the
  /// JWT against the server's JSON Web Key Set endpoint
  /// `/.well-known/jwks.json` which is often cached, resulting in significantly
  /// faster responses. Prefer this method over [getUser] which always
  /// sends a request to the Auth server for each JWT.
  ///
  /// If the project is not using an asymmetric JWT signing key (like ECC or
  /// RSA) it always sends a request to the Auth server (similar to [getUser]) to verify the JWT.
  ///
  /// For JWTs signed with asymmetric algorithms (RS256, ES256, etc.), the JWKS
  /// is fetched from the server on the first call and cached for subsequent calls.
  /// The cache is refreshed automatically after 10 minutes.
  ///
  /// [jwt] An optional specific JWT you wish to verify, not the one you
  ///       can obtain from [currentSession].
  /// [options] Various additional options that allow you to customize the
  ///           behavior of this method.
  ///
  /// Returns a [GetClaimsResponse] containing the JWT claims, or throws an [AuthException] on error.
  Future<GetClaimsResponse> getClaims([
    String? jwt,
    GetClaimsOptions? options,
  ]) async {
    String token = jwt ?? '';

    if (token.isEmpty) {
      final session = currentSession;
      if (session == null) {
        throw AuthSessionMissingException('No session found');
      }
      token = session.accessToken;
    }

    // Decode the JWT to get the payload
    final decoded = decodeJwt(token);

    // Validate expiration unless allowExpired is true
    if (!(options?.allowExpired ?? false)) {
      validateExp(decoded.payload.exp);
    }

    final signingKey =
        (decoded.header.alg.startsWith('HS') || decoded.header.kid == null)
        ? null
        : await _fetchJwk(decoded.header.kid!, _jwks ?? JWKSet(keys: []));

    // If symmetric algorithm, fallback to getUser()
    if (signingKey == null) {
      await getUser(token);
      return GetClaimsResponse(
        claims: decoded.payload,
        header: decoded.header,
        signature: decoded.signature,
      );
    }

    try {
      JWT.verify(token, signingKey.publicKey);
      return GetClaimsResponse(
        claims: decoded.payload,
        header: decoded.header,
        signature: decoded.signature,
      );
    } catch (e) {
      throw AuthInvalidJwtException('Invalid JWT signature: $e');
    }
  }
}
