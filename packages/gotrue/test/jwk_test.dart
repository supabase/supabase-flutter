import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:gotrue/src/types/jwt.dart';
import 'package:test/test.dart';

void main() {
  group('JWK.publicKey', () {
    // Regression test: previously the getter passed the JWK JSON to a DER
    // parser, which threw UnsupportedASN1TagException, breaking getClaims for
    // asymmetric (RS256) signing keys, the default for the local Supabase CLI
    // stack.
    test('builds an RSA public key from an RSA JWK', () {
      final jwk = JWK.fromJson({
        'kty': 'RSA',
        'alg': 'RS256',
        'kid': 'rsa-test',
        'use': 'sig',
        'n':
            't0XB0gQ32Obq7f-L1rZiBTnJvIGfDV4TqGif43rC6Y0hvGFfEPlWnz6M0jbLEK-v0tTXDGbG-EMS3r_bCtm-ZuF4eyfZvWw9DRjQG7D4MPoRmjyKZ8xgpkzgEJLQB7dCuI8xvm1Hh38eiRk1Kb_tSsaZ9Yd7ppibJpcxu_lI_FaKE7RT6CjW8u6nvolrNXlhL_4qPeoy_sRg7uIC7LgOXVwh73-0lq4DVtDMVkJG-WJ0v4ljAzyt_Sl2c7ag1HKhCWxo5HBdp0gzeWnuotOT0zPAwR_5cJuW7VWHjecwfnWbgDXZNb_BMGOnT64dwzClCeh2VcZDYHa0o4w5FHClUw',
        'e': 'AQAB',
      });

      expect(jwk.publicKey, isA<RSAPublicKey>());
    });
  });
}
