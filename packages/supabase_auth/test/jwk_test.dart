import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:supabase_auth/src/types/jwt.dart';
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
            't0XB0gQ32Obq7f-L1rZiBTnJvIGfDV4TqGif43rC6Y0hvGFfEPlWnz6M0jbLEK-v0t'
            'TXDGbG-EMS3r_bCtm-ZuF4eyfZvWw9DRjQG7D4MPoRmjyKZ8xgpkzgEJLQB7dCuI8x'
            'vm1Hh38eiRk1Kb_tSsaZ9Yd7ppibJpcxu_lI_FaKE7RT6CjW8u6nvolrNXlhL_4qPe'
            'oy_sRg7uIC7LgOXVwh73-0lq4DVtDMVkJG-WJ0v4ljAzyt_Sl2c7ag1HKhCWxo5HBd'
            'p0gzeWnuotOT0zPAwR_5cJuW7VWHjecwfnWbgDXZNb_BMGOnT64dwzClCeh2VcZDYH'
            'a0o4w5FHClUw',
        'e': 'AQAB',
      });

      expect(jwk.publicKey, isA<RSAPublicKey>());
    });

    test('builds an EC public key from an EC JWK', () {
      final jwk = JWK.fromJson({
        'kty': 'EC',
        'alg': 'ES256',
        'kid': 'ec-test',
        'use': 'sig',
        'crv': 'P-256',
        'x': 'gctse0odNml3G63HfU7BIZ4zOY3PrcwlC70031KGnwo',
        'y': 'k_uxFaLt2Ad5gueJZGnzKBIid6mxfJYqjXssxE1vORA',
      });

      expect(jwk.publicKey, isA<ECPublicKey>());
    });
  });
}
