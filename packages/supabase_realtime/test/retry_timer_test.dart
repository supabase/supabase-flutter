import 'dart:math';

import 'package:supabase_realtime/src/retry_timer.dart';
import 'package:test/test.dart';

class _FixedRandom implements Random {
  const _FixedRandom({required this.highest});

  final bool highest;

  @override
  int nextInt(int max) => highest ? max - 1 : 0;

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}

void main() {
  group('reconnectBackoff', () {
    test('doubles the upper bound from one second up to 30 seconds', () {
      final highest = _FixedRandom(highest: true);
      expect(
        [
          for (var attempt = 1; attempt <= 8; attempt++)
            RetryTimer.reconnectBackoff(attempt, random: highest).inSeconds,
        ],
        [1, 2, 4, 8, 16, 30, 30, 30],
      );
    });

    test('can wait no time at all', () {
      expect(
        RetryTimer.reconnectBackoff(5, random: _FixedRandom(highest: false)),
        Duration.zero,
      );
    });

    test('stays within its bounds for large attempt numbers', () {
      for (var attempt = 1; attempt < 200; attempt++) {
        final delay = RetryTimer.reconnectBackoff(attempt);
        expect(delay, greaterThanOrEqualTo(Duration.zero));
        expect(delay, lessThanOrEqualTo(const Duration(seconds: 30)));
      }
    });
  });

  test('rejoinBackoff steps through 1, 2, 5 and 10 seconds', () {
    expect(
      [
        for (var attempt = 1; attempt <= 6; attempt++)
          RetryTimer.rejoinBackoff(attempt).inSeconds,
      ],
      [1, 2, 5, 10, 10, 10],
    );
  });
}
