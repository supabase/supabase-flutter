import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:supabase/supabase.dart';

enum _FilterType { eq, neq, lt, lte, gt, gte, inFilter }

class _StreamPostgrestFilter {
  _StreamPostgrestFilter({
    required this.column,
    required this.value,
    required this.type,
  });

  /// Column name of the eq filter
  final String column;

  /// Value of the eq filter
  final dynamic value;

  /// Type of the filer being applied
  final _FilterType type;
}

class _Order {
  _Order({
    required this.column,
    required this.ascending,
  });
  final String column;
  final bool ascending;
}

typedef SupabaseStreamEvent = List<Map<String, dynamic>>;

class SupabaseStreamBuilder extends Stream<SupabaseStreamEvent> {
  final PostgrestQueryBuilder _queryBuilder;

  final RealtimeClient _realtimeClient;

  final String _realtimeTopic;

  RealtimeChannel? _channel;

  final String _schema;

  final String _table;

  /// Used to identify which row has changed
  final List<String> _uniqueColumns;

  /// StreamController for `stream()` method.
  BehaviorSubject<SupabaseStreamEvent>? _streamController;

  /// Contains the combined data of postgrest and realtime to emit as stream.
  SupabaseStreamEvent _streamData = [];

  /// `eq` filter used for both postgrest and realtime
  _StreamPostgrestFilter? _streamFilter;

  /// Which column to order by and whether it's ascending
  _Order? _orderBy;

  /// Count of record to be returned
  int? _limit;

  SupabaseStreamBuilder({
    required PostgrestQueryBuilder queryBuilder,
    required String realtimeTopic,
    required RealtimeClient realtimeClient,
    required String schema,
    required String table,
    required List<String> primaryKey,
  })  : _queryBuilder = queryBuilder,
        _realtimeTopic = realtimeTopic,
        _realtimeClient = realtimeClient,
        _schema = schema,
        _table = table,
        _uniqueColumns = primaryKey;

  /// Filters the results where [column] equals [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).eq('name', 'Supabase');
  /// ```
  SupabaseStreamBuilder eq(String column, dynamic value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.eq,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] does not equal [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).neq('name', 'Supabase');
  /// ```
  SupabaseStreamBuilder neq(String column, dynamic value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.neq,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is less than [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lt('likes', 100);
  /// ```
  SupabaseStreamBuilder lt(String column, dynamic value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.lt,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is less than or equal to [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).lte('likes', 100);
  /// ```
  SupabaseStreamBuilder lte(String column, dynamic value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.lte,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is greater than [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gt('likes', '100');
  /// ```
  SupabaseStreamBuilder gt(String column, dynamic value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.gt,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is greater than or equal to [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).gte('likes', 100);
  /// ```
  SupabaseStreamBuilder gte(String column, dynamic value) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.gte,
      column: column,
      value: value,
    );
    return this;
  }

  /// Filters the results where [column] is included in [value].
  ///
  /// Only one filter can be applied to `.stream()`.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).inFilter('name', ['Andy', 'Amy', 'Terry']);
  /// ```
  SupabaseStreamBuilder inFilter(String column, List<dynamic> values) {
    assert(
      _streamFilter == null,
      'Only one filter can be applied to `.stream()`',
    );
    _streamFilter = _StreamPostgrestFilter(
      type: _FilterType.inFilter,
      column: column,
      value: values,
    );
    return this;
  }

  /// Orders the result with the specified [column].
  ///
  /// When `ascending` value is true, the result will be in ascending order.
  ///
  /// ```dart
  /// supabase.from('users').stream(primaryKey: ['id']).order('username', ascending: false);
  /// ```
  SupabaseStreamBuilder order(String column, {bool ascending = false}) {
    _orderBy = _Order(column: column, ascending: ascending);
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

  @Deprecated('Directly listen without execute instead. Deprecated in 1.0.0')
  Stream<SupabaseStreamEvent> execute() {
    _setupStream();
    return _streamController!.stream;
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

  /// Sets up the stream controller and calls the method to get data as necessary
  void _setupStream() {
    _streamController ??= BehaviorSubject(
      onListen: () {
        _getStreamData();
      },
      onCancel: () {
        _channel?.unsubscribe();
        _streamController?.close();
        _streamController = null;
      },
    );
  }

  Future<void> _getStreamData() async {
    final currentStreamFilter = _streamFilter;
    _streamData = [];
    String? realtimeFilter;
    if (currentStreamFilter != null) {
      if (currentStreamFilter.type == _FilterType.inFilter) {
        final value = currentStreamFilter.value;
        if (value is List<String>) {
          realtimeFilter =
              '${currentStreamFilter.column}=in.(${value.map((s) => '"$s"').join(',')})';
        } else {
          realtimeFilter =
              '${currentStreamFilter.column}=in.(${value.join(',')})';
        }
      } else {
        realtimeFilter =
            '${currentStreamFilter.column}=${currentStreamFilter.type.name}.${currentStreamFilter.value}';
      }
    }

    _channel = _realtimeClient.channel(_realtimeTopic);
    _channel!.on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'INSERT',
          schema: _schema,
          table: _table,
          filter: realtimeFilter,
        ), (payload, [ref]) {
      final newRecord = Map<String, dynamic>.from(payload['new']!);
      _streamData.add(newRecord);
      _addStream();
    }).on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'UPDATE',
          schema: _schema,
          table: _table,
          filter: realtimeFilter,
        ), (payload, [ref]) {
      final updatedIndex = _streamData.indexWhere(
        (element) => _isTargetRecord(record: element, payload: payload),
      );

      final updatedRecord = Map<String, dynamic>.from(payload['new']!);
      if (updatedIndex >= 0) {
        _streamData[updatedIndex] = updatedRecord;
      } else {
        _streamData.add(updatedRecord);
      }
      _addStream();
    }).on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'DELETE',
          schema: _schema,
          table: _table,
          filter: realtimeFilter,
        ), (payload, [ref]) {
      final deletedIndex = _streamData.indexWhere(
        (element) => _isTargetRecord(record: element, payload: payload),
      );
      if (deletedIndex >= 0) {
        /// Delete the data from in memory cache if it was found
        _streamData.removeAt(deletedIndex);
        _addStream();
      }
    }).subscribe();

    PostgrestFilterBuilder query = _queryBuilder.select();
    if (_streamFilter != null) {
      switch (_streamFilter!.type) {
        case _FilterType.eq:
          query = query.eq(_streamFilter!.column, _streamFilter!.value);
          break;
        case _FilterType.neq:
          query = query.neq(_streamFilter!.column, _streamFilter!.value);
          break;
        case _FilterType.lt:
          query = query.lt(_streamFilter!.column, _streamFilter!.value);
          break;
        case _FilterType.lte:
          query = query.lte(_streamFilter!.column, _streamFilter!.value);
          break;
        case _FilterType.gt:
          query = query.gt(_streamFilter!.column, _streamFilter!.value);
          break;
        case _FilterType.gte:
          query = query.gte(_streamFilter!.column, _streamFilter!.value);
          break;
        case _FilterType.inFilter:
          query = query.in_(_streamFilter!.column, _streamFilter!.value);
          break;
      }
    }
    PostgrestTransformBuilder? transformQuery;
    if (_orderBy != null) {
      transformQuery =
          query.order(_orderBy!.column, ascending: _orderBy!.ascending);
    }
    if (_limit != null) {
      transformQuery = (transformQuery ?? query).limit(_limit!);
    }

    try {
      final data = await (transformQuery ?? query);
      final rows = SupabaseStreamEvent.from(data as List);
      _streamData.addAll(rows);
      _addStream();
    } catch (error, stackTrace) {
      _addException(error, stackTrace);
    }
  }

  bool _isTargetRecord({
    required Map<String, dynamic> record,
    required Map payload,
  }) {
    late final Map<String, dynamic> targetRecord;
    if (payload['eventType'] == 'UPDATE') {
      targetRecord = payload['new']!;
    } else if (payload['eventType'] == 'DELETE') {
      targetRecord = payload['old']!;
    }
    return _uniqueColumns
        .every((column) => record[column] == targetRecord[column]);
  }

  void _sortData() {
    final orderModifier = _orderBy!.ascending ? 1 : -1;
    _streamData.sort((a, b) {
      if (a[_orderBy!.column] is String && b[_orderBy!.column] is String) {
        return orderModifier *
            (a[_orderBy!.column] as String)
                .compareTo(b[_orderBy!.column] as String);
      } else if (a[_orderBy!.column] is int && b[_orderBy!.column] is int) {
        return orderModifier *
            (a[_orderBy!.column] as int).compareTo(b[_orderBy!.column] as int);
      } else {
        return 0;
      }
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
      FutureOr<E> Function(SupabaseStreamEvent event) convert) {
    // Copied from [Stream.asyncMap]

    final controller = BehaviorSubject<E>();

    controller.onListen = () {
      StreamSubscription<SupabaseStreamEvent> subscription = listen(null,
          onError: controller.addError, // Avoid Zone error replacement.
          onDone: controller.close);
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
          newValue.then(add, onError: addError).whenComplete(resume);
        } else {
          controller.add(newValue as dynamic);
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
      Stream<E>? Function(SupabaseStreamEvent event) convert) {
    //Copied from [Stream.asyncExpand]
    final controller = BehaviorSubject<E>();
    controller.onListen = () {
      StreamSubscription<SupabaseStreamEvent> subscription = listen(null,
          onError: controller.addError, // Avoid Zone error replacement.
          onDone: controller.close);
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
          controller.addStream(newStream).whenComplete(subscription.resume);
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
