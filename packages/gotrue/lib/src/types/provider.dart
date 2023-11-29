enum Provider {
  apple,
  azure,
  bitbucket,
  discord,
  facebook,
  figma,
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
}

extension ProviderName on Provider {
  String get name {
    return toString().split('.').last;
  }
}
