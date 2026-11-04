import 'package:clock/clock.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  group('Session expiry', () {
    final start = DateTime.utc(2030);
    final session = Session(
      accessToken: unsignedTestJwt({
        'exp':
            start.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      }),
      tokenType: 'bearer',
      user: User(
        id: 'id',
        audience: 'authenticated',
        createdAt: DateTime.utc(2030),
      ),
    );

    test('follows the injected clock', () {
      withClock(Clock.fixed(start), () {
        expect(session.isExpired, isFalse);
        expect(session.isExpiredWithoutMargin, isFalse);
      });
      withClock(Clock.fixed(start.add(const Duration(hours: 2))), () {
        expect(session.isExpired, isTrue);
        expect(session.isExpiredWithoutMargin, isTrue);
      });
    });
  });

  group('Session expiry on the device clock', () {
    final serverNow = DateTime.utc(2030);
    final deviceNow = serverNow.add(const Duration(hours: 2));
    final user = User(
      id: 'id',
      audience: 'authenticated',
      createdAt: DateTime.utc(2030),
    );

    Session session({required DateTime expiresAt, DateTime? receivedAt}) =>
        Session(
          accessToken: unsignedTestJwt({
            'exp': unixSecondsFromDateTime(expiresAt),
          }),
          expiresIn: 3600,
          tokenType: 'bearer',
          user: user,
          receivedAt: receivedAt,
        );

    void at(DateTime now, void Function() body) =>
        withClock(Clock.fixed(now), body);

    test('counts the lifetime from the receipt time', () {
      final received = session(
        expiresAt: serverNow.add(const Duration(hours: 1)),
        receivedAt: deviceNow,
      );

      at(deviceNow, () => expect(received.isExpired, isFalse));
      at(
        deviceNow.add(const Duration(minutes: 59, seconds: 31)),
        () => expect(received.isExpired, isTrue),
      );
      expect(
        received.expiresAtOnDevice,
        deviceNow.add(const Duration(hours: 1)),
      );
    });

    test('takes an exp claim that lies slightly earlier', () {
      final expiresAt = serverNow.add(const Duration(minutes: 59, seconds: 5));
      final received = session(expiresAt: expiresAt, receivedAt: serverNow);

      expect(received.expiresAtOnDevice, expiresAt);
    });

    test('follows the exp claim without a receipt time', () {
      final stored = session(
        expiresAt: serverNow.add(const Duration(hours: 1)),
      );

      expect(stored.expiresAtOnDevice, stored.expiresAt);
      at(deviceNow, () => expect(stored.isExpired, isTrue));
    });

    test('follows the exp claim without a lifetime', () {
      final received = Session(
        accessToken: unsignedTestJwt({
          'exp': unixSecondsFromDateTime(
            serverNow.add(const Duration(hours: 1)),
          ),
        }),
        tokenType: 'bearer',
        user: user,
        receivedAt: deviceNow,
      );

      at(deviceNow, () => expect(received.isExpired, isTrue));
    });

    test('is expired when the device clock is set back', () {
      final received = session(
        expiresAt: serverNow.add(const Duration(hours: 1)),
        receivedAt: deviceNow,
      );

      at(
        deviceNow.subtract(const Duration(seconds: 1)),
        () => expect(received.isExpired, isFalse),
      );
      at(
        deviceNow.subtract(const Duration(minutes: 2)),
        () => expect(received.isExpiredWithoutMargin, isTrue),
      );
    });

    test('keeps the receipt time through json and copyWith', () {
      final received = session(
        expiresAt: serverNow.add(const Duration(hours: 1)),
        receivedAt: deviceNow,
      );

      final restored = Session.fromJson(
        received.copyWith(tokenType: 'bearer').toJson(),
        receivedAt: serverNow,
      )!;

      expect(restored.receivedAt, deviceNow);
      expect(restored, received);
      expect(
        received.copyWith(expiresIn: 3600).receivedAt,
        isNull,
      );
    });
  });
}
