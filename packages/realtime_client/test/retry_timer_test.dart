import 'package:realtime_client/src/retry_timer.dart';
import 'package:test/test.dart';

void main() {
  test('retry function should stop at maxDelay', () {
    final backoff = RetryTimer.createRetryFunction(maxDelay: 5000);
    expect(backoff(100), 5000);
  });

  test('retry function should return first delay on tries == 1', () {
    final backoff = RetryTimer.createRetryFunction();
    expect(backoff(1), 1000);
  });

  test('retry function should return firstDelay * 4 for tries 3', () {
    final backoff = RetryTimer.createRetryFunction();
    expect(backoff(3), 1000 * 4);
  });
}
