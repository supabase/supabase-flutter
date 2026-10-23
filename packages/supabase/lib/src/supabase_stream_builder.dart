import 'dart:async';

import 'package:meta/meta.dart';
import 'package:supabase/src/logger.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_common/supabase_common.dart';

part 'supabase_stream_filter_builder.dart';

/// [column] name of the filter, [value] of the filter, [type] of the filter
/// being applied, and whether the filter is [negated].
typedef _StreamPostgrestFilter = ({
  String column,
  dynamic value,
  PostgresChangeFilterType type,
  bool negated,
});

typedef _Order = ({String column, bool ascending});

/// Delivered to the stream's error handler when the underlying Realtime
/// channel fails to subscribe and does not retry, for example because the
/// server declined the join.
class RealtimeSubscribeException extends RealtimeException {
  RealtimeSubscribeException(this.status, [this.details])
    : super(
        details is SupabaseException
            ? details.message
            : 'Realtime subscription failed with status ${status.name}',
      );

  /// The subscription status that caused this exception.
  ///
  /// When emitted by [SupabaseStreamBuilder], this is
  /// [RealtimeSubscribeStatus.channelError].
  final RealtimeSubscribeStatus status;

  /// The error reported alongside [status], if any.
  final Object? details;

  @override
  String get exceptionName => 'RealtimeSubscribeException';

  @override
  String toString() {
    return '$exceptionName(status: ${status.name}, details: '
        '$details)';
  }
}

/// A snapshot of the rows a `SupabaseStreamBuilder` stream emits.
typedef SupabaseStreamEvent = List<Map<String, dynamic>>;

/// A stream of a table's rows kept up to date over Realtime, created with
/// `SupabaseQueryBuilder.stream`.
class SupabaseStreamBuilder extends Stream<SupabaseStreamEvent> {
  SupabaseStreamBuilder({
    required PostgrestQueryBuilder queryBuilder,
    required String realtimeTopic,
    required RealtimeClient realtimeClient,
    required String schema,
    required String table,
    required List<String> primaryKey,
    required bool private,
    List<String>? select,
  }) : _queryBuilder = queryBuilder,
       _realtimeTopic = realtimeTopic,
       _realtimeClient = realtimeClient,
       _schema = schema,
       _table = table,
       _uniqueColumns = primaryKey,
       _private = private,
       _select = select == null
           ? null
           : [
               ...select,
               for (final column in primaryKey)
                 if (!select.contains(column)) column,
             ];
  final PostgrestQueryBuilder _queryBuilder;

  final RealtimeClient _realtimeClient;

  final String _realtimeTopic;

  /// Whether the underlying [_channel] should be initialized as private
  /// or not. Default is false, which means the channel is public.
  final bool _private;

  RealtimeChannel? _channel;

  final String _schema;

  final String _table;

  /// Used to identify which row has changed
  final List<String> _uniqueColumns;

  /// The columns asked for with `select`, `null` for every column. Always
  /// holds [_uniqueColumns], which the change payloads are matched to the rows
  /// by.
  final List<String>? _select;

  /// The columns PostgREST and the realtime server are asked for: [_select]
  /// plus the column of [_orderBy], which [_sortData] reads from every row.
  List<String>? get _effectiveSelect {
    final select = _select;
    final orderColumn = _orderBy?.column;
    if (select == null || orderColumn == null || select.contains(orderColumn)) {
      return select;
    }
    return [...select, orderColumn];
  }

  /// StreamController for `stream()` method.
  ReplaySubject<SupabaseStreamEvent>? _streamController;

  /// Subscription on the channel's postgres changes stream.
  StreamSubscription<PostgresChangePayload>? _changesSubscription;

  /// Subscription on the channel's subscription status stream.
  StreamSubscription<RealtimeSubscribeStatusChange>? _statusSubscription;

  /// Subscription on the channel's system events, which confirm that the
  /// server streams the changes.
  StreamSubscription<RealtimeSystemPayload>? _systemSubscription;

  /// Contains the combined data of postgrest and realtime to emit as stream.
  SupabaseStreamEvent _streamData = [];

  /// Filters to be applied to the stream, combined with an `AND`
  final List<_StreamPostgrestFilter> _streamFilters = [];

  /// Which column to order by and whether it's ascending
  _Order? _orderBy;

  /// Count of record to be returned
  int? _limit;

  /// The changes that arrived while a snapshot is being fetched, applied on
  /// top of it once it arrives. `null` when no snapshot is pending.
  List<PostgresChangePayload>? _pendingChanges;

  /// Identifies the latest snapshot fetch, so the result of a superseded or
  /// cancelled one is dropped.
  int _fetchId = 0;

  /// Whether a snapshot request is waiting for its response.
  bool _isFetching = false;

  /// Whether a snapshot has been fetched since the stream was listened to.
  bool _hasSnapshot = false;

  /// How many snapshot fetches in a row have failed.
  int _failedFetches = 0;

  /// Retries a failed snapshot fetch.
  Timer? _retryTimer;

  /// Whether the server confirmed that it streams the changes since the
  /// channel last joined.
  bool _isReplicating = false;

  /// Fetches the snapshot when the server does not confirm the replication
  /// within the timeout of the realtime client.
  Timer? _replicationTimer;

  /// Whether another snapshot is needed once the one in flight arrives.
  bool _refetchRequested = false;

  /// The status codes of client errors that a later fetch can recover from.
  static const _retryableClientErrors = {401, 408, 429};

  /// Orders the result with the specified [column].
  ///
  /// [ascending] defaults to `true`, matching SQL's `ORDER BY`, so results come
  /// back in ascending order unless `ascending: false` is passed.
  ///
  /// `null` values sort last in ascending order and first in descending order,
  /// matching PostgreSQL's default, both in the initial fetch and when a
  /// realtime change is merged into the stream.
  ///
  /// ```dart
  /// // Ascending is the default.
  /// supabase.from('users').stream(primaryKey: ['id']).order('username');
  /// ```
  ///
  /// ```dart
  /// // Descending has to be requested explicitly.
  /// supabase
  ///     .from('users')
  ///     .stream(primaryKey: ['id'])
  ///     .order('username', ascending: false);
  /// ```
  SupabaseStreamBuilder order(String column, {bool ascending = true}) {
    _orderBy = (column: column, ascending: ascending);
    return this;
  }

  /// Limits the result with the specified `count`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).limit(10);
  /// ```
  SupabaseStreamBuilder limit(int count) {
    _limit = count;
    return this;
  }

  @override
  StreamSubscription<SupabaseStreamEvent> listen(
    void Function(SupabaseStreamEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _setupStream();
    return _streamController!.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Sets up the stream controller and calls the method to get data as
  /// necessary
  void _setupStream() {
    if (_streamController != null) {
      return;
    }
    final controller = ReplaySubject<SupabaseStreamEvent>(
      onListen: _getStreamData,
    );
    controller.onCancel = () {
      if (_streamController == controller) {
        clientLogger.fine('stream controller for table: $_table got closed');
        _tearDown();
      }
    };
    _streamController = controller;
  }

  /// Stops listening to the channel, leaves it unless [leaveChannel] is
  /// false, and closes the stream.
  void _tearDown({bool leaveChannel = true}) {
    _fetchId++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _replicationTimer?.cancel();
    _replicationTimer = null;
    _pendingChanges = null;
    unawaited(_changesSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    unawaited(_systemSubscription?.cancel());
    _changesSubscription = null;
    _statusSubscription = null;
    _systemSubscription = null;
    if (leaveChannel) {
      unawaited(_channel?.unsubscribe());
    }
    _channel = null;
    final controller = _streamController;
    _streamController = null;
    unawaited(controller?.close());
  }

  void _getStreamData() {
    _streamData = [];
    _hasSnapshot = false;
    _isFetching = false;
    _failedFetches = 0;
    _isReplicating = false;
    _refetchRequested = false;
    _pendingChanges = [];
    final realtimeFilters = _streamFilters
        .map(
          (filter) => PostgresChangeFilter(
            column: filter.column,
            type: filter.type,
            value: filter.value,
            negate: filter.negated,
          ),
        )
        .toList();

    final channel = _channel = _realtimeClient.channel(
      _realtimeTopic,
      RealtimeChannelConfig(
        private: _private,
      ),
    );

    _changesSubscription = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: _schema,
          table: _table,
          filters: realtimeFilters,
          select: _effectiveSelect,
        )
        .listen(_onChange);
    _systemSubscription = channel.onSystemEvents.listen((event) {
      if (event.extension == 'postgres_changes' && event.status == 'ok') {
        _isReplicating = true;
        _replicationTimer?.cancel();
        _replicationTimer = null;
        unawaited(_fetchSnapshot());
      }
    });
    _statusSubscription = channel.onStatusChange.listen((change) {
      switch (change.status) {
        case RealtimeSubscribeStatus.subscribed:
          if (!_isReplicating) {
            _replicationTimer?.cancel();
            _replicationTimer = Timer(_realtimeClient.timeout, () {
              _replicationTimer = null;
              unawaited(_fetchSnapshot());
            });
          }
        case RealtimeSubscribeStatus.closed:
          _tearDown(leaveChannel: false);
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.channelError:
          _isReplicating = false;
          _replicationTimer?.cancel();
          _replicationTimer = null;
          if (!_hasSnapshot && !_isFetching && _retryTimer == null) {
            unawaited(_fetchSnapshot());
          }
          // ignore: invalid_use_of_internal_member
          if (channel.isErrored) {
            clientLogger.fine(
              'stream channel for table: $_table rejoins after '
              '${change.status.name}',
              change.error,
            );
          } else {
            _addException(
              RealtimeSubscribeException(change.status, change.error),
            );
          }
      }
    });
    channel.subscribe();
  }

  void _onChange(PostgresChangePayload payload) {
    if (payload.eventType
        case PostgresChangeEvent.all || PostgresChangeEvent.unknown) {
      return;
    }
    final errors = payload.errors;
    if (errors is List && errors.isNotEmpty) {
      clientLogger.fine(
        'refetching table: $_table after a ${payload.eventType.name} arrived '
        'without its full record: ${errors.join(', ')}',
      );
      _requestRefetch();
      return;
    }
    final pendingChanges = _pendingChanges;
    if (pendingChanges != null) {
      pendingChanges.add(payload);
      return;
    }
    if (_hasSnapshot && _applyChange(payload)) {
      _addStream();
    }
  }

  /// Fetches a new snapshot once the one in flight or the pending retry is
  /// done, so that a burst of changes causes one fetch.
  void _requestRefetch() {
    if (_isFetching) {
      _refetchRequested = true;
    } else if (_retryTimer == null) {
      unawaited(_fetchSnapshot());
    }
  }

  /// Applies [payload] to [_streamData], and returns whether it changed.
  bool _applyChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert || PostgresChangeEvent.update:
        final index = _streamData.indexWhere(
          (element) => _isTargetRecord(record: element, payload: payload),
        );

        final record = payload.newRecord;
        if (index >= 0) {
          _streamData[index] = record;
        } else {
          _streamData.add(record);
        }
        return true;
      case PostgresChangeEvent.delete:
        final deletedIndex = _streamData.indexWhere(
          (element) => _isTargetRecord(record: element, payload: payload),
        );
        if (deletedIndex < 0) {
          return false;
        }
        _streamData.removeAt(deletedIndex);
        return true;
      case PostgresChangeEvent.all || PostgresChangeEvent.unknown:
        return false;
    }
  }

  /// Fetches the rows from PostgREST and replaces [_streamData] with them,
  /// applying the changes that arrived in the meantime on top.
  ///
  /// A failed fetch is retried with the backoff of the realtime client, and
  /// only the first failure in a row is added to the stream. A client error
  /// that a retry cannot fix is added and closes the stream. Until the retry,
  /// changes are applied to the previous snapshot, if there is one.
  Future<void> _fetchSnapshot() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    final fetchId = ++_fetchId;
    _pendingChanges = [];
    _isFetching = true;
    _refetchRequested = false;

    PostgrestFilterBuilder<PostgrestList> query = _queryBuilder.select(
      _effectiveSelect?.join(',') ?? '*',
    );
    for (final filter in _streamFilters) {
      final token = filter.type.token;
      query = filter.negated
          ? query.not(filter.column, token, filter.value)
          : query.filter(filter.column, token, filter.value);
    }
    PostgrestTransformBuilder<PostgrestList>? transformQuery;
    if (_orderBy != null) {
      transformQuery = query.order(
        _orderBy!.column,
        ascending: _orderBy!.ascending,
      );
    }
    if (_limit != null) {
      transformQuery = (transformQuery ?? query).limit(_limit!);
    }

    final PostgrestList data;
    try {
      data = await (transformQuery ?? query);
    } catch (error, stackTrace) {
      if (fetchId != _fetchId) {
        return;
      }
      _isFetching = false;
      _pendingChanges = null;
      _failedFetches++;
      clientLogger.warning(
        'fetching the rows of table: $_table failed',
        error,
        stackTrace,
      );
      if (error is PostgrestApiException &&
          error.statusCode >= 400 &&
          error.statusCode < 500 &&
          !_retryableClientErrors.contains(error.statusCode)) {
        _addException(error, stackTrace);
        _tearDown();
        return;
      }
      if (_failedFetches == 1) {
        _addException(error, stackTrace);
      }
      _retryTimer = Timer(
        _realtimeClient.reconnectAfter(_failedFetches),
        () => unawaited(_fetchSnapshot()),
      );
      return;
    }
    if (fetchId != _fetchId) {
      return;
    }
    _isFetching = false;
    _failedFetches = 0;
    _hasSnapshot = true;
    _streamData = SupabaseStreamEvent.of(data);
    final pendingChanges = _pendingChanges ?? const [];
    _pendingChanges = null;
    pendingChanges.forEach(_applyChange);
    _addStream();
    if (_refetchRequested) {
      unawaited(_fetchSnapshot());
    }
  }

  bool _isTargetRecord({
    required Map<String, dynamic> record,
    required PostgresChangePayload payload,
  }) {
    final targetRecord = payload.eventType == PostgresChangeEvent.delete
        ? payload.oldRecord
        : payload.newRecord;
    return _uniqueColumns.every(
      (column) => record[column] == targetRecord[column],
    );
  }

  void _sortData() {
    final orderModifier = _orderBy!.ascending ? 1 : -1;
    _streamData.sort((a, b) {
      final columnA = a[_orderBy!.column];
      final columnB = b[_orderBy!.column];

      if (columnA == null) {
        return columnB == null ? 0 : orderModifier;
      } else if (columnB == null) {
        return -orderModifier;
      } else if (columnA is num && columnB is num) {
        return orderModifier * columnA.compareTo(columnB);
      } else if (columnA is String && columnB is String) {
        return orderModifier * columnA.compareTo(columnB);
      } else if (columnA is bool && columnB is bool) {
        return orderModifier * (columnA ? 1 : 0).compareTo(columnB ? 1 : 0);
      }
      return 0;
    });
  }

  /// Will add new data to the stream if streamController is not closed
  void _addStream() {
    if (_orderBy != null) {
      _sortData();
    }
    if (!(_streamController?.isClosed ?? true)) {
      final emitData =
          (_limit != null ? _streamData.take(_limit!) : _streamData).toList();
      _streamController!.add(emitData);
    }
  }

  /// Will add error to the stream if streamController is not closed
  void _addException(Object error, [StackTrace? stackTrace]) {
    if (!(_streamController?.isClosed ?? true)) {
      _streamController?.addError(error, stackTrace ?? StackTrace.current);
    }
  }

  @override
  bool get isBroadcast => true;

  @override
  Stream<E> asyncMap<E>(
    FutureOr<E> Function(SupabaseStreamEvent event) convert,
  ) {
    // Copied from [Stream.asyncMap]

    final controller = ReplaySubject<E>();

    controller.onListen = () {
      StreamSubscription<SupabaseStreamEvent> subscription = listen(
        null,
        onError: controller.addError, // Avoid Zone error replacement.
        onDone: () => unawaited(controller.close()),
      );
      FutureOr<void> add(E value) {
        controller.add(value);
      }

      final addError = controller.addError;
      final resume = subscription.resume;
      subscription.onData((SupabaseStreamEvent event) {
        FutureOr<E> newValue;
        try {
          newValue = convert(event);
        } catch (e, s) {
          controller.addError(e, s);
          return;
        }
        if (newValue is Future<E>) {
          subscription.pause();
          unawaited(newValue.then(add, onError: addError).whenComplete(resume));
        } else {
          controller.add(newValue);
        }
      });
      controller.onCancel = subscription.cancel;
      if (!isBroadcast) {
        controller
          ..onPause = subscription.pause
          ..onResume = resume;
      }
    };
    return controller.stream;
  }

  @override
  Stream<E> asyncExpand<E>(
    Stream<E>? Function(SupabaseStreamEvent event) convert,
  ) {
    //Copied from [Stream.asyncExpand]
    final controller = ReplaySubject<E>();
    controller.onListen = () {
      StreamSubscription<SupabaseStreamEvent> subscription = listen(
        null,
        onError: controller.addError, // Avoid Zone error replacement.
        onDone: () => unawaited(controller.close()),
      );
      subscription.onData((SupabaseStreamEvent event) {
        Stream<E>? newStream;
        try {
          newStream = convert(event);
        } catch (e, s) {
          controller.addError(e, s);
          return;
        }
        if (newStream != null) {
          subscription.pause();
          unawaited(
            controller.addStream(newStream).whenComplete(subscription.resume),
          );
        }
      });
      controller.onCancel = subscription.cancel;
      if (!isBroadcast) {
        controller
          ..onPause = subscription.pause
          ..onResume = subscription.resume;
      }
    };
    return controller.stream;
  }
}
