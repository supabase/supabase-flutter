typedef BroadcastChannel = ({
  Stream<Map<String, dynamic>> onMessage,
  void Function(Map) postMessage,
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
  slackOidc,
  spotify,
  twitch,
  twitter,
  workos,
  zoom,
}
