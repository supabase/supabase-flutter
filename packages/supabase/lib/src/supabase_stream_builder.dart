import 'dart:async';

import 'package:supabase/src/logger.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_common/supabase_common.dart';

part 'supabase_stream_filter_builder.dart';

/// [column] name of the eq filter, [value] of the eq filter, and [type] of the
/// filter being applied.
typedef _StreamPostgrestFilter = ({
  String column,
  dynamic value,
  PostgresChangeFilterType type,
});

typedef _Order = ({String column, bool ascending});

/// Thrown by `SupabaseStreamBuilder.listen` when the underlying Realtime
/// channel fails to subscribe.
class RealtimeSubscribeException implements Exception {
  /// Creates an exception.
  const RealtimeSubscribeException(this.status, [this.details]);

  /// The subscription status that caused this exception, always
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
  }) : _queryBuilder = queryBuilder,
       _realtimeTopic = realtimeTopic,
       _realtimeClient = realtimeClient,
       _schema = schema,
       _table = table,
       _uniqueColumns = primaryKey,
       _private = private;
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
        )
        .listen((payload) {
          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
              final newRecord = payload.newRecord;
              _streamData.add(newRecord);
              _addStream();
            case PostgresChangeEvent.update:
              final updatedIndex = _streamData.indexWhere(
                (element) => _isTargetRecord(record: element, payload: payload),
              );

              final updatedRecord = payload.newRecord;
              if (updatedIndex >= 0) {
                _streamData[updatedIndex] = updatedRecord;
              } else {
                _streamData.add(updatedRecord);
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
    PostgrestFilterBuilder<PostgrestList> query = _queryBuilder.select();
    for (final filter in _streamFilters) {
      query = switch (filter.type) {
        PostgresChangeFilterType.eq => query.eq(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.neq => query.neq(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.lt => query.lt(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.lte => query.lte(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.gt => query.gt(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.gte => query.gte(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.inFilter => query.inFilter(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.like => query.like(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.ilike => query.ilike(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.match => query.matchRegex(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.imatch => query.imatchRegex(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.isFilter => query.isFilter(
          filter.column,
          filter.value,
        ),
        PostgresChangeFilterType.isDistinct => query.isDistinct(
          filter.column,
          filter.value,
        ),
      };
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
    late final Map<String, dynamic> targetRecord;
    if (payload.eventType == PostgresChangeEvent.update) {
      targetRecord = payload.newRecord;
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      targetRecord = payload.oldRecord;
    }
    return _uniqueColumns.every(
      (column) => record[column] == targetRecord[column],
    );
  }

  void _sortData() {
    final orderModifier = _orderBy!.ascending ? 1 : -1;
    _streamData.sort((a, b) {
      final columnA = a[_orderBy!.column];
      final columnB = b[_orderBy!.column];

      if (columnA is num && columnB is num) {
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
