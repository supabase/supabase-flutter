import 'package:iceberg/iceberg.dart';
import 'package:test/test.dart';

void main() {
  test('every iceberg exception names itself in toString', () {
    IcebergException fromStatus(int statusCode, {String? type}) =>
        IcebergApiException.fromResponse(statusCode, {
          'error': {'message': 'boom', 'type': ?type},
        });

    final exceptions = <String, IcebergException>{
      'IcebergNetworkException': const IcebergNetworkException('boom'),
      'IcebergNotFoundException': fromStatus(404),
      'IcebergConflictException': fromStatus(409),
      'IcebergAuthenticationTimeoutException': fromStatus(419),
      'IcebergCommitStateUnknownException': fromStatus(
        500,
        type: 'CommitStateUnknownException',
      ),
      'IcebergServerException': fromStatus(503),
      'IcebergUnknownException': fromStatus(418),
    };

    for (final MapEntry(key: name, value: exception) in exceptions.entries) {
      expect(exception.toString(), startsWith('$name('));
    }
  });
}
