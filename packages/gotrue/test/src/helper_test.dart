import 'package:gotrue/src/helper.dart';
import 'package:test/test.dart';

void main() {
  test(
      'PKCE code verifier only contains alphanumeric characters, hyphens, periods, underscores and tildes',
      () {
    final codeVerifier = generatePKCEVerifier();
    final codeChallenge = generatePKCEChallenge(codeVerifier);
    final regex = RegExp(r'^[A-Za-z0-9-~_]*$');
    expect(regex.hasMatch(codeChallenge), true,
        reason:
            'codeChallenge was "$codeChallenge", which contains characters that are not alphanumeric characters, hyphens, periods, underscores or tildes.');
  });
}
