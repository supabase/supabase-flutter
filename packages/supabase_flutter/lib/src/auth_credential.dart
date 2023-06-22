// ignore_for_file: require_trailing_commas
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Interface that represents the credentials returned by an auth provider.
/// Implementations specify the details about each auth provider's credential
/// requirements.
class AuthCredential {
  // ignore: public_member_api_docs
  @protected
  const AuthCredential({
    required this.provider,
    this.idToken,
    this.accessToken,
  });

  /// The authentication provider for the credential. For example,
  /// 'facebook', or 'google'.
  final Provider provider;

  final String? idToken;
  final String? accessToken;

  /// Returns the current instance as a serialized [Map].
  Map<String, dynamic> asMap() {
    return <String, dynamic>{
      'provider': provider.name,
      'idToken': idToken,
      'accessToken': accessToken,
    };
  }

  @override
  String toString() =>
      'AuthCredential(providerId: ${provider.index}, idToken: $idToken, accessToken: $accessToken)';
}
