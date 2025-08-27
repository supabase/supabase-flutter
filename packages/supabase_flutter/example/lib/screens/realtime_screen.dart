import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeScreen extends StatefulWidget {
  const RealtimeScreen({super.key});

  @override
  State<RealtimeScreen> createState() => _RealtimeScreenState();
}

class _RealtimeScreenState extends State<RealtimeScreen> {
  final _messageController = TextEditingController();
  final _channelNameController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  String _channelName = 'public:messages';
  bool _isConnected = false;
  List<String> _onlineUsers = [];

  @override
  void initState() {
    super.initState();
    _channelNameController.text = _channelName;
    _subscribeToChannel();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _channelNameController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToChannel() {
    _channel?.unsubscribe();
    
    _channel = Supabase.instance.client.channel(_channelName);
    
    // Listen to database changes
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (mounted) {
              setState(() {
                if (payload.eventType == PostgresChangeEvent.insert) {
                  _messages.insert(0, payload.newRecord);
                } else if (payload.eventType == PostgresChangeEvent.update) {
                  final index = _messages.indexWhere(
                    (message) => message['id'] == payload.newRecord['id'],
                  );
                  if (index >= 0) {
                    _messages[index] = payload.newRecord;
                  }
                } else if (payload.eventType == PostgresChangeEvent.delete) {
                  _messages.removeWhere(
                    (message) => message['id'] == payload.oldRecord['id'],
                  );
                }
              });
            }
          },
        )
        .onBroadcast(
          event: 'message',
          callback: (payload) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Broadcast: ${payload['message']}'),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        )
        .onPresenceSync((payload) {
          if (mounted) {
            // Simple presence tracking - just show connected status
            setState(() {
              _onlineUsers = ['Connected Users']; // Placeholder for presence demo
            });
          }
        })
        .subscribe((status, [error]) {
          if (mounted) {
            setState(() {
              _isConnected = status == RealtimeSubscribeStatus.subscribed;
            });
            
            if (status == RealtimeSubscribeStatus.subscribed) {
              // Track presence
              _channel!.track({
                'user': 'User${DateTime.now().millisecondsSinceEpoch}',
                'online_at': DateTime.now().toIso8601String(),
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connected to realtime!'),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (status == RealtimeSubscribeStatus.channelError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connection error: ${error?.toString() ?? 'Unknown error'}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    
    try {
      // Insert into database (will trigger realtime update)
      await Supabase.instance.client.from('messages').insert({
        'content': _messageController.text,
        'user_id': Supabase.instance.client.auth.currentUser?.id ?? 'anonymous',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendBroadcast() async {
    if (_messageController.text.isEmpty) return;
    
    try {
      await _channel?.sendBroadcastMessage(
        event: 'message',
        payload: {'message': _messageController.text},
      );
      
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending broadcast: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _changeChannel() {
    final newChannel = _channelNameController.text;
    if (newChannel.isEmpty || newChannel == _channelName) return;
    
    setState(() {
      _channelName = newChannel;
      _messages.clear();
      _onlineUsers.clear();
    });
    
    _subscribeToChannel();
  }

  Future<void> _loadMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      
      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Examples'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isConnected ? 'Connected' : 'Disconnected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Channel Settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _channelNameController,
                            decoration: const InputDecoration(
                              labelText: 'Channel Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.tag),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _changeChannel,
                          child: const Text('Switch'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_onlineUsers.isNotEmpty) ...[
                      Text(
                        'Online Users (${_onlineUsers.length}):',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Wrap(
                        children: _onlineUsers.map((user) {
                          return Chip(
                            label: Text(user, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.green[100],
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Type a message',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.message),
                      ),
                      onFieldSubmitted: (_) => _sendMessage(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isConnected ? _sendMessage : null,
                            icon: const Icon(Icons.send),
                            label: const Text('Send to DB'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isConnected ? _sendBroadcast : null,
                            icon: const Icon(Icons.radio),
                            label: const Text('Broadcast'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Messages (${_messages.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: _loadMessages,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send a message to get started',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Note: This example requires a "messages" table in your Supabase database',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.orange[700],
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final content = message['content'] ?? '';
                        final userId = message['user_id'] ?? 'Unknown';
                        final createdAt = message['created_at'] ?? '';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(content),
                            subtitle: Text('From: $userId'),
                            trailing: Text(
                              _formatTimestamp(createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return timestamp;
    }
  }
}