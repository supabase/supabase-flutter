import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

void main() {
  test('ErrorCode.emailAddressInvalid maps to its wire value', () {
    expect(ErrorCode.emailAddressInvalid.code, 'email_address_invalid');
    expect(
      ErrorCode.fromCode('email_address_invalid'),
      ErrorCode.emailAddressInvalid,
    );
  });
}
