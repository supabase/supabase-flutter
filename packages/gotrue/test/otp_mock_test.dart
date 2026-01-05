import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

import 'mocks/otp_mock_client.dart';
import 'utils.dart';

void main() {
  const testPhone = '+11234567890';
  const testEmail = 'test@example.com';
  const testUserId = 'mock-user-id-123';
  const testPassword = 'password123';

  group('Basic OTP and Phone Authentication', () {
    late GoTrueClient client;
    late OtpMockClient mockClient;
    late TestAsyncStorage asyncStorage;

    setUp(() {
      mockClient = OtpMockClient(
        phoneNumber: testPhone,
        email: testEmail,
        userId: testUserId,
      );

      asyncStorage = TestAsyncStorage();

      client = GoTrueClient(
        url: 'https://example.com',
        httpClient: mockClient,
        asyncStorage: asyncStorage,
      );
    });

    test('signInWithOtp() with phone number', () async {
      await client.signInWithOtp(phone: testPhone);
      // This test passes if no exceptions are thrown
      expect(client.currentSession,
          isNull); // No session should be set yet as OTP is not verified
    });

    test('signInWithOtp() with email', () async {
      await client.signInWithOtp(email: testEmail);
      // This test passes if no exceptions are thrown
      expect(client.currentSession,
          isNull); // No session should be set yet as OTP is not verified
    });

    test('signInWithOtp() with phone number and custom data', () async {
      await client.signInWithOtp(
        phone: testPhone,
        shouldCreateUser: true,
        data: {'name': 'Test User'},
      );
      // This test passes if no exceptions are thrown
      expect(client.currentSession,
          isNull); // No session should be set yet as OTP is not verified
    });

    test('signInWithOtp() without email or phone should throw', () async {
      try {
        await client.signInWithOtp();
        fail('Should have thrown an exception');
      } on AuthException catch (e) {
        expect(e.message,
            contains('You must provide either an email, phone number'));
      }
    });

    test('verifyOTP() with phone number', () async {
      final response = await client.verifyOTP(
        phone: testPhone,
        token: '123456',
        type: OtpType.sms,
      );

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);
      expect(response.user?.phone, testPhone);

      // Verify session was set
      expect(client.currentSession, isNotNull);
      expect(client.currentUser, isNotNull);
      expect(client.currentUser?.phone, testPhone);
    });

    test('verifyOTP() with email', () async {
      final response = await client.verifyOTP(
        email: testEmail,
        token: '123456',
        type: OtpType.email,
      );

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);
      expect(response.user?.email, testEmail);

      // Verify session was set
      expect(client.currentSession, isNotNull);
      expect(client.currentUser, isNotNull);
      expect(client.currentUser?.email, testEmail);
    });

    test('verifyOTP() with recovery type', () async {
      final response = await client.verifyOTP(
        email: testEmail,
        token: '123456',
        type: OtpType.recovery,
      );

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);

      // Verify session was set
      expect(client.currentSession, isNotNull);
      expect(client.currentUser, isNotNull);
    });

    test('verifyOTP() with tokenHash', () async {
      final response = await client.verifyOTP(
        tokenHash: 'mock-token-hash',
        token: '123456',
        type: OtpType.email,
      );

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);

      // Verify session was set
      expect(client.currentSession, isNotNull);
      expect(client.currentUser, isNotNull);
    });

    test('verifyOTP() with recovery type and tokenHash', () async {
      // Recovery type with tokenHash should only include tokenHash and type
      final response = await client.verifyOTP(
        tokenHash: 'mock-token-hash',
        type: OtpType.recovery,
      );

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);

      // Verify session was set
      expect(client.currentSession, isNotNull);
      expect(client.currentUser, isNotNull);
    });

    test(
        'verifyOTP() with recovery type and tokenHash should reject email/phone',
        () async {
      // Recovery type with tokenHash should not accept email/phone
      try {
        await client.verifyOTP(
          email: testEmail,
          tokenHash: 'mock-token-hash',
          type: OtpType.recovery,
        );
        fail('Should have thrown an assertion error');
      } catch (e) {
        expect(e, isA<AssertionError>());
        expect(
            e.toString(),
            contains(
                'For recovery type with tokenHash, only tokenHash and type should be provided'));
      }
    });

    test('verifyOTP() without token should throw', () async {
      try {
        await client.verifyOTP(
          email: testEmail,
          type: OtpType.email,
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<AssertionError>());
      }
    });

    test('signUp() with phone number', () async {
      final response = await client.signUp(
        phone: testPhone,
        password: testPassword,
        data: {'name': 'Test User'},
      );

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);
      expect(response.user?.phone, testPhone);
      expect(response.user?.userMetadata?['name'], 'Test User');

      // Verify session was set
      expect(client.currentSession, isNotNull);
      expect(client.currentUser, isNotNull);
      expect(client.currentUser?.phone, testPhone);
    });

    test('signUp() with phone number and specific channel', () async {
      final response = await client.signUp(
        phone: testPhone,
        password: testPassword,
        channel: OtpChannel.whatsapp,
      );

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);
    });

    test('signInWithPassword() with phone number', () async {
      final response = await client.signInWithPassword(
        phone: testPhone,
        password: testPassword,
      );

      expect(response.session, isNotNull);
      expect(response.user, isNotNull);
      expect(response.user?.phone, testPhone);

      // Verify session was set
      expect(client.currentSession, isNotNull);
      expect(client.currentUser, isNotNull);
      expect(client.currentUser?.phone, testPhone);
    });

    test('reauthenticate() works correctly', () async {
      // First sign in to set the session
      await client.signInWithPassword(
        phone: testPhone,
        password: testPassword,
      );

      // Then reauthenticate
      await client.reauthenticate();
      // This test passes if no exceptions are thrown
    });

    test('reauthenticate() throws when no session', () async {
      try {
        await client.reauthenticate();
        fail('Should have thrown an exception');
      } on AuthSessionMissingException catch (_) {
        // Expected exception
      }
    });

    test('resend() with phone type', () async {
      final response = await client.resend(
        phone: testPhone,
        type: OtpType.sms,
      );

      expect(response, isA<ResendResponse>());
    });

    test('resend() with email type', () async {
      final response = await client.resend(
        email: testEmail,
        type: OtpType.signup,
      );

      expect(response, isA<ResendResponse>());
    });

    test('resend() with phone_change type', () async {
      final response = await client.resend(
        phone: testPhone,
        type: OtpType.phoneChange,
      );

      expect(response, isA<ResendResponse>());
    });

    test('resend() with email_change type', () async {
      final response = await client.resend(
        email: testEmail,
        type: OtpType.emailChange,
      );

      expect(response, isA<ResendResponse>());
    });

    test('resend() with wrong type for phone throws', () async {
      try {
        await client.resend(
          phone: testPhone,
          type: OtpType.signup, // This should be sms or phoneChange for phone
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<AssertionError>());
      }
    });

    test('resend() with wrong type for email throws', () async {
      try {
        await client.resend(
          email: testEmail,
          type: OtpType.sms, // This should be signup or emailChange for email
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<AssertionError>());
      }
    });

    test('signInWithOtp() with different channel types', () async {
      // Test WhatsApp channel
      await client.signInWithOtp(
        phone: testPhone,
        channel: OtpChannel.whatsapp,
      );

      // Test SMS channel (default)
      await client.signInWithOtp(
        phone: testPhone,
        channel: OtpChannel.sms,
      );
    });
  });

  group('OTP Edge Cases and Error Conditions', () {
    test('verifyOTP() with invalid OTP throws AuthException', () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: ErrorMockClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.verifyOTP(
          phone: testPhone,
          token: '123456',
          type: OtpType.sms,
        );
        fail('Should have thrown an exception');
      } on AuthException catch (e) {
        expect(e.message, 'The OTP provided is invalid or has expired');
      }
    });

    test(
        'signInWithPassword() with phone and wrong password throws AuthException',
        () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: ConditionalErrorClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.signInWithPassword(
          phone: testPhone,
          password: 'wrong-password',
        );
        fail('Should have thrown an exception');
      } on AuthException catch (e) {
        expect(e.message, 'Invalid login credentials');
      }
    });

    test('signUp() with existing phone number throws AuthException', () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: ConditionalErrorClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.signUp(
          phone: testPhone,
          password: testPassword,
        );
        fail('Should have thrown an exception');
      } on AuthException catch (e) {
        expect(e.message, 'Phone number is already registered');
      }
    });

    test('signInWithOtp() with empty response', () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: EmptyResponseClient(),
        asyncStorage: TestAsyncStorage(),
      );

      // Should not throw an exception
      await client.signInWithOtp(phone: testPhone);
    });

    test('verifyOTP() with neither email nor phone throws assertion error',
        () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: EmptyResponseClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.verifyOTP(
          token: '123456',
          type: OtpType.sms,
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<AssertionError>());
      }
    });

    test('verifyOTP() with expired token throws AuthException', () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: ConditionalErrorClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.verifyOTP(
          phone: testPhone,
          token: '123456',
          type: OtpType.sms,
        );
        fail('Should have thrown an exception');
      } on AuthException catch (e) {
        expect(e.message, 'The OTP has expired');
      }
    });

    test('resend() with both email and phone throws assertion error', () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: EmptyResponseClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.resend(
          email: testEmail,
          phone: testPhone,
          type: OtpType.sms,
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<AssertionError>());
      }
    });

    test('signUp() without email or phone throws exception', () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: EmptyResponseClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.signUp(password: testPassword);
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<AssertionError>());
      }
    });

    test('signInWithPassword() without email or phone throws exception',
        () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: EmptyResponseClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.signInWithPassword(password: testPassword);
        fail('Should have thrown an exception');
      } on AuthException catch (e) {
        expect(e.message.contains('You must provide either an'), isTrue);
      }
    });

    test('empty response on server error', () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: CustomServerErrorClient(),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.signInWithOtp(phone: testPhone);
        fail('Should have thrown an exception');
      } on AuthException catch (e) {
        expect(e.statusCode, '500');
      }
    });

    test('response with null session', () async {
      final client = GoTrueClient(
        url: 'https://example.com',
        httpClient: NullSessionClient(testEmail),
        asyncStorage: TestAsyncStorage(),
      );

      try {
        await client.verifyOTP(
          email: testEmail,
          token: '123456',
          type: OtpType.email,
        );
        fail('Should have thrown an exception');
      } on AuthException catch (e) {
        expect(e.message, 'An error occurred on token verification.');
      }
    });
  });

  group('Channel Types Tests', () {
    late GoTrueClient client;
    late ChannelMockClient mockClient;
    late TestAsyncStorage asyncStorage;

    setUp(() {
      mockClient = ChannelMockClient();
      asyncStorage = TestAsyncStorage();

      client = GoTrueClient(
        url: 'https://example.com',
        httpClient: mockClient,
        asyncStorage: asyncStorage,
      );
    });

    test('signInWithOtp() uses sms channel by default', () async {
      await client.signInWithOtp(phone: testPhone);
      expect(mockClient.lastChannelUsed, 'sms');
    });

    test('signInWithOtp() with whatsapp channel', () async {
      await client.signInWithOtp(
        phone: testPhone,
        channel: OtpChannel.whatsapp,
      );
      expect(mockClient.lastChannelUsed, 'whatsapp');
    });

    test('signUp() with whatsapp channel', () async {
      await client.signUp(
        phone: testPhone,
        password: testPassword,
        channel: OtpChannel.whatsapp,
      );
      expect(mockClient.lastChannelUsed, 'whatsapp');
    });

    test('signUp() uses sms channel by default', () async {
      await client.signUp(
        phone: testPhone,
        password: testPassword,
      );
      expect(mockClient.lastChannelUsed, 'sms');
    });

    test('resend() with sms type sets channel to sms', () async {
      await client.resend(
        phone: testPhone,
        type: OtpType.sms,
      );
      expect(mockClient.lastRequestBody?['type'], 'sms');
    });

    test('resend() with phone_change type sets correct type', () async {
      await client.resend(
        phone: testPhone,
        type: OtpType.phoneChange,
      );
      expect(mockClient.lastRequestBody?['type'], 'phone_change');
    });

    test('OtpChannel enum converts to correct string values', () {
      // Test enum conversion to string
      expect(OtpChannel.sms.name, 'sms');
      expect(OtpChannel.whatsapp.name, 'whatsapp');

      // Test that the enum is used correctly in the request
      client.signInWithOtp(
        phone: testPhone,
        channel: OtpChannel.whatsapp,
      );
      expect(mockClient.lastChannelUsed, 'whatsapp');

      client.signInWithOtp(
        phone: testPhone,
        channel: OtpChannel.sms,
      );
      expect(mockClient.lastChannelUsed, 'sms');
    });

    test('OtpType enum is used correctly in requests', () async {
      // Test enum representation in API calls
      await client.verifyOTP(
        phone: testPhone,
        token: '123456',
        type: OtpType.sms,
      );
      expect(mockClient.lastRequestBody?['type'], 'sms');

      await client.verifyOTP(
        phone: testPhone,
        token: '123456',
        type: OtpType.recovery,
      );
      expect(mockClient.lastRequestBody?['type'], 'recovery');

      await client.verifyOTP(
        phone: testPhone,
        token: '123456',
        type: OtpType.signup,
      );
      expect(mockClient.lastRequestBody?['type'], 'signup');

      await client.verifyOTP(
        phone: testPhone,
        token: '123456',
        type: OtpType.invite,
      );
      expect(mockClient.lastRequestBody?['type'], 'invite');

      await client.verifyOTP(
        phone: testPhone,
        token: '123456',
        type: OtpType.phoneChange,
      );
      expect(mockClient.lastRequestBody?['type'], 'phone_change');

      await client.verifyOTP(
        phone: testPhone,
        token: '123456',
        type: OtpType.emailChange,
      );
      expect(mockClient.lastRequestBody?['type'], 'email_change');
    });
  });
}
