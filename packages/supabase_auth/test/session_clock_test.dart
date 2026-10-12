import 'package:clock/clock.dart';
import 'package:supabase_auth/supabase_auth.dart';
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
}
