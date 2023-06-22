// ignore_for_file: require_trailing_commas
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A generic OAuth credential.
///
/// This class is extended by other OAuth based credentials, or can be returned
/// when generating credentials from 3rd party OAuth providers.
class OAuthCredential extends AuthCredential {
  // ignore: public_member_api_docs
  @protected
  const OAuthCredential({
    required Provider provider,
    String? accessToken,
    this.idToken,
    this.secret,
  }) : super(
          provider: provider,
          accessToken: accessToken,
        );

  /// The OAuth ID token associated with the credential if it belongs to an
  /// OIDC provider, such as `google.com`.
  final String? idToken;

  /// The OAuth access token secret associated with the credential if it belongs
  /// to an OAuth 1.0 provider, such as `twitter.com`.
  final String? secret;

  @override
  Map<String, String?> asMap() {
    return <String, String?>{
      'provider': provider.name,
      'idToken': idToken,
      'accessToken': accessToken,
      'secret': secret,
    };
  }
}
