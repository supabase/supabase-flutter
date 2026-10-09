import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart';

import 'http.dart';

/// Aborts a request once it makes no progress for [duration].
///
/// The timer starts when the request is sent and restarts whenever the HTTP
/// client reads a chunk of the body of a [request] or [multipartRequest], or of
/// a body passed through [watchRequestBody], when the response headers arrive,
/// and when a chunk of the response body arrives, so a slow but steady
/// transfer is never cut short. It is paused while the
/// consumer of the response body pauses its subscription and stops once that
/// body is done.
///
/// A timed-out request throws a [TimeoutException], either from [send] or from
/// the stream of the response it returned.
///
/// Create one for every attempt. A `null` [duration] applies no timeout.
final class IdleTimeout {
  IdleTimeout(this.duration);

  /// How long the request may go without progress, or `null` for no limit.
  final Duration? duration;

  final _expired = Completer<void>();
  Timer? _timer;
  bool _stopped = false;

  /// Whether the timeout expired.
  bool get expired => _expired.isCompleted;

  /// The abort trigger for the request, completing when [abortSignal] does or
  /// when the timeout expires.
  Future<void>? abortTrigger(Future<void>? abortSignal) {
    if (duration == null) return abortSignal;
    if (abortSignal == null) return _expired.future;
    return Future.any([abortSignal, _expired.future]);
  }

  /// A request that is aborted when [abortSignal] completes or the timeout
  /// expires, and whose body restarts the timer as the HTTP client reads it.
  Request request(String method, Uri url, {Future<void>? abortSignal}) =>
      _IdleTimeoutRequest(method, url, this, abortTrigger(abortSignal));

  /// The multipart counterpart of [request].
  MultipartRequest multipartRequest(
    String method,
    Uri url, {
    Future<void>? abortSignal,
  }) => _IdleTimeoutMultipartRequest(
    method,
    url,
    this,
    abortTrigger(abortSignal),
  );

  /// Passes [body] through, restarting the timer whenever the HTTP client reads
  /// a chunk of it.
  ///
  /// A large chunk is handed over in slices, so that a body held in memory as
  /// a single chunk also shows its progress while it is being sent.
  Stream<List<int>> watchRequestBody(Stream<List<int>> body) {
    if (duration == null) return body;
    return body.asyncExpand(_slices).map((chunk) {
      _restart();
      return chunk;
    });
  }

  static const _sliceLength = 64 * 1024;

  static Stream<List<int>> _slices(List<int> chunk) {
    if (chunk.length <= _sliceLength) return Stream.value(chunk);
    return Stream.fromIterable([
      for (var start = 0; start < chunk.length; start += _sliceLength)
        if (chunk is Uint8List)
          Uint8List.sublistView(
            chunk,
            start,
            min(start + _sliceLength, chunk.length),
          )
        else
          chunk.sublist(start, min(start + _sliceLength, chunk.length)),
    ]);
  }

  /// Sends [request] over [httpClient] and returns a response whose body
  /// stream is watched as well.
  ///
  /// Build [request] with [request], [multipartRequest] or [abortTrigger] so
  /// that a timeout also cancels it.
  Future<StreamedResponse> send(BaseRequest request, Client? httpClient) async {
    if (duration == null) return request.sendWith(httpClient);

    _restart();
    final sending = request.sendWith(httpClient);
    final StreamedResponse response;
    try {
      response = await Future.any([
        sending,
        _expired.future.then<StreamedResponse>((_) => throw _exception()),
      ]);
    } catch (_) {
      _stop();
      if (!expired) rethrow;
      // A client that does not honor the abort trigger still answers at some
      // point, and that response must not keep its connection open.
      unawaited(
        sending.then(
          (abandoned) => abandoned.stream.listen(null).cancel(),
          onError: (_) {},
        ),
      );
      throw _exception();
    }
    _restart();

    return StreamedResponse(
      _watchResponseBody(response.stream),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Stream<List<int>> _watchResponseBody(Stream<List<int>> body) {
    StreamSubscription<List<int>>? subscription;
    final controller = StreamController<List<int>>();

    void fail() {
      if (controller.isClosed) return;
      // A body nobody listened to yet still holds the connection.
      if (subscription == null) unawaited(body.listen(null).cancel());
      controller.addError(_exception());
      unawaited(controller.close());
      unawaited(subscription?.cancel());
    }

    controller
      ..onListen = () {
        if (controller.isClosed) return;
        _restart();
        subscription = body.listen(
          (chunk) {
            _restart();
            controller.add(chunk);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (error is RequestAbortedException && expired) {
              fail();
            } else if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
          onDone: () {
            _stop();
            if (!controller.isClosed) unawaited(controller.close());
          },
        );
      }
      ..onPause = () {
        _timer?.cancel();
        subscription?.pause();
      }
      ..onResume = () {
        _restart();
        subscription?.resume();
      }
      ..onCancel = () {
        _stop();
        return subscription?.cancel();
      };
    unawaited(_expired.future.then((_) => fail()));
    return controller.stream;
  }

  TimeoutException _exception() =>
      TimeoutException('Request timed out', duration);

  void _restart() {
    final duration = this.duration;
    if (duration == null || _stopped || expired) return;
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (!_stopped && !expired) _expired.complete();
    });
  }

  void _stop() {
    _stopped = true;
    _timer?.cancel();
  }
}

final class _IdleTimeoutRequest extends Request with Abortable {
  _IdleTimeoutRequest(
    super.method,
    super.url,
    this._idleTimeout,
    this.abortTrigger,
  );

  final IdleTimeout _idleTimeout;

  @override
  final Future<void>? abortTrigger;

  @override
  ByteStream finalize() =>
      ByteStream(_idleTimeout.watchRequestBody(super.finalize()));
}

final class _IdleTimeoutMultipartRequest extends MultipartRequest
    with Abortable {
  _IdleTimeoutMultipartRequest(
    super.method,
    super.url,
    this._idleTimeout,
    this.abortTrigger,
  );

  final IdleTimeout _idleTimeout;

  @override
  final Future<void>? abortTrigger;

  @override
  ByteStream finalize() =>
      ByteStream(_idleTimeout.watchRequestBody(super.finalize()));
}
