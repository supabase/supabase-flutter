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
/// channel fails to subscribe.
class RealtimeSubscribeException implements Exception {
  const RealtimeSubscribeException(this.status, [this.details]);

  /// The subscription status that caused this exception.
  ///
  /// When emitted by [SupabaseStreamBuilder], this is always
  /// [RealtimeSubscribeStatus.channelError] or
  /// [RealtimeSubscribeStatus.timedOut].
  final RealtimeSubscribeStatus status;

  /// The error reported alongside [status], if any.
  final Object? details;

  @override
  String toString() {
    return 'RealtimeSubscribeException(status: ${status.name}, details: '
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

  /// Contains the combined data of postgrest and realtime to emit as stream.
  SupabaseStreamEvent _streamData = [];

  /// Filters to be applied to the stream, combined with an `AND`
  final List<_StreamPostgrestFilter> _streamFilters = [];

  /// Which column to order by and whether it's ascending
  _Order? _orderBy;

  /// Count of record to be returned
  int? _limit;

  /// Flag that the stream has at least one time been subscribed to realtime
  bool _wasSubscribed = false;

  /// Orders the result with the specified [column].
  ///
  /// [ascending] defaults to `true`, matching SQL's `ORDER BY`, so results come
  /// back in ascending order unless `ascending: false` is passed.
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
    _streamController ??= ReplaySubject(
      onListen: () {
        _getStreamData();
      },
      onCancel: () {
        clientLogger.fine('stream controller for table: $_table got closed');
        unawaited(_changesSubscription?.cancel());
        unawaited(_statusSubscription?.cancel());
        _changesSubscription = null;
        _statusSubscription = null;
        unawaited(_channel?.unsubscribe());
        unawaited(_streamController?.close());
        _streamController = null;
      },
    );
  }

  void _getStreamData() {
    _streamData = [];
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

    _channel = _realtimeClient.channel(
      _realtimeTopic,
      RealtimeChannelConfig(
        private: _private,
      ),
    );

    _changesSubscription = _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: _schema,
          table: _table,
          filters: realtimeFilters,
          select: _effectiveSelect,
        )
        .listen((payload) {
          switch (payload.eventType) {
            // An insert can arrive for a row that a refetch after a
            // reconnect already returned, so it replaces that row.
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
              _addStream();
            case PostgresChangeEvent.delete:
              final deletedIndex = _streamData.indexWhere(
                (element) => _isTargetRecord(record: element, payload: payload),
              );
              if (deletedIndex >= 0) {
                /// Delete the data from in memory cache if it was found
                _streamData.removeAt(deletedIndex);
                _addStream();
              }
            case PostgresChangeEvent.all:
              break;
          }
        });
    _statusSubscription = _channel!.onStatusChange.listen((change) {
      switch (change.status) {
        case RealtimeSubscribeStatus.subscribed:
          // Reload all data from PostgREST after a realtime reconnect, so
          // that changes missed while the socket was down are picked up.
          // The first subscribe is skipped because the initial load is
          // already started below, right after subscribing.
          if (_wasSubscribed) {
            unawaited(_getPostgrestData());
          }
          _wasSubscribed = true;
        case RealtimeSubscribeStatus.closed:
          unawaited(_streamController?.close());
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.channelError:
          _addException(
            RealtimeSubscribeException(change.status, change.error),
          );
      }
    });
    _channel!.subscribe();
    unawaited(_getPostgrestData());
  }

  Future<void> _getPostgrestData() async {
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

    try {
      final data = await (transformQuery ?? query);
      final rows = SupabaseStreamEvent.of(data);
      _streamData = rows;
      _addStream();
    } catch (error, stackTrace) {
      _addException(error, stackTrace);
      // In case the postgrest call fails, there is no need to keep the
      // realtime connection open
      unawaited(_channel?.unsubscribe());
      unawaited(_streamController?.close());
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
