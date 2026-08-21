import 'package:supabase/supabase.dart';

class SupabaseQueryBuilder extends PostgrestQueryBuilder {
  final RealtimeClient _realtime;
  final String _schema;
  final String _table;
  final int _incrementId;

  SupabaseQueryBuilder(
    String url,
    RealtimeClient realtime, {
    super.headers = const {},
    required String super.schema,
    required String table,
    super.httpClient,
    required int incrementId,
    required super.isolate,
    super.retryOptions,
    super.requestTimeout,
  }) : _realtime = realtime,
       _schema = schema,
       _table = table,
       _incrementId = incrementId,
       super(
         url: Uri.parse(url),
       );

  /// Combines the current state of your table from PostgREST with changes from
  /// the realtime server to return real-time data from your table as a
  /// [Stream].
  ///
  /// Realtime is disabled by default for new tables. You can turn it on by
  /// [managing replication](https://supabase.com/docs/guides/realtime/subscribing-to-database-changes#enable-postgres-changes).
  ///
  /// Pass the list of primary key column names to [primaryKey], which will be
  /// used to update and delete the proper records internally as the stream
  /// receives realtime updates.
  ///
  /// The underlying [RealtimeChannel] is public by default. Set [private] to
  /// `true` to make it private, which requires additional RLS policies to be
  /// set up. See https://supabase.com/docs/guides/realtime/authorization for
  /// more details.
  ///
  /// It handles the life cycle of the realtime connection and automatically
  /// refetches data from PostgREST when needed.
  ///
  /// Make sure to provide `onError` and `onDone` callbacks to [Stream.listen]
  /// to handle errors and completion of the stream.
  /// The stream gets closed when the realtime connection is closed.
  ///
  /// Be aware of the following limitations when using streams:
  /// - When using filters like `eq` only realtime updates matching the filter
  ///   will be received. Therefore, an update that changes a record to no
  ///   longer match the filter will not be received, and the record will remain
  ///   in the stream.
  /// - By default, the old record of a DELETE event only contains the primary
  ///   key columns, so a filter on any other column never matches and the
  ///   deleted record remains in the stream. Set the replica identity of the
  ///   table to `full` to filter deletions on other columns as well. Refer to
  ///   the documentation about [receiving old records](https://supabase.com/docs/guides/realtime/postgres-changes?queryGroups=language&language=dart#receiving-old-records).
  ///
  /// ```dart
  /// supabase
  ///     .from('chats')
  ///     .stream(primaryKey: ['id'])
  ///     .listen(_onChatsReceived);
  /// ```
  ///
  /// `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `inFilter`, `like`, `ilike`,
  /// `matchRegex`, `imatchRegex`, `isFilter` and `isDistinct` are available to
  /// limit the data being queried. Multiple filters are combined with an `AND`.
  /// `order` and `limit` are available to sort and cap the result.
  ///
  /// ```dart
  /// supabase
  ///     .from('chats')
  ///     .stream(primaryKey: ['id'])
  ///     .eq('room_id', '123')
  ///     .order('created_at')
  ///     .limit(20)
  ///     .listen(_onChatsReceived);
  /// ```
  ///
  /// ```dart
  /// supabase
  ///     .from('chats')
  ///     .stream(primaryKey: ['id'])
  ///     .eq('room_id', '123')
  ///     .like('message', '%supabase%')
  ///     .listen(_onChatsReceived);
  /// ```
  SupabaseStreamFilterBuilder stream({
    required List<String> primaryKey,
    bool private = false,
  }) {
    assert(primaryKey.isNotEmpty, 'Please specify primary key column(s).');
    return SupabaseStreamFilterBuilder(
      queryBuilder: this,
      realtimeClient: _realtime,
      realtimeTopic: '$_schema:$_table:$_incrementId',
      schema: _schema,
      table: _table,
      primaryKey: primaryKey,
      private: private,
    );
  }
}
