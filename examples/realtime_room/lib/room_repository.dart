import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'room_channel.dart';

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
  Future<List<Message>> fetchMessages() async {
    final rows = await _client.from('messages').select().order('created_at');
    return rows.map(Message.fromJson).toList();
  }

  /// INSERT a message and return the stored row.
  ///
  /// The insert is all that's needed to update every other client: the
  /// `messages` table is in the realtime publication, so the server streams this
  /// row to every subscribed [RoomChannel] as a Postgres Changes insert event.
  Future<Message> sendMessage({
    required String username,
    required String content,
  }) async {
    final row = await _client
        .from('messages')
        .insert({'username': username, 'content': content})
        .select()
        .single();
    return Message.fromJson(row);
  }

  /// DELETE a message, which likewise streams a delete event to every client.
  Future<void> deleteMessage(String id) async {
    await _client.from('messages').delete().eq('id', id);
  }

  /// Opens a realtime [RoomChannel] for [username] carrying the Postgres
  /// Changes, Broadcast and Presence streams for the room. Call
  /// [RoomChannel.subscribe] to join and [RoomChannel.dispose] to leave.
  RoomChannel joinRoom({required String username}) =>
      RoomChannel(client: _client, username: username);
}
