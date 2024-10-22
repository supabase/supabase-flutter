import 'package:gotrue/src/types/user_attributes.dart';
import 'package:test/test.dart';

void main() {
  late String email;
  late String phone;
  late String password;
  late String nonce;
  late Map<String, dynamic> data;

  setUp(() {
    email = 'john@supabase.com';
    phone = '+1234567890';
    password = 'password';
    nonce = 'nonce';
    data = {'first_name': 'John', 'last_name': 'Doe'};
  });

  group('User attributes', () {
    late UserAttributes userAttributesOne;
    late UserAttributes userAttributesTwo;

    setUp(() {
      userAttributesOne = UserAttributes(
        email: email,
        phone: phone,
        password: password,
        nonce: nonce,
        data: data,
      );

      userAttributesTwo = UserAttributes(
        email: email,
        phone: phone,
        password: password,
        nonce: nonce,
        data: data,
      );
    });

    test('Attributes are equals', () {
      // assert
      expect(userAttributesOne, equals(userAttributesTwo));
    });

    test('Attributes are not equals', () {
      // arrange
      final userAttributesThree = UserAttributes(
        email: 'email',
        phone: phone,
        password: password,
        nonce: nonce,
        data: {'first_name': 'Jane', 'last_name': 'Doe'},
      );

      // assert
      expect(userAttributesOne, isNot(equals(userAttributesThree)));
    });
  });

  group('Admin user attributes', () {
    late AdminUserAttributes adminUserAttributesOne;
    late AdminUserAttributes adminUserAttributesTwo;

    late Map<String, dynamic> userMetadata;
    late Map<String, dynamic> appMetadata;
    late bool emailConfirm;
    late bool phoneConfirm;
    late String banDuration;

    setUp(() {
      userMetadata = {'first_name': 'John', 'last_name': 'Doe'};
      appMetadata = {
        'roles': ['admin']
      };
      emailConfirm = true;
      phoneConfirm = true;
      banDuration = '1d';

      adminUserAttributesOne = AdminUserAttributes(
        email: email,
        phone: phone,
        password: password,
        data: data,
        userMetadata: userMetadata,
        appMetadata: appMetadata,
        emailConfirm: emailConfirm,
        phoneConfirm: phoneConfirm,
        banDuration: banDuration,
      );

      adminUserAttributesTwo = AdminUserAttributes(
        email: email,
        phone: phone,
        password: password,
        data: data,
        userMetadata: userMetadata,
        appMetadata: appMetadata,
        emailConfirm: emailConfirm,
        phoneConfirm: phoneConfirm,
        banDuration: banDuration,
      );
    });

    test('Attributes are equals', () {
      // assert
      expect(adminUserAttributesOne, equals(adminUserAttributesTwo));
    });

    test('Attributes are not equals', () {
      // arrange
      final adminUserAttributesThree = AdminUserAttributes(
        email: email,
        phone: phone,
        password: password,
        data: data,
        userMetadata: {'first_name': 'Jane', 'last_name': 'Doe'},
        appMetadata: appMetadata,
        emailConfirm: false,
        phoneConfirm: false,
        banDuration: 'banDuration',
      );

      // assert
      expect(adminUserAttributesOne, isNot(equals(adminUserAttributesThree)));
    });
  });
}
