import 'package:meta/meta.dart';

/// What a channel does after the server answered its join with an error.
@internal
enum JoinRecovery {
  /// Retrying as is cannot succeed, so the channel stops rejoining.
  fail,

  /// A fresh access token can fix it, so the channel refreshes the token and
  /// rejoins once.
  refreshToken,

  /// The server applied a rate limit, so the channel waits the long rejoin
  /// delay.
  backOff,

  /// The channel rejoins after the next step of the rejoin backoff.
  retry;

  /// Classifies a join error [reason], `<code>: <message>` or one of the bare
  /// strings the server sends without a code.
  ///
  /// The server's catalog at
  /// https://github.com/supabase/realtime/blob/main/ERROR_CODES.md does not
  /// say which codes are permanent, so a code is fatal here when the server
  /// would give the same answer on a retry.
  static JoinRecovery classify(String reason) {
    final code = joinErrorCode(reason);
    if (code != null) {
      if (code == 'InvalidJWTToken' && reason.contains('expired')) {
        return refreshToken;
      }
      if (_fatalCodes.contains(code)) {
        return fail;
      }
      if (_rateLimitCodes.contains(code)) {
        return backOff;
      }
      return retry;
    }
    if (reason.contains('Token has expired')) {
      return refreshToken;
    }
    if ((reason.contains('Too many') && reason.contains('per second')) ||
        reason.contains('rate limit')) {
      return backOff;
    }
    if (reason.contains('You no longer have permission')) {
      return fail;
    }
    return retry;
  }

  static const _fatalCodes = {
    'TopicNameRequired',
    'MalformedJWT',
    'JwtSignatureError',
    'JwtSignerError',
    'InvalidJWTToken',
    'Unauthorized',
    'PrivateOnly',
    'TenantNotFound',
    'RealtimeDisabledForTenant',
    'RealtimeDisabledForConfiguration',
    'UnableToReplayMessages',
  };

  static const _rateLimitCodes = {
    'ChannelRateLimitReached',
    'ConnectionRateLimitReached',
    'ClientJoinRateLimitReached',
    'DatabaseConnectionRateLimitReached',
  };
}

/// The code in front of the first `:` of a join error [reason], or `null` for
/// the reasons the server sends without one. A prefix with whitespace is
/// prose, not a code.
@internal
String? joinErrorCode(String reason) {
  final separator = reason.indexOf(':');
  if (separator <= 0) {
    return null;
  }
  final prefix = reason.substring(0, separator).trim();
  return prefix.isEmpty || prefix.contains(_whitespace) ? null : prefix;
}

final _whitespace = RegExp(r'\s');
