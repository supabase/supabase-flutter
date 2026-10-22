import 'package:supabase_flutter/supabase_flutter.dart';

import 'room_channel.dart';
import 'supabase_schema.g.dart';

/// Database reads and writes for the room's chat history.
///
/// The persistent part of the example (loading and mutating the `messages`
/// table) lives here; the live realtime subscription lives in [RoomChannel].
/// Both take a [SupabaseClient] so the UI stays thin and each part is easy to
/// drive from an integration test.
class RoomRepository {
  RoomRepository(this._client);

  final SupabaseClient _client;

  /// SELECT the existing messages once, oldest first, to seed the chat log
  /// before realtime starts streaming new ones.
  Future<List<MessagesRow>> fetchMessages() =>
      _client.table(Messages.table).select().order(Messages.createdAt);

  /// INSERT a message and return the stored row.
  ///
  /// The insert is all that's needed to update every other client: the
  /// `messages` table is in the realtime publication, so the server streams
  /// this row to every subscribed [RoomChannel] as a Postgres Changes insert
  /// event.
  Future<MessagesRow> sendMessage({
    required String username,
    required String content,
  }) => _client
      .table(Messages.table)
      .insert(MessagesInsert(username: username, content: content))
      .select()
      .single();

  /// DELETE a message, which likewise streams a delete event to every client.
  Future<void> deleteMessage(String id) async {
    await _client.table(Messages.table).delete().where(Messages.id.eq(id));
  }

  /// Opens a realtime [RoomChannel] for [username] carrying the Postgres
  /// Changes, Broadcast and Presence streams for the room. Call
  /// [RoomChannel.subscribe] to join and [RoomChannel.dispose] to leave.
  RoomChannel joinRoom({required String username}) =>
      RoomChannel(client: _client, username: username);
}
