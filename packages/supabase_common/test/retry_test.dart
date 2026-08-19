import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

const _fast = SupabaseRetryOptions(
  initialDelay: Duration(milliseconds: 1),
  randomizationFactor: 0,
);

void main() {
  group('retry', () {
    test('retries until success and counts attempts', () async {
      var attempts = 0;
      final result = await retry(
        () async {
          attempts++;
          if (attempts < 3) throw const FormatException('fail');
          return 'ok';
        },
        options: _fast,
        retryIf: (error) => error is FormatException,
      );
      expect(result, 'ok');
      expect(attempts, 3);
    });

    test('stops after count retries and rethrows', () async {
      var attempts = 0;
      await expectLater(
        retry(() async {
          attempts++;
          throw const FormatException('always');
        }, options: _fast.copyWith(count: 3)),
        throwsA(isA<FormatException>()),
      );
      expect(attempts, 4);
    });

    test('a count of zero sends the action exactly once', () async {
      var attempts = 0;
      await expectLater(
        retry(() async {
          attempts++;
          throw const FormatException('always');
        }, options: _fast.copyWith(count: 0)),
        throwsA(isA<FormatException>()),
      );
      expect(attempts, 1);
    });

    test('disabled options send the action exactly once', () async {
      var attempts = 0;
      await expectLater(
        retry(() async {
          attempts++;
          throw const FormatException('always');
        }, options: _fast.copyWith(enabled: false)),
        throwsA(isA<FormatException>()),
      );
      expect(attempts, 1);
    });

    test('does not retry when retryIf returns false', () async {
      var attempts = 0;
      await expectLater(
        retry(
          () async {
            attempts++;
            throw const FormatException('nope');
          },
          options: _fast,
          retryIf: (error) => false,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(attempts, 1);
    });

    test('invokes onRetry before each retry with the thrown error', () async {
      final seenErrors = <Object>[];
      var attempts = 0;
      final result = await retry(
        () async {
          attempts++;
          if (attempts < 3) throw FormatException('fail $attempts');
          return 'ok';
        },
        options: _fast,
        onRetry: seenErrors.add,
      );
      expect(result, 'ok');
      expect(seenErrors, hasLength(2));
      expect(seenErrors.every((error) => error is FormatException), isTrue);
    });
  });

  group('SupabaseRetryOptions', () {
    test('the delay doubles for every retry and is capped at maxDelay', () {
      const options = SupabaseRetryOptions(
        initialDelay: Duration(milliseconds: 100),
        randomizationFactor: 0,
        maxDelay: Duration(seconds: 1),
      );

      expect(options.delay(0), const Duration(milliseconds: 100));
      expect(options.delay(1), const Duration(milliseconds: 200));
      expect(options.delay(2), const Duration(milliseconds: 400));
      expect(options.delay(10), const Duration(seconds: 1));
    });

    test('copyWith keeps the fields that are not overridden', () {
      const options = SupabaseRetryOptions(
        enabled: false,
        count: 7,
        initialDelay: Duration(milliseconds: 5),
        maxDelay: Duration(milliseconds: 50),
        randomizationFactor: 0.5,
      );

      final copy = options.copyWith(enabled: true);

      expect(copy.enabled, isTrue);
      expect(copy.count, 7);
      expect(copy.initialDelay, const Duration(milliseconds: 5));
      expect(copy.maxDelay, const Duration(milliseconds: 50));
      expect(copy.randomizationFactor, 0.5);
    });

    test('two options with the same fields are equal', () {
      expect(
        const SupabaseRetryOptions(count: 2),
        const SupabaseRetryOptions(count: 2),
      );
      expect(
        const SupabaseRetryOptions(count: 2).hashCode,
        const SupabaseRetryOptions(count: 2).hashCode,
      );
      expect(
        const SupabaseRetryOptions(count: 2),
        isNot(const SupabaseRetryOptions(count: 3)),
      );
    });

    test('a negative count is rejected', () {
      expect(
        () => SupabaseRetryOptions(count: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a randomization factor outside 0 to 1 is rejected', () {
      expect(
        () => SupabaseRetryOptions(randomizationFactor: 1.5),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
