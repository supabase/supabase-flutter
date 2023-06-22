// ignore_for_file: require_trailing_commas
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:supabase_flutter/src/providers/oauth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _provider = Provider.facebook;

/// If authenticating with Facebook via a 3rd party, use the returned
/// `accessToken` to sign-in or link the user with the created credential,
/// for example:
///
/// ```dart
/// String accessToken = '...'; // From 3rd party provider
/// var facebookAuthCredential = FacebookAuthProvider.credential(accessToken);
///
/// Supabase.instance.client.auth.signInWithCredential(facebookAuthCredential)
///   .then(...);
/// ```
///

class FacebookAuthProvider extends AuthProvider {
  /// Creates a new instance.
  FacebookAuthProvider() : super(_provider);

  /// Create a new [FacebookAuthCredential] from a provided [accessToken];
  static OAuthCredential credential(String accessToken) {
    return FacebookAuthCredential._credential(
      accessToken,
    );
  }
}

/// The auth credential returned from calling
/// [FacebookAuthProvider.credential].
class FacebookAuthCredential extends OAuthCredential {
  FacebookAuthCredential._({
    required String accessToken,
  }) : super(
          provider: _provider,
          accessToken: accessToken,
        );

  factory FacebookAuthCredential._credential(String accessToken) {
    return FacebookAuthCredential._(
      accessToken: accessToken,
    );
  }
}
