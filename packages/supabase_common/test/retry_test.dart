import 'dart:async';

import 'package:http/http.dart' show RequestAbortedException;
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

const _fast = SupabaseRetryOptions(
  initialDelay: Duration(milliseconds: 1),
  randomizationFactor: 0,
);

const _fiftyMilliseconds = Duration(milliseconds: 50);

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

    test('never retries a RequestAbortedException', () async {
      var attempts = 0;
      await expectLater(
        retry(
          () async {
            attempts++;
            throw RequestAbortedException();
          },
          options: _fast,
          retryIf: (error) => true,
        ),
        throwsA(isA<RequestAbortedException>()),
      );
      expect(attempts, 1);
    });

    test('an abort during the delay before the next attempt ends the loop '
        'without making that attempt', () async {
      final abortSignal = Completer<void>();
      var attempts = 0;
      final result = retry(
        () async {
          attempts++;
          throw const FormatException('fail');
        },
        options: const SupabaseRetryOptions(initialDelay: Duration(hours: 1)),
        retryIf: (error) => error is FormatException,
        abortSignal: abortSignal.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      abortSignal.complete();

      await expectLater(result, throwsA(isA<RequestAbortedException>()));
      expect(attempts, 1);
    });

    test('retries a result retryIfResult rejects', () async {
      var attempts = 0;
      final result = await retry(
        () => ++attempts,
        options: _fast,
        retryIfResult: (attempt) => attempt < 3,
      );
      expect(result, 3);
    });

    test('returns the rejected result once the retries run out', () async {
      var attempts = 0;
      final result = await retry(
        () => ++attempts,
        options: _fast.copyWith(count: 2),
        retryIfResult: (attempt) => true,
      );
      expect(result, 3);
    });

    test('passes the rejected result to retryAfter', () async {
      final outcomes = <Object>[];
      var attempts = 0;
      await retry(
        () => ++attempts,
        options: _fast,
        retryIfResult: (attempt) => attempt < 2,
        retryAfter: (outcome) {
          outcomes.add(outcome);
          return Duration.zero;
        },
      );
      expect(outcomes, [1]);
    });

    test('waits the delay retryAfter returns instead of the backoff', () async {
      var attempts = 0;
      final stopwatch = Stopwatch()..start();
      final result = await retry(
        () async {
          attempts++;
          if (attempts < 2) throw const FormatException('fail');
          return 'ok';
        },
        options: const SupabaseRetryOptions(initialDelay: Duration(hours: 1)),
        retryAfter: (error) => const Duration(milliseconds: 50),
      );
      stopwatch.stop();

      expect(result, 'ok');
      expect(stopwatch.elapsed, greaterThanOrEqualTo(_fiftyMilliseconds));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('falls back to the backoff when retryAfter returns null', () async {
      var attempts = 0;
      final stopwatch = Stopwatch()..start();
      await retry(
        () async {
          attempts++;
          if (attempts < 2) throw const FormatException('fail');
          return 'ok';
        },
        options: _fast.copyWith(initialDelay: _fiftyMilliseconds),
        retryAfter: (error) => null,
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, greaterThanOrEqualTo(_fiftyMilliseconds));
    });

    test('caps the delay retryAfter returns at maxDelay', () async {
      var attempts = 0;
      final stopwatch = Stopwatch()..start();
      await retry(
        () async {
          attempts++;
          if (attempts < 2) throw const FormatException('fail');
          return 'ok';
        },
        options: _fast.copyWith(maxDelay: _fiftyMilliseconds),
        retryAfter: (error) => const Duration(hours: 1),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('an abort during a retryAfter delay ends the loop', () async {
      final abortSignal = Completer<void>();
      var attempts = 0;
      final result = retry(
        () async {
          attempts++;
          throw const FormatException('fail');
        },
        options: const SupabaseRetryOptions(maxDelay: Duration(hours: 1)),
        retryAfter: (error) => const Duration(hours: 1),
        abortSignal: abortSignal.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      abortSignal.complete();

      await expectLater(result, throwsA(isA<RequestAbortedException>()));
      expect(attempts, 1);
    });
  });

  group('parseRetryAfter', () {
    final now = DateTime.utc(2015, 10, 21, 7, 28);

    test('reads a number of seconds', () {
      expect(
        parseRetryAfter({'retry-after': '3'}, now: now),
        const Duration(seconds: 3),
      );
    });

    test('matches the header name regardless of case', () {
      expect(
        parseRetryAfter({'Retry-After': ' 2 '}, now: now),
        const Duration(seconds: 2),
      );
    });

    test('reads an HTTP date in the future', () {
      expect(
        parseRetryAfter({
          'retry-after': 'Wed, 21 Oct 2015 07:28:10 GMT',
        }, now: now),
        const Duration(seconds: 10),
      );
    });

    test('ignores an HTTP date that is not in the future', () {
      expect(
        parseRetryAfter({
          'retry-after': 'Wed, 21 Oct 2015 07:27:00 GMT',
        }, now: now),
        isNull,
      );
      expect(
        parseRetryAfter({
          'retry-after': 'Wed, 21 Oct 2015 07:28:00 GMT',
        }, now: now),
        isNull,
      );
    });

    test('ignores a missing, negative or unparseable value', () {
      expect(parseRetryAfter({}, now: now), isNull);
      expect(parseRetryAfter({'retry-after': '-5'}, now: now), isNull);
      expect(parseRetryAfter({'retry-after': 'soon'}, now: now), isNull);
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
