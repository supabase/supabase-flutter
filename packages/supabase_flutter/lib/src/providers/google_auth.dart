// ignore_for_file: require_trailing_commas
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:supabase_flutter/src/providers/oauth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _provider = Provider.google;

/// If authenticating with Google via a 3rd party, use the returned
/// `accessToken` to sign-in or link the user with the created credential,
/// for example:
///
/// ```dart
/// String accessToken = '...'; // From 3rd party provider
/// var googleAuthCredential = GoogleAuthProvider.credential(idToken, accessToken);
///
/// Supabase.instance.client.auth.signInWithCredential(googleAuthCredential)
///   .then(...);
/// ```
///```
class GoogleAuthProvider extends AuthProvider {
  /// Creates a new instance.
  GoogleAuthProvider() : super(_provider);

  /// Create a new [GoogleAuthCredential] from a provided [idToken, accessToken].
  static OAuthCredential credential({String? idToken, String? accessToken}) {
    assert(accessToken != null || idToken != null,
        'At least one of ID token and access token is required');
    return GoogleAuthCredential._credential(
      idToken: idToken,
      accessToken: accessToken,
    );
  }
}

/// The auth credential returned from calling
/// [GoogleAuthProvider.credential].
class GoogleAuthCredential extends OAuthCredential {
  GoogleAuthCredential._({
    String? accessToken,
    String? idToken,
  }) : super(
          provider: _provider,
          signInMethod: _provider.name,
          accessToken: accessToken,
          idToken: idToken,
        );

  factory GoogleAuthCredential._credential({
    String? idToken,
    String? accessToken,
  }) {
    return GoogleAuthCredential._(
      accessToken: accessToken,
      idToken: idToken,
    );
  }
}
