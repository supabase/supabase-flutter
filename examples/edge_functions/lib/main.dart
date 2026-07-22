import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'functions_repository.dart';
import 'models.dart';

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
  runApp(const EdgeFunctionsExampleApp());
}

SupabaseClient get supabase => Supabase.instance.client;

class EdgeFunctionsExampleApp extends StatelessWidget {
  const EdgeFunctionsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Edge Functions',
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const FunctionsPage(),
    );
  }
}

/// Invokes the example's Edge Functions and shows what each one returns: a JSON
/// greeting (over POST and GET), a plain-text transform, and a validating
/// function whose error response is surfaced to the user.
class FunctionsPage extends StatefulWidget {
  const FunctionsPage({super.key});

  @override
  State<FunctionsPage> createState() => _FunctionsPageState();
}

class _FunctionsPageState extends State<FunctionsPage> {
  final _repository = FunctionsRepository(supabase);
  final _name = TextEditingController(text: 'Ada');
  final _shout = TextEditingController(text: 'edge functions');
  final _count = TextEditingController(text: 'Functions run close to the user');

  bool _excited = false;
  Greeting? _greeting;
  String? _shoutResult;
  WordCount? _wordCount;

  /// Name of the function whose button is currently running, so only that
  /// button shows a spinner and the others stay tappable.
  String? _running;

  @override
  void dispose() {
    _name.dispose();
    _shout.dispose();
    _count.dispose();
    super.dispose();
  }

  /// Runs [action] while marking [key] as in flight, then applies its result
  /// with [onResult]. Any error is shown in a snackbar.
  Future<void> _invoke<T>(
    String key,
    Future<T> Function() action,
    void Function(T result) onResult,
  ) async {
    if (_running != null) return;
    setState(() => _running = key);
    try {
      final result = await action();
      if (mounted) setState(() => onResult(result));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edge Functions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _greetCard(),
          const SizedBox(height: 16),
          _shoutCard(),
          const SizedBox(height: 16),
          _wordCountCard(),
        ],
      ),
    );
  }

  Widget _greetCard() {
    return _DemoCard(
      title: 'Greeting',
      description:
          'Invokes the greet function, which builds the message server-side. '
          'POST sends the name in a JSON body; GET sends it as a query '
          'parameter.',
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        CheckboxListTile(
          value: _excited,
          onChanged: (value) => setState(() => _excited = value ?? false),
          title: const Text('Excited'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        Row(
          children: [
            _RunButton(
              label: 'Greet (POST)',
              running: _running == 'greet-post',
              onPressed: () => _invoke(
                'greet-post',
                () => _repository.greet(
                  name: _name.text.trim(),
                  excited: _excited,
                ),
                (result) => _greeting = result,
              ),
            ),
            const SizedBox(width: 12),
            _RunButton(
              label: 'Greet (GET)',
              filled: false,
              running: _running == 'greet-get',
              onPressed: () => _invoke(
                'greet-get',
                () => _repository.greetViaQuery(_name.text.trim()),
                (result) => _greeting = result,
              ),
            ),
          ],
        ),
        if (_greeting case final greeting?)
          _Result(
            '${greeting.message}\n'
            'via ${greeting.method}, source "${greeting.source}"',
          ),
      ],
    );
  }

  Widget _shoutCard() {
    return _DemoCard(
      title: 'Plain text',
      description:
          'Sends text to the shout function, which returns it uppercased as '
          'text/plain. A plain-text response arrives as a Dart String.',
      children: [
        TextField(
          controller: _shout,
          decoration: const InputDecoration(labelText: 'Text to shout'),
        ),
        _RunButton(
          label: 'Shout',
          running: _running == 'shout',
          onPressed: () => _invoke(
            'shout',
            () => _repository.shout(_shout.text),
            (result) => _shoutResult = result,
          ),
        ),
        if (_shoutResult case final result?) _Result(result),
      ],
    );
  }

  Widget _wordCountCard() {
    return _DemoCard(
      title: 'Validation and errors',
      description:
          'Sends text to the word-count function. Clearing the field makes it '
          'respond with a 400, which surfaces as a FunctionException shown '
          'below.',
      children: [
        TextField(
          controller: _count,
          decoration: const InputDecoration(labelText: 'Text to count'),
        ),
        _RunButton(
          label: 'Count words',
          running: _running == 'count',
          onPressed: () => _invoke(
            'count',
            () => _repository.countWords(_count.text.trim()),
            (result) => _wordCount = result,
          ),
        ),
        if (_wordCount case final wordCount?)
          _Result(
            '${wordCount.words} words, ${wordCount.characters} characters',
          ),
      ],
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _RunButton extends StatelessWidget {
  const _RunButton({
    required this.label,
    required this.running,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final bool running;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = running
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    final onPressedOrNull = running ? null : onPressed;
    return filled
        ? FilledButton(onPressed: onPressedOrNull, child: child)
        : OutlinedButton(onPressed: onPressedOrNull, child: child);
  }
}

class _Result extends StatelessWidget {
  const _Result(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
  }
}

void _showError(Object error) {
  // A function that responds with a non-2xx status throws a FunctionException.
  // Its `details` hold the response body, which is the `{ "error": ... }` JSON
  // the word-count function returns when validation fails.
  String message;
  if (error is FunctionException) {
    final details = error.details;
    message = details is Map && details['error'] is String
        ? details['error'] as String
        : 'Function failed with status ${error.status}';
  } else {
    message = error.toString();
  }
  messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
