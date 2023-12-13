import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

class SupabaseQueryBuilder extends PostgrestQueryBuilder {
  final RealtimeClient _realtime;
  final String _schema;
  final String _table;
  final int _incrementId;

  SupabaseQueryBuilder(
    String url,
    RealtimeClient realtime, {
    Map<String, String> headers = const {},
    required String schema,
    required String table,
    Client? httpClient,
    required int incrementId,
    required YAJsonIsolate isolate,
  })  : _realtime = realtime,
        _schema = schema,
        _table = table,
        _incrementId = incrementId,
        super(
          url: Uri.parse(url),
          headers: headers,
          schema: schema,
          httpClient: httpClient,
          isolate: isolate,
        );

  /// Returns real-time data from your table as a `Stream`.
  ///
  /// Realtime is disabled by default for new tables. You can turn it on by [managing replication](https://supabase.com/docs/guides/realtime/extensions/postgres-changes#replication-setup).
  ///
  /// Pass the list of primary key column names to [primaryKey], which will be used to updating and deleting the proper records internally as the library receives real-time updates.
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
