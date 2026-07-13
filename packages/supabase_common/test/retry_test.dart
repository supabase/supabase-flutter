import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  test('retries until success and counts attempts', () async {
    var attempts = 0;
    final result = await retry(
      () async {
        attempts++;
        if (attempts < 3) throw const FormatException('fail');
        return 'ok';
      },
      delayFactor: const Duration(milliseconds: 1),
      retryIf: (error) => error is FormatException,
    );
    expect(result, 'ok');
    expect(attempts, 3);
  });

  test('stops at maxAttempts and rethrows', () async {
    var attempts = 0;
    await expectLater(
      retry(
        () async {
          attempts++;
          throw const FormatException('always');
        },
        maxAttempts: 4,
        delayFactor: const Duration(milliseconds: 1),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(attempts, 4);
  });

  test('does not retry when retryIf returns false', () async {
    var attempts = 0;
    await expectLater(
      retry(
        () async {
          attempts++;
          throw const FormatException('nope');
        },
        delayFactor: const Duration(milliseconds: 1),
        retryIf: (error) => false,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(attempts, 1);
  });

  test('RetryOptions.retry with maxAttempts (storage usage)', () async {
    var attempts = 0;
    await expectLater(
      const RetryOptions(
        maxAttempts: 2,
        delayFactor: Duration(milliseconds: 1),
      ).retry(
        () async {
          attempts++;
          throw const FormatException('x');
        },
        retryIf: (error) => true,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(attempts, 2);
  });

  test('delay grows exponentially and is capped at maxDelay', () {
    const options = RetryOptions(
      delayFactor: Duration(milliseconds: 100),
      randomizationFactor: 0,
      maxDelay: Duration(seconds: 1),
    );
    expect(options.delay(0), Duration.zero);
    expect(options.delay(1), const Duration(milliseconds: 200));
    expect(options.delay(2), const Duration(milliseconds: 400));
    expect(options.delay(10), const Duration(seconds: 1));
  });
}
