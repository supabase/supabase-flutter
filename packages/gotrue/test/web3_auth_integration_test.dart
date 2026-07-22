import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

import 'utils.dart';

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

String _base58Encode(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }

  final result = StringBuffer();
  final radix = BigInt.from(58);
  while (value > BigInt.zero) {
    result.write(_base58Alphabet[(value % radix).toInt()]);
    value = value ~/ radix;
  }

  for (final byte in bytes) {
    if (byte != 0) break;
    result.write('1');
  }

  return String.fromCharCodes(result.toString().codeUnits.reversed);
}

void main() {
  final env = DotEnv()..load();
  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://127.0.0.1:54421/auth/v1';
  final anonToken = env['GOTRUE_TOKEN'] ?? getAnonToken(env);
  final ed25519 = Ed25519();

  late GoTrueClient client;

  setUp(() {
    client = GoTrueClient(
      url: gotrueUrl,
      headers: {'Authorization': 'Bearer $anonToken', 'apikey': anonToken},
      asyncStorage: TestAsyncStorage(),
    );
  });

  tearDown(() {
    client.dispose();
  });

  Future<({String message, String signature})> signSolanaMessage() async {
    final keyPair = await ed25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final address = _base58Encode(publicKey.bytes);
    final issuedAt = DateTime.now().toUtc().toIso8601String();

    final message =
        'localhost:9999 wants you to sign in with your Solana account:\n'
        '$address\n'
        '\n'
        'Version: 1\n'
        'URI: http://localhost:9999/welcome\n'
        'Issued At: $issuedAt';

    final signature = await ed25519.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );

    return (message: message, signature: base64Url.encode(signature.bytes));
  }

  group('signInWithWeb3 against a live GoTrue', () {
    test('signs in with a valid Solana signature', () async {
      final signed = await signSolanaMessage();

      final events = <AuthChangeEvent>[];
      client.onAuthStateChange.listen(
        (state) => events.add(state.event),
        onError: (_) {},
      );

      final response = await client.signInWithWeb3(
        chain: Web3Chain.solana,
        message: signed.message,
        signature: signed.signature,
      );

      expect(response.session, isNotNull);
      expect(response.session?.accessToken, isNotEmpty);
      expect(response.user?.appMetadata['provider'], 'web3');
      expect(client.currentSession?.accessToken, response.session?.accessToken);

      await Future<void>.delayed(Duration.zero);
      expect(events, contains(AuthChangeEvent.signedIn));
    });

    test('rejects a signature that does not match the message', () async {
      final signed = await signSolanaMessage();
      final other = await signSolanaMessage();

      await expectLater(
        client.signInWithWeb3(
          chain: Web3Chain.solana,
          message: signed.message,
          signature: other.signature,
        ),
        throwsA(isA<AuthApiException>()),
      );
    });
  });
}
