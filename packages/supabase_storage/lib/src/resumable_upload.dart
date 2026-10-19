import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:supabase_storage/src/fetch.dart';
import 'package:supabase_storage/src/logger.dart';
import 'package:supabase_storage/src/types.dart';

import 'file_stub.dart' if (dart.library.io) './file_io.dart';

/// Where resumable uploads keep the records that let them continue after the
/// process restarts.
///
/// Every record is kept under a single key. `supabase_flutter` stores them
/// in the same place as the session; a pure Dart client keeps them in memory
/// unless another storage is passed through
/// [ResumableUploadOptions.storage].
abstract class ResumableUploadStorage {
  const ResumableUploadStorage();

  /// Returns the value stored under [key], or `null` when there is none.
  Future<String?> getItem(String key);

  /// Stores [value] under [key], replacing any earlier value.
  Future<void> setItem(String key, String value);

  /// Removes the value stored under [key], if any.
  Future<void> removeItem(String key);
}

/// A [ResumableUploadStorage] that keeps the records in memory only, so an
/// upload can be paused and resumed but not continued after a restart.
class MemoryResumableUploadStorage extends ResumableUploadStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem(String key) async => _items[key];

  @override
  Future<void> setItem(String key, String value) async => _items[key] = value;

  @override
  Future<void> removeItem(String key) async => _items.remove(key);
}

/// How resumable uploads are chunked, retried and persisted.
class ResumableUploadOptions {
  const ResumableUploadOptions({
    this.chunkSize = defaultChunkSize,
    this.retryDelays = defaultRetryDelays,
    this.retryTimeout = const Duration(seconds: 120),
    this.storage,
  }) : assert(chunkSize > 0, 'chunkSize must be positive');

  /// The chunk size hosted Supabase requires, 6 MiB.
  static const defaultChunkSize = 6 * 1024 * 1024;

  /// The waits before each retry of a failed request.
  static const defaultRetryDelays = [
    Duration.zero,
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
  ];

  /// The bytes sent per request. Every chunk but the last has this size.
  ///
  /// Hosted Supabase only accepts the default. Change it to match a
  /// self-hosted server configured with another `TUS_PART_SIZE`.
  final int chunkSize;

  /// The waits before each retry of a request that failed on the network, or
  /// that the server answered with HTTP 408, 429 or a 5xx status. There are as
  /// many retries as delays.
  final List<Duration> retryDelays;

  /// How long a chunk may keep failing, counted from its first failure. The
  /// upload fails once the next retry would start after it.
  final Duration retryTimeout;

  /// Where the records are kept, in memory when `null`.
  final ResumableUploadStorage? storage;

  /// Returns a copy with the given fields replaced.
  ResumableUploadOptions copyWith({
    int? chunkSize,
    List<Duration>? retryDelays,
    Duration? retryTimeout,
    ResumableUploadStorage? storage,
  }) {
    return ResumableUploadOptions(
      chunkSize: chunkSize ?? this.chunkSize,
      retryDelays: retryDelays ?? this.retryDelays,
      retryTimeout: retryTimeout ?? this.retryTimeout,
      storage: storage ?? this.storage,
    );
  }
}

/// Where a [ResumableUpload] is.
enum ResumableUploadStatus {
  /// Sending chunks, or waiting to retry one.
  uploading,

  /// Stopped by [ResumableUpload.pause].
  paused,

  /// Every byte is stored. The upload is over.
  completed,

  /// Gave up after an error, which [ResumableUpload.done] completes with.
  /// [ResumableUpload.resume] tries again.
  failed,

  /// Stopped by [ResumableUpload.cancel]. The upload is over.
  cancelled,
}

/// The state of a [ResumableUpload] at one point in time.
@immutable
class ResumableUploadProgress {
  const ResumableUploadProgress({
    required this.status,
    required this.bytesUploaded,
    required this.totalBytes,
  });

  /// Where the upload is.
  final ResumableUploadStatus status;

  /// The bytes the server confirmed, plus those of the chunk being sent.
  ///
  /// It can go down when the server reports a lower offset than expected, or
  /// when an expired upload starts over.
  final int bytesUploaded;

  /// The size of the file.
  final int totalBytes;

  @override
  bool operator ==(Object other) =>
      other is ResumableUploadProgress &&
      other.status == status &&
      other.bytesUploaded == bytesUploaded &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(status, bytesUploaded, totalBytes);

  @override
  String toString() =>
      'ResumableUploadProgress(status: ${status.name}, '
      'bytesUploaded: $bytesUploaded, totalBytes: $totalBytes)';
}

/// A resumable upload the server knows about, as it is persisted.
///
/// Listed by `SupabaseStorageClient.resumableUploads`, so an upload
/// interrupted by a restart can be continued with
/// `SupabaseStorageClient.resumeUpload`.
@immutable
class ResumableUploadRecord {
  const ResumableUploadRecord._({
    required this.id,
    required this.bucketId,
    required this.path,
    required this.totalBytes,
    required this.createdAt,
    required Uri uploadUrl,
    required bool upsert,
    required String contentType,
    required String cacheControl,
    required Map<String, dynamic>? metadata,
    required String? token,
  }) : _uploadUrl = uploadUrl,
       _upsert = upsert,
       _contentType = contentType,
       _cacheControl = cacheControl,
       _metadata = metadata,
       _token = token;

  factory ResumableUploadRecord._fromJson(Map<String, dynamic> json) {
    return ResumableUploadRecord._(
      id: json['id'] as String,
      bucketId: json['bucketId'] as String,
      path: json['path'] as String,
      totalBytes: json['totalBytes'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      uploadUrl: Uri.parse(json['uploadUrl'] as String),
      upsert: json['upsert'] as bool,
      contentType: json['contentType'] as String,
      cacheControl: json['cacheControl'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      token: json['token'] as String?,
    );
  }

  /// The id of the upload, [ResumableUpload.id].
  final String id;

  /// The bucket the object goes to.
  final String bucketId;

  /// The path of the object in the bucket.
  final String path;

  /// The size of the file.
  final int totalBytes;

  /// When the server created the upload.
  final DateTime createdAt;

  final Uri _uploadUrl;
  final bool _upsert;
  final String _contentType;
  final String _cacheControl;
  final Map<String, dynamic>? _metadata;
  final String? _token;

  Map<String, dynamic> _toJson() => {
    'id': id,
    'bucketId': bucketId,
    'path': path,
    'totalBytes': totalBytes,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'uploadUrl': _uploadUrl.toString(),
    'upsert': _upsert,
    'contentType': _contentType,
    'cacheControl': _cacheControl,
    'metadata': _metadata,
    'token': _token,
  };

  @override
  String toString() =>
      'ResumableUploadRecord(id: $id, bucketId: $bucketId, path: $path, '
      'totalBytes: $totalBytes, createdAt: $createdAt)';
}

/// The bytes a resumable upload sends.
@internal
sealed class ResumableUploadSource {
  const ResumableUploadSource();

  /// Reads [file] from disk, one chunk at a time.
  const factory ResumableUploadSource.file(File file) = _FileSource;

  /// Sends [data] from memory.
  const factory ResumableUploadSource.bytes(Uint8List data) = _BytesSource;

  Future<int> get length;

  Stream<List<int>> read(int start, int end);
}

final class _FileSource extends ResumableUploadSource {
  const _FileSource(this.file);

  final File file;

  @override
  Future<int> get length async {
    final int bytes = await file.length();
    return bytes;
  }

  @override
  Stream<List<int>> read(int start, int end) => file.openRead(start, end);
}

final class _BytesSource extends ResumableUploadSource {
  const _BytesSource(this.data);

  final Uint8List data;

  @override
  Future<int> get length async => data.length;

  @override
  Stream<List<int>> read(int start, int end) =>
      Stream.value(Uint8List.sublistView(data, start, end));
}

/// The records and live uploads of one storage client.
@internal
class ResumableUploadRegistry {
  ResumableUploadRegistry({
    required this.url,
    required this.options,
    required this.storageKey,
    required this.fetch,
  }) : _storage = options.storage ?? MemoryResumableUploadStorage();

  /// The storage endpoint uploads are created under.
  final String url;
  final ResumableUploadOptions options;

  /// The key the records are stored under.
  final String storageKey;
  final Fetch fetch;
  final ResumableUploadStorage _storage;

  /// The uploads of this process that are uploading or paused, by id, so an
  /// upload reattached while it runs is the same handle.
  final _live = <String, ResumableUpload>{};

  Future<void> _operations = Future.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, ResumableUploadRecord>> _read() async {
    final value = await _storage.getItem(storageKey);
    if (value == null) return {};
    final records = <String, ResumableUploadRecord>{};
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      for (final entry in json.values) {
        final record = ResumableUploadRecord._fromJson(
          entry as Map<String, dynamic>,
        );
        records[record.id] = record;
      }
    } on Object catch (error, stackTrace) {
      storageLogger.warning(
        'Discarding unreadable resumable upload records',
        error,
        stackTrace,
      );
    }
    return records;
  }

  Future<void> _write(Map<String, ResumableUploadRecord> records) {
    if (records.isEmpty) return _storage.removeItem(storageKey);
    return _storage.setItem(
      storageKey,
      jsonEncode({
        for (final record in records.values) record.id: record._toJson(),
      }),
    );
  }

  /// Every record, oldest first.
  Future<List<ResumableUploadRecord>> records() => _serialize(() async {
    final records = (await _read()).values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return records;
  });

  Future<ResumableUploadRecord?> _record(String id) =>
      _serialize(() async => (await _read())[id]);

  Future<void> _save(ResumableUploadRecord record) => _serialize(() async {
    await _write({...await _read(), record.id: record});
  });

  Future<void> _remove(String id) => _serialize(() async {
    final records = await _read();
    if (records.remove(id) != null) await _write(records);
  });

  /// Starts uploading [source] to [path] in [bucketId].
  ResumableUpload start({
    required String bucketId,
    required String path,
    required ResumableUploadSource source,
    required String contentType,
    required FileOptions fileOptions,
    required Map<String, String> headers,
    required String? token,
  }) {
    final metadata = fileOptions.metadata;
    if (metadata != null) {
      try {
        jsonEncode(metadata);
      } on JsonUnsupportedObjectError catch (error) {
        throw ArgumentError.value(
          metadata,
          'metadata',
          'Cannot be encoded as JSON: $error',
        );
      }
    }
    final upload = ResumableUpload._(
      id: _uuid(),
      bucketId: bucketId,
      path: path,
      source: source,
      headers: {...headers, ...?fileOptions.headers},
      upsert: fileOptions.upsert,
      contentType: contentType,
      cacheControl: fileOptions.cacheControl,
      metadata: fileOptions.metadata,
      token: token,
      record: null,
      registry: this,
    );
    _live[upload.id] = upload;
    upload._start();
    return upload;
  }

  /// Continues the upload recorded under [id] with [source], returning the
  /// handle of the upload when it is still running in this process.
  Future<ResumableUpload> resume(
    String id,
    ResumableUploadSource source,
    Map<String, String> headers,
  ) async {
    final live = _live[id];
    if (live != null) return live..resume();
    final record = await _record(id);
    if (record == null) {
      throw StorageException('No resumable upload is recorded under $id');
    }
    final length = await source.length;
    if (length != record.totalBytes) {
      throw ArgumentError.value(
        length,
        'source',
        'Holds $length bytes, but upload $id is for ${record.totalBytes}',
      );
    }
    final existing = _live[id];
    if (existing != null) return existing..resume();
    final upload = _live[id] = ResumableUpload._(
      id: id,
      bucketId: record.bucketId,
      path: record.path,
      source: source,
      headers: headers,
      upsert: record._upsert,
      contentType: record._contentType,
      cacheControl: record._cacheControl,
      metadata: record._metadata,
      token: record._token,
      record: record,
      registry: this,
    );
    upload._start();
    return upload;
  }

  /// Cancels the upload recorded under [id], or terminates it on the server
  /// and forgets it when it does not run in this process.
  Future<void> discard(String id, Map<String, String> headers) async {
    final live = _live[id];
    if (live != null) return live.cancel();
    final record = await _record(id);
    if (record == null) return;
    await _terminate(record, headers);
    await _remove(id);
  }

  Future<void> _terminate(
    ResumableUploadRecord record,
    Map<String, String> headers,
  ) async {
    try {
      await fetch.sendTus(
        HttpMethod.delete,
        record._uploadUrl,
        _tusHeaders(headers, record._token),
      );
    } on Exception catch (error, stackTrace) {
      storageLogger.fine(
        'Could not terminate resumable upload ${record.id}',
        error,
        stackTrace,
      );
    }
  }

  static String _uuid() {
    final bytes = randomBytes(16);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

Map<String, String> _tusHeaders(Map<String, String> headers, String? token) => {
  ...headers,
  'Tus-Resumable': '1.0.0',
  'x-signature': ?token,
};

enum _Step { create, resync, append }

/// An upload sent in chunks with the tus protocol, that can be paused,
/// resumed, cancelled, and continued after the process restarts.
///
/// Started by `StorageFileApi.resumableUpload` and
/// `StorageFileApi.resumableUploadBinary`:
///
/// ```dart
/// final upload = supabase.storage
///     .from('videos')
///     .resumableUpload('holiday.mp4', file);
/// upload.progress.listen((progress) {
///   print('${progress.bytesUploaded} of ${progress.totalBytes}');
/// });
/// final response = await upload.done;
/// ```
///
/// Each chunk is sent from the offset the server confirmed, never from a
/// local count, so bytes the server holds are not sent twice. A request that
/// fails on the network, or that the server answers with HTTP 408, 429 or a
/// 5xx status, is retried as [ResumableUploadOptions] configures. An upload
/// the server no longer knows, because it expired, starts over.
///
/// The upload is recorded under [id] as soon as the server created it, until
/// it completes or is cancelled. After a restart,
/// `SupabaseStorageClient.resumableUploads` lists the records and
/// `SupabaseStorageClient.resumeUpload` continues one with the same file.
class ResumableUpload {
  ResumableUpload._({
    required this.id,
    required this.bucketId,
    required this.path,
    required ResumableUploadSource source,
    required Map<String, String> headers,
    required bool upsert,
    required String contentType,
    required String cacheControl,
    required Map<String, dynamic>? metadata,
    required String? token,
    required ResumableUploadRecord? record,
    required ResumableUploadRegistry registry,
  }) : _source = source,
       _headers = headers,
       _upsert = upsert,
       _contentType = contentType,
       _cacheControl = cacheControl,
       _metadata = metadata,
       _token = token,
       _record = record,
       _registry = registry,
       _totalBytes = record?.totalBytes {
    _done.future.ignore();
  }

  /// The id the upload is recorded under, a UUID. Store it to continue the
  /// upload with `SupabaseStorageClient.resumeUpload` after a restart.
  final String id;

  /// The bucket the object goes to.
  final String bucketId;

  /// The path of the object in the bucket.
  final String path;

  final ResumableUploadSource _source;
  final Map<String, String> _headers;
  final bool _upsert;
  final String _contentType;
  final String _cacheControl;
  final Map<String, dynamic>? _metadata;
  final String? _token;
  final ResumableUploadRegistry _registry;

  ResumableUploadRecord? _record;
  int? _totalBytes;
  int _bytesUploaded = 0;
  ResumableUploadStatus _status = ResumableUploadStatus.uploading;
  Completer<void>? _abort;
  Future<void> _running = Future.value();
  int _generation = 0;
  Completer<UploadResponse> _done = Completer();
  final _progress = ReplaySubject<ResumableUploadProgress>(sync: true);

  /// Where the upload is.
  ResumableUploadStatus get status => _status;

  /// Every change of [status] and of the bytes uploaded. A new listener gets
  /// the latest value first. Closes once the upload completes or is
  /// cancelled.
  Stream<ResumableUploadProgress> get progress => _progress.stream;

  /// Completes with the stored object once every byte is on the server.
  ///
  /// Completes with the error the upload failed with, or with a
  /// [ResumableUploadCancelledException] after [cancel]. After a failure,
  /// [resume] makes it wait for the next outcome.
  Future<UploadResponse> get done => _done.future;

  /// Stops sending chunks. The chunk in flight is aborted, and [resume]
  /// continues from the offset the server confirmed.
  void pause() {
    if (_status != ResumableUploadStatus.uploading) return;
    _setStatus(ResumableUploadStatus.paused);
    _stopRun();
  }

  /// Continues a paused or failed upload from the offset the server
  /// confirmed.
  void resume() {
    if (_status != ResumableUploadStatus.paused &&
        _status != ResumableUploadStatus.failed) {
      return;
    }
    _registry._live[id] = this;
    _start();
  }

  /// Aborts the upload, deletes what the server holds of it, and forgets its
  /// record. [done] completes with a [ResumableUploadCancelledException].
  Future<void> cancel() async {
    if (_status == ResumableUploadStatus.completed ||
        _status == ResumableUploadStatus.cancelled) {
      return;
    }
    _setStatus(ResumableUploadStatus.cancelled);
    _stopRun();
    _finish();
    await _running;
    final record = _record;
    if (record != null) {
      await _registry._terminate(record, _headers);
      await _registry._remove(id);
    }
    if (_done.isCompleted) _done = Completer()..future.ignore();
    _done.completeError(
      ResumableUploadCancelledException(id),
      StackTrace.current,
    );
  }

  void _start() {
    if (_done.isCompleted) {
      _done = Completer()..future.ignore();
    }
    _setStatus(ResumableUploadStatus.uploading);
    final generation = ++_generation;
    _running = _running.then((_) => _run(generation));
  }

  void _stopRun() {
    _generation++;
    _abort?.complete();
    _abort = null;
  }

  bool _isCurrent(int generation) =>
      generation == _generation && _status == ResumableUploadStatus.uploading;

  void _setStatus(ResumableUploadStatus updated) {
    _status = updated;
    _emit();
  }

  void _emit() {
    final totalBytes = _totalBytes;
    if (totalBytes == null || _progress.isClosed) return;
    _progress.add(
      ResumableUploadProgress(
        status: _status,
        bytesUploaded: _bytesUploaded,
        totalBytes: totalBytes,
      ),
    );
  }

  void _setBytesUploaded(int bytes) {
    _bytesUploaded = bytes;
    _emit();
  }

  void _finish() {
    if (_registry._live[id] == this) _registry._live.remove(id);
    unawaited(_progress.close());
  }

  Future<void> _run(int generation) async {
    if (!_isCurrent(generation)) return;
    var step = _record == null ? _Step.create : _Step.resync;
    var retries = 0;
    Stopwatch? failing;
    try {
      if (_totalBytes == null) {
        _totalBytes = await _source.length;
        _emit();
      }
      while (_isCurrent(generation)) {
        final abort = _abort = Completer<void>();
        try {
          switch (step) {
            case _Step.create:
              if (await _create(abort.future)) return;
              step = _Step.append;
            case _Step.resync:
              if (await _resync(abort.future)) return;
              step = _Step.append;
            case _Step.append:
              if (await _append(abort.future)) return;
              retries = 0;
              failing = null;
          }
        } on http.RequestAbortedException {
          if (!_isCurrent(generation)) return;
          rethrow;
        } on Exception catch (error) {
          if (step != _Step.create && _isGone(error)) {
            storageLogger.fine('Resumable upload $id expired, starting over');
            await _registry._remove(id);
            _record = null;
            _setBytesUploaded(0);
            step = _Step.create;
            continue;
          }
          if (!_isRetryable(error, step)) rethrow;
          final elapsed = (failing ??= Stopwatch()..start()).elapsed;
          final delays = _registry.options.retryDelays;
          if (retries >= delays.length ||
              elapsed + delays[retries] > _registry.options.retryTimeout) {
            rethrow;
          }
          final delay = delays[retries++];
          storageLogger.fine(
            'Retrying resumable upload $id in $delay after: $error',
          );
          await Future.any([Future<void>.delayed(delay), abort.future]);
          if (step != _Step.create) step = _Step.resync;
        }
      }
    } on Object catch (error, stackTrace) {
      if (!_isCurrent(generation)) return;
      if (error is StorageApiException && !_isTransient(error)) {
        await _registry._remove(id);
        _record = null;
      }
      storageLogger.fine('Resumable upload $id failed', error, stackTrace);
      _registry._live.remove(id);
      _setStatus(ResumableUploadStatus.failed);
      _done.completeError(error, stackTrace);
    }
  }

  /// Whether the server no longer knows the upload, because it expired or
  /// was terminated.
  static bool _isGone(Exception error) =>
      error is StorageApiException &&
      (error.statusCode == 404 || error.statusCode == 410);

  /// Whether [step] can be repeated after failing with [error]. A chunk sent
  /// for another offset than the server holds is, once the offset is read
  /// again.
  static bool _isRetryable(Exception error, _Step step) => switch (error) {
    StorageTransportException() => true,
    StorageApiException(statusCode: 409) => step == _Step.append,
    StorageApiException() => _isTransient(error),
    _ => false,
  };

  /// Whether the upload may still succeed after the server answered with
  /// [exception], so its record is worth keeping.
  static bool _isTransient(StorageApiException exception) =>
      switch (exception.statusCode) {
        408 || 409 || 429 => true,
        final statusCode => statusCode >= 500,
      };

  Map<String, String> get _requestHeaders => _tusHeaders(_headers, _token);

  String get _uploadMetadata {
    String encode(String value) => base64.encode(utf8.encode(value));
    final metadata = _metadata;
    return [
      'bucketName ${encode(bucketId)}',
      'objectName ${encode(path)}',
      'contentType ${encode(_contentType)}',
      'cacheControl ${encode(_cacheControl)}',
      if (metadata != null) 'metadata ${encode(jsonEncode(metadata))}',
    ].join(',');
  }

  /// Creates the upload on the server and records it, returning whether that
  /// already completed it.
  Future<bool> _create(Future<void> abortSignal) async {
    final endpoint = Uri.parse(
      '${_registry.url}/upload/resumable${_token == null ? '' : '/sign'}',
    );
    final totalBytes = _totalBytes!;
    final response = await _registry.fetch.sendTus(
      HttpMethod.post,
      endpoint,
      {
        ..._requestHeaders,
        'Upload-Length': '$totalBytes',
        'Upload-Metadata': _uploadMetadata,
        if (_token == null) 'x-upsert': '$_upsert',
      },
      abortSignal: abortSignal,
    );
    if (response.statusCode != 201) {
      throw _registry.fetch.apiException(response);
    }
    if (response.headers['tus-complete'] == '1') {
      await _complete(response);
      return true;
    }
    final location = response.headers['location'];
    if (location == null) {
      throw StorageException(
        'Storage created the resumable upload without a Location header',
        requestId: response.headers.requestId,
      );
    }
    final record = _record = ResumableUploadRecord._(
      id: id,
      bucketId: bucketId,
      path: path,
      totalBytes: totalBytes,
      createdAt: DateTime.now().toUtc(),
      uploadUrl: endpoint.resolve(location),
      upsert: _upsert,
      contentType: _contentType,
      cacheControl: _cacheControl,
      metadata: _metadata,
      token: _token,
    );
    await _registry._save(record);
    _setBytesUploaded(0);
    return false;
  }

  /// Reads the offset the server holds, returning whether the upload is
  /// already complete.
  Future<bool> _resync(Future<void> abortSignal) async {
    final response = await _registry.fetch.sendTus(
      HttpMethod.head,
      _record!._uploadUrl,
      {..._requestHeaders, 'Cache-Control': 'no-store'},
      abortSignal: abortSignal,
    );
    _throwUnlessSuccessful(response);
    final offset = _offset(response);
    if (offset < _totalBytes!) {
      _setBytesUploaded(offset);
      return false;
    }
    if (response.headers['supabase-object-id'] == null) {
      await _registry._remove(id);
      _record = null;
      throw StorageException(
        'Storage received every byte of resumable upload $id but did not '
        'store the object',
        requestId: response.headers.requestId,
      );
    }
    await _complete(response);
    return true;
  }

  /// Sends the chunk at the confirmed offset, returning whether that
  /// completed the upload.
  Future<bool> _append(Future<void> abortSignal) async {
    final start = _bytesUploaded;
    final totalBytes = _totalBytes!;
    final end = start + _registry.options.chunkSize < totalBytes
        ? start + _registry.options.chunkSize
        : totalBytes;
    var sent = start;
    final response = await _registry.fetch.sendTus(
      HttpMethod.patch,
      _record!._uploadUrl,
      {
        ..._requestHeaders,
        'Upload-Offset': '$start',
        HttpHeader.contentType: 'application/offset+octet-stream',
        if (_token == null) 'x-upsert': '$_upsert',
      },
      createBody: () => _source.read(start, end).map((chunk) {
        sent += chunk.length;
        if (sent <= end) _setBytesUploaded(sent);
        return chunk;
      }),
      contentLength: end - start,
      abortSignal: abortSignal,
    );
    if (response.statusCode == 409) _setBytesUploaded(start);
    _throwUnlessSuccessful(response);
    final offset = _offset(response);
    _setBytesUploaded(offset);
    if (response.headers['tus-complete'] == '1' || offset >= totalBytes) {
      await _complete(response);
      return true;
    }
    return false;
  }

  void _throwUnlessSuccessful(http.Response response) {
    if (!isSuccessStatusCode(response.statusCode)) {
      throw _registry.fetch.apiException(response);
    }
  }

  int _offset(http.Response response) {
    final offset = int.tryParse(response.headers['upload-offset'] ?? '');
    if (offset == null) {
      throw StorageException(
        'Storage answered resumable upload $id without an Upload-Offset',
        requestId: response.headers.requestId,
      );
    }
    return offset;
  }

  Future<void> _complete(http.Response response) async {
    if (_record != null) await _registry._remove(id);
    _record = null;
    if (_status == ResumableUploadStatus.cancelled) return;
    _bytesUploaded = _totalBytes!;
    _setStatus(ResumableUploadStatus.completed);
    _finish();
    _done.complete(
      UploadResponse(
        id: response.headers['supabase-object-id'],
        path: path,
        fullPath: '$bucketId/$path',
        versionId: response.headers['supabase-object-version-id'],
      ),
    );
  }
}
