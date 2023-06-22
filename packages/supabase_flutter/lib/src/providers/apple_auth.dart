// ignore_for_file: require_trailing_commas
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:supabase_flutter/src/providers/oauth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _provider = Provider.apple;

/// If authenticating with Apple via a 3rd party, use the returned
/// `accessToken` to sign-in or link the user with the created credential,
/// for example:
///
/// ```dart
/// String accessToken = '...'; // From 3rd party provider
/// var appleAuthCredential = AppleAuthProvider.credential(identityToken, authorizationCode);
///
/// Supabase.instance.client.auth.signInWithCredential(appleAuthCredential)
///   .then(...);
/// ```
///

class AppleAuthProvider extends AuthProvider {
  /// Creates a new instance.
  AppleAuthProvider() : super(_provider);

  /// Create a new [AppleAuthCredential] from a provided [identityToken, authorizationCode];
  static OAuthCredential credential(
      String identityToken, String authorizationCode) {
    return AppleAuthCredential._credential(
      identityToken,
      authorizationCode,
    );
  }
}

/// The auth credential returned from calling
/// [AppleAuthProvider.credential].
class AppleAuthCredential extends OAuthCredential {
  AppleAuthCredential._({
    required String idToken,
    required String accessToken,
  }) : super(
          provider: _provider,
          idToken: idToken,
        );

  factory AppleAuthCredential._credential(
      String idToken, String authorizationCode) {
    return AppleAuthCredential._(
      idToken: idToken,
      accessToken: authorizationCode,
    );
  }
}
