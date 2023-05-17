enum Provider {
  apple,
  azure,
  bitbucket,
  discord,
  facebook,
  github,
  gitlab,
  google,
  kakao,
  keycloak,
  linkedin,
  notion,
  slack,
  spotify,
  twitch,
  twitter,
  workos,
  kakao
}

extension ProviderName on Provider {
  String get name {
    return toString().split('.').last;
  }
}
