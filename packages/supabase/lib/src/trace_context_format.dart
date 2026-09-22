import 'package:meta/meta.dart';

final _hexadecimal = RegExp(r'^[0-9a-f]+$', caseSensitive: false);

/// The all-zero trace id, which the W3C trace context specification forbids.
@internal
const invalidTraceId = '00000000000000000000000000000000';

/// The all-zero parent id, which the W3C trace context specification forbids.
@internal
const invalidParentId = '0000000000000000';

/// Reports whether [traceparent] is a well-formed W3C `traceparent`.
///
/// A version above `00` may append fields the specification requires
/// receivers to parse past rather than reject, so only version `00` is held
/// to exactly four fields. Version `ff` is invalid.
@internal
bool isValidTraceparent(String traceparent) {
  final parts = traceparent.split('-');
  if (parts.length < 4) {
    return false;
  }
  final version = parts[0].toLowerCase();
  if (version.length != 2 ||
      !_hexadecimal.hasMatch(version) ||
      version == 'ff' ||
      (version == '00' && parts.length != 4)) {
    return false;
  }
  final traceFlags = parts[3];
  return isValidTraceId(parts[1]) &&
      isValidParentId(parts[2]) &&
      traceFlags.length == 2 &&
      _hexadecimal.hasMatch(traceFlags);
}

/// Reports whether [traceId] is 32 hexadecimal digits and not all zeros.
@internal
bool isValidTraceId(String traceId) =>
    traceId.length == 32 &&
    traceId != invalidTraceId &&
    _hexadecimal.hasMatch(traceId);

/// Reports whether [parentId] is 16 hexadecimal digits and not all zeros.
@internal
bool isValidParentId(String parentId) =>
    parentId.length == 16 &&
    parentId != invalidParentId &&
    _hexadecimal.hasMatch(parentId);

/// Reports whether a W3C `traceparent` carries the sampled flag.
///
/// Malformed headers are treated as sampled so that propagation is not
/// silently suppressed by an unparseable value, matching supabase-js.
@internal
bool isSampledTraceparent(String traceparent) {
  if (!isValidTraceparent(traceparent)) {
    return true;
  }
  final flags = int.parse(traceparent.split('-')[3], radix: 16);
  return flags & 0x01 == 0x01;
}

/// Formats a W3C `traceparent` from its parts.
///
/// The ids are lowercased, as the specification only admits lowercase
/// hexadecimal digits.
@internal
String formatTraceparent({
  required String traceId,
  required String spanId,
  required bool sampled,
}) =>
    '00-${traceId.toLowerCase()}-${spanId.toLowerCase()}-'
    '${sampled ? '01' : '00'}';
