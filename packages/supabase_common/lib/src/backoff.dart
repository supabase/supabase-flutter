import 'dart:math';

/// The exponent is clamped so that doubling cannot overflow the delay. Every
/// caller caps the result well below this, so the clamp is only a safety net.
const _maxExponent = 31;

/// The exponential backoff delay to wait before the retry that follows
/// [attempt], where attempt `0` is the first failure.
///
/// The delay starts at [initialDelay] and doubles every attempt, capped at
/// [maxDelay]. When [randomizationFactor] is greater than zero the delay is
/// jittered by up to that fraction in either direction before being capped,
/// which keeps many clients from retrying in lockstep.
///
/// [random] is only meant for tests that need a deterministic jitter.
Duration exponentialBackoff(
  int attempt, {
  required Duration initialDelay,
  required Duration maxDelay,
  double randomizationFactor = 0,
  Random? random,
}) {
  assert(attempt >= 0, 'attempt cannot be negative');
  final randomization = randomizationFactor == 0
      ? 1.0
      : randomizationFactor * ((random ?? Random()).nextDouble() * 2 - 1) + 1;
  final delay =
      initialDelay * pow(2.0, min(attempt, _maxExponent)) * randomization;
  return delay < maxDelay ? delay : maxDelay;
}
