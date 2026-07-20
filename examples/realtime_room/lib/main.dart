import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'room_channel.dart';
import 'room_repository.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const RealtimeRoomApp());
}

SupabaseClient get supabase => Supabase.instance.client;

class RealtimeRoomApp extends StatelessWidget {
  const RealtimeRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Realtime Room',
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const JoinPage(),
    );
  }
}

/// Asks for a display name before joining the room. Open the example in a second
/// window with a different name to see the realtime features in action.
class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  void _join() {
    final username = _username.text.trim();
    if (username.isEmpty) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => RoomPage(username: username),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Realtime room')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _username,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _join(),
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    hintText: 'e.g. Ada',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _join,
                  child: const Text('Join room'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The live room: a chat log kept in sync with Postgres Changes, an online
/// roster from Presence and typing indicators sent over Broadcast.
class RoomPage extends StatefulWidget {
  const RoomPage({required this.username, super.key});

  final String username;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  final _repository = RoomRepository(supabase);
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late final RoomChannel _channel = _repository.joinRoom(
    username: widget.username,
  );
  final List<StreamSubscription<void>> _subscriptions = [];

  List<Message> _messages = [];
  List<OnlineUser> _onlineUsers = [];
  final Set<String> _typingUsers = {};
  final Map<String, Timer> _typingTimers = {};
  Timer? _typingThrottle;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingThrottle?.cancel();
    unawaited(_channel.dispose());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Loads the existing messages, then joins the channel and wires the realtime
  /// streams into the UI.
  Future<void> _init() async {
    // Start listening before subscribing so no early event is missed.
    _subscriptions.addAll([
      _channel.onMessageInserted.listen(_addMessage),
      _channel.onMessageDeleted.listen(_removeMessage),
      _channel.onlineUsers.listen(
        (users) => setState(() => _onlineUsers = users),
      ),
      _channel.onTyping.listen(_showTyping),
    ]);

    try {
      final messages = await _repository.fetchMessages();
      if (mounted) setState(() => _messages = messages);
      await _channel.subscribe();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _scrollToBottom();
  }

  /// Appends a streamed message, ignoring one already in the list (a row could
  /// arrive both from the initial fetch and the insert stream).
  void _addMessage(Message message) {
    if (_messages.any((existing) => existing.id == message.id)) return;
    setState(() => _messages = [..._messages, message]);
    _scrollToBottom();
  }

  void _removeMessage(String id) {
    setState(() => _messages.removeWhere((message) => message.id == id));
  }

  /// Shows `<name> is typing` for a short while, resetting the timer each time a
  /// fresh ping arrives from that user.
  void _showTyping(String name) {
    _typingTimers[name]?.cancel();
    setState(() => _typingUsers.add(name));
    _typingTimers[name] = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _typingUsers.remove(name));
    });
  }

  /// Throttles typing pings so a burst of keystrokes sends at most one broadcast
  /// per second.
  void _onInputChanged(String _) {
    if (_typingThrottle?.isActive ?? false) return;
    _typingThrottle = Timer(const Duration(seconds: 1), () {});
    unawaited(_channel.sendTyping());
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repository.sendMessage(
        username: widget.username,
        content: content,
      );
      // The inserted row comes back through the Postgres Changes stream, which
      // is what adds it to the list, so there's nothing to add here.
      _input.clear();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime room'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _OnlineBar(users: _onlineUsers),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(child: Text('No messages yet. Say hi!'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _MessageTile(
                        message: message,
                        isMine: message.username == widget.username,
                        onDelete: () => _repository.deleteMessage(message.id),
                      );
                    },
                  ),
          ),
          _TypingIndicator(usernames: _typingUsers),
          const Divider(height: 1),
          _Composer(
            controller: _input,
            enabled: !_sending,
            onChanged: _onInputChanged,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _OnlineBar extends StatelessWidget {
  const _OnlineBar({required this.users});

  final List<OnlineUser> users;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          const Icon(Icons.circle, size: 10, color: Colors.greenAccent),
          const SizedBox(width: 8),
          for (final user in users)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(user.username),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.isMine,
    required this.onDelete,
  });

  final Message message;
  final bool isMine;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(message.username),
      subtitle: Text(message.content),
      trailing: isMine
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: onDelete,
            )
          : null,
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.usernames});

  final Set<String> usernames;

  @override
  Widget build(BuildContext context) {
    if (usernames.isEmpty) return const SizedBox(height: 20);
    final names = usernames.join(', ');
    final verb = usernames.length == 1 ? 'is' : 'are';
    return SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          '$names $verb typing…',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onChanged: onChanged,
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                hintText: 'Message',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

void _showError(Object error) {
  final message = error is PostgrestException
      ? error.message
      : error.toString();
  messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
