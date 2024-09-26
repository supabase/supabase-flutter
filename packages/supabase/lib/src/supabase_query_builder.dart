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
  })  : _realtime = realtime,
        _schema = schema,
        _table = table,
        _incrementId = incrementId,
        super(
          url: Uri.parse(url),
        );

  /// Combines the current state of your table from PostgREST with changes from the realtime server to return real-time data from your table as a [Stream].
  ///
  /// Realtime is disabled by default for new tables. You can turn it on by [managing replication](https://supabase.com/docs/guides/realtime/extensions/postgres-changes#replication-setup).
  ///
  /// Pass the list of primary key column names to [primaryKey], which will be used to update and delete the proper records internally as the stream receives real-time updates.
  ///
  /// It handles the lifecycle of the realtime connection and automatically refetches data from PostgREST when needed.
  ///
  /// Make sure to provide `onError` and `onDone` callbacks to [Stream.listen] to handle errors and completion of the stream.
  /// The stream gets closed when the realtime connection is closed.
  ///
  /// ```dart
  /// supabase.from('chats').stream(primaryKey: ['id']).listen(_onChatsReceived);
  /// ```
  ///
  /// `eq`, `neq`, `lt`, `lte`, `gt` or `gte` and `order`, `limit` filter are available to limit the data being queried.
  ///
  /// ```dart
  /// supabase.from('chats').stream(primaryKey: ['id']).eq('room_id','123').order('created_at').limit(20).listen(_onChatsReceived);
  /// ```
  SupabaseStreamFilterBuilder stream({required List<String> primaryKey}) {
    assert(primaryKey.isNotEmpty, 'Please specify primary key column(s).');
    return SupabaseStreamFilterBuilder(
      queryBuilder: this,
      realtimeClient: _realtime,
      realtimeTopic: '$_schema:$_table:$_incrementId',
      schema: _schema,
      table: _table,
      primaryKey: primaryKey,
    );
  }
}
