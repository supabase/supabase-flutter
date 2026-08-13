import 'dart:math';

import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

/// Returns the extremes of the jitter range so a randomized delay can be
/// checked without depending on a real random sequence.
class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}

void main() {
  group('exponentialBackoff', () {
    Duration backoff(int attempt, {double randomizationFactor = 0}) =>
        exponentialBackoff(
          attempt,
          initialDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 30),
          randomizationFactor: randomizationFactor,
        );

    test('starts at the initial delay', () {
      expect(backoff(0), const Duration(seconds: 1));
    });

    test('doubles every attempt', () {
      expect(backoff(1), const Duration(seconds: 2));
      expect(backoff(2), const Duration(seconds: 4));
      expect(backoff(3), const Duration(seconds: 8));
    });

    test('caps at the maximum delay', () {
      expect(backoff(5), const Duration(seconds: 30));
      expect(backoff(1000), const Duration(seconds: 30));
    });

    test('is not randomized by default', () {
      expect(
        List.generate(10, (_) => backoff(2)),
        everyElement(const Duration(seconds: 4)),
      );
    });

    test('jitters by at most the randomization factor', () {
      Duration jittered(double random) => exponentialBackoff(
        2,
        initialDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 30),
        randomizationFactor: 0.25,
        random: _FixedRandom(random),
      );

      expect(jittered(0), const Duration(seconds: 3));
      expect(jittered(0.5), const Duration(seconds: 4));
      expect(jittered(1), const Duration(seconds: 5));
    });

    test('rejects a negative attempt', () {
      expect(
        () => backoff(-1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
