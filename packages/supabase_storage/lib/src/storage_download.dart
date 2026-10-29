import 'dart:async';
import 'dart:typed_data';

/// A download whose response head has arrived, returned by
/// `StorageFileApi.downloadStream`.
///
/// It is the stream of the response body, so it can be read with `await for`,
/// piped, collected with `collectBytes` or written with `writeToFile`. It can
/// be listened to once. Listening and then cancelling the subscription closes
/// the connection.
final class StorageDownload extends StreamView<Uint8List> {
  /// A download of [statusCode] with [headers], whose body is [body].
  StorageDownload(
    super.body, {
    required this.statusCode,
    Map<String, String> headers = const {},
    this.contentLength,
  }) : headers = Map.unmodifiable({
         for (final MapEntry(:key, :value) in headers.entries)
           key.toLowerCase(): value,
       });

  /// The status of the response, 206 for a satisfied byte range and 200 for
  /// the whole file.
  final int statusCode;

  /// The headers of the response, keyed by their lower case name.
  final Map<String, String> headers;

  /// The number of bytes the stream yields, or `null` when it is unknown.
  ///
  /// It is unknown when the response has no `Content-Length`, or has a
  /// `Content-Encoding` the HTTP stack may decode, so that the length no
  /// longer matches.
  final int? contentLength;

  /// The `Content-Range` header, which names the range a 206 response holds
  /// and the size of the whole file, for example `bytes 0-1023/4096`.
  String? get contentRange => headers['content-range'];

  /// The `Content-Type` header.
  String? get contentType => headers['content-type'];
}
