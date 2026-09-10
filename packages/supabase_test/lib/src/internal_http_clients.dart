// The composed helpers of this package legitimately build on its own
// test-only primitives outside of a test directory.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'mock_http_clients.dart';

/// A mock HTTP client that answers every request with the same JSON body.
@visibleForTesting
class JsonResponseMockClient extends BaseClient {
  JsonResponseMockClient({required this.body, this.statusCode = 200});

  /// The body the mocked server encodes and returns for every request.
  final Object? body;

  final int statusCode;

  Uri? lastUri;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastUri = request.url;

    return jsonStreamedResponse(
      body,
      statusCode: statusCode,
      request: request,
    );
  }
}

/// A mock HTTP client that answers every request with an empty body and the
/// recognizable status code 420, so a test can assert this client was the
/// one used.
@visibleForTesting
class FailingHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      const Stream.empty(),
      420,
      request: request,
    );
  }
}

/// Never answers, so only completing [request]'s abort trigger, which
/// surfaces as a [RequestAbortedException], ends the request.
///
/// A request that is not [Abortable] stalls forever.
@visibleForTesting
Future<StreamedResponse> stallUntilAborted(BaseRequest request) {
  final completer = Completer<StreamedResponse>();
  if (request is Abortable) {
    final abortTrigger = request.abortTrigger;
    unawaited(
      abortTrigger?.then((_) {
        if (!completer.isCompleted) {
          completer.completeError(
            RequestAbortedException(request.url),
            StackTrace.current,
          );
        }
      }),
    );
  }
  return completer.future;
}
