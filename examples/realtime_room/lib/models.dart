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
