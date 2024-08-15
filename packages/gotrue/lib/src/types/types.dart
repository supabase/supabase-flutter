typedef BroadcastChannel = ({
  Stream<String> onMessage,
  void Function(String) postMessage,
  void Function() close,
});

enum AuthFlowType {
  implicit,
  pkce,
}

enum OAuthProvider {
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
  linkedinOidc,
  notion,
  slack,
  spotify,
  twitch,
  twitter,
  workos,
  zoom,
}
