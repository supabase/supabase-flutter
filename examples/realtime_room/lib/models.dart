/// A chat message stored in the `messages` table. New rows are streamed to every
/// client in the room through realtime Postgres Changes.
class Message {
  const Message({
    required this.id,
    required this.username,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    username: json['username'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String username;
  final String content;
  final DateTime createdAt;
}

/// Someone currently connected to the room, surfaced through realtime Presence.
///
/// The fields come from the arbitrary payload this example tracks with
/// [RoomChannel.subscribe]; presence lets each client attach any JSON it likes.
class OnlineUser {
  const OnlineUser({required this.username, required this.onlineAt});

  factory OnlineUser.fromPresence(Map<String, dynamic> payload) => OnlineUser(
    username: payload['username'] as String,
    onlineAt: DateTime.parse(payload['online_at'] as String),
  );

  final String username;
  final DateTime onlineAt;
}
