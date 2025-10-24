import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Setup logging to see all instrumentation
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '${record.level.name}: ${DateFormat('HH:mm:ss.SSS').format(record.time)}: ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      debugPrint('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('  StackTrace: ${record.stackTrace}');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Token Refresh Debug App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SetupPage(),
    );
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeSupabase() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Supabase.initialize(
        url: _urlController.text.trim(),
        anonKey: _anonKeyController.text.trim(),
        debug: true,
      );

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _signIn() async {
    if (!_isInitialized) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DebugDashboard()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Token Refresh Debug'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Supabase Configuration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Supabase URL',
                hintText: 'https://your-project.supabase.co',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _anonKeyController,
              decoration: const InputDecoration(
                labelText: 'Anon Key',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading || _isInitialized
                  ? null
                  : _initializeSupabase,
              child: Text(_isInitialized ? 'Initialized ✓' : 'Initialize'),
            ),
            if (_isInitialized) ...[
              const SizedBox(height: 32),
              const Text(
                'Sign In',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                child: const Text('Sign In'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class DebugDashboard extends StatefulWidget {
  const DebugDashboard({super.key});

  @override
  State<DebugDashboard> createState() => _DebugDashboardState();
}

class _DebugDashboardState extends State<DebugDashboard>
    with WidgetsBindingObserver {
  final List<String> _logs = [];
  Timer? _refreshTimer;
  StreamSubscription<AuthState>? _authSubscription;
  String _appLifecycleState = 'resumed';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      _addLog('AUTH EVENT: ${data.event.name}');
      if (mounted) setState(() {});
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });

    _addLog('Dashboard initialized');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _appLifecycleState = state.name;
    });
    _addLog('APP LIFECYCLE: ${state.name}');
  }

  void _addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return 'EXPIRED ${duration.abs().inSeconds}s ago';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  Future<void> _testApiCall() async {
    _addLog('Testing API call...');
    try {
      final response = await Supabase.instance.client
          .from('test_table')
          .select()
          .limit(1);
      _addLog('API call successful: ${response.length} rows');
    } catch (e) {
      _addLog('API call failed: $e');
    }
  }

  Future<void> _manualRefresh() async {
    _addLog('Manually triggering token refresh...');
    try {
      await Supabase.instance.client.auth.refreshSession();
      _addLog('Manual refresh successful');
    } catch (e) {
      _addLog('Manual refresh failed: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SetupPage()),
        );
      }
    } catch (e) {
      _addLog('Sign out failed: $e');
    }
  }

  Widget _buildSessionInfo() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No active session',
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      );
    }

    final expiresAt = session.expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
        : null;
    final now = DateTime.now();
    final timeUntilExpiry = expiresAt?.difference(now);
    final isExpired = session.isExpired;

    return Card(
      color: isExpired ? Colors.red[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Status: ${isExpired ? "EXPIRED" : "Active"}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isExpired ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('User ID', session.user.id),
            _buildInfoRow('Email', session.user.email ?? 'N/A'),
            _buildInfoRow(
              'Expires At',
              expiresAt != null
                  ? DateFormat('HH:mm:ss').format(expiresAt)
                  : 'N/A',
            ),
            _buildInfoRow(
              'Time Until Expiry',
              timeUntilExpiry != null
                  ? _formatDuration(timeUntilExpiry)
                  : 'N/A',
            ),
            _buildInfoRow(
              'Access Token (first 20)',
              session.accessToken.substring(
                0,
                session.accessToken.length < 20
                    ? session.accessToken.length
                    : 20,
              ),
            ),
            _buildInfoRow(
              'Refresh Token Available',
              session.refreshToken != null ? 'Yes' : 'No',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _testApiCall,
              icon: const Icon(Icons.api),
              label: const Text('Test API Call'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _manualRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Manual Token Refresh'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'App State: $_appLifecycleState',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Event Log',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _logs.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Refresh Debug Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSessionInfo(),
            const SizedBox(height: 16),
            _buildControls(),
            const SizedBox(height: 16),
            _buildLogs(),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reproduction Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Configure your Supabase project with a short token expiry (e.g., 5 minutes)\n'
                      '2. Sign in and observe the session info\n'
                      '3. Use your device settings to minimize the app\n'
                      '4. Wait for the token to expire (check "Time Until Expiry")\n'
                      '5. Resume the app and observe behavior\n'
                      '6. Check logs in console for detailed flow\n'
                      '7. Try "Test API Call" to verify token is working\n\n'
                      'Expected: Token auto-refreshes on resume\n'
                      'Bug: Sometimes emits signedOut event instead',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
