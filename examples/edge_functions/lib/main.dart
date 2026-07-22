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
/// function whose error response is surfaced to the user. Each card drives one
/// function through the shared [FunctionsRepository].
class FunctionsPage extends StatefulWidget {
  const FunctionsPage({super.key});

  @override
  State<FunctionsPage> createState() => _FunctionsPageState();
}

class _FunctionsPageState extends State<FunctionsPage> {
  final _repository = FunctionsRepository(supabase);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edge Functions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GreetCard(repository: _repository),
          const SizedBox(height: 16),
          _ShoutCard(repository: _repository),
          const SizedBox(height: 16),
          _WordCountCard(repository: _repository),
        ],
      ),
    );
  }
}

/// Invokes `greet` over POST and GET, both building the message server-side.
class _GreetCard extends StatefulWidget {
  const _GreetCard({required this.repository});

  final FunctionsRepository repository;

  @override
  State<_GreetCard> createState() => _GreetCardState();
}

class _GreetCardState extends State<_GreetCard> {
  final _name = TextEditingController(text: 'Ada');
  bool _excited = false;
  Greeting? _greeting;

  /// Which button is running (`post` or `get`), or null when idle, so only the
  /// tapped button shows a spinner and neither fires twice.
  String? _running;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(String key, Future<Greeting> Function() action) async {
    if (_running != null) return;
    setState(() => _running = key);
    try {
      final greeting = await action();
      if (mounted) setState(() => _greeting = greeting);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              running: _running == 'post',
              onPressed: () => _run(
                'post',
                () => widget.repository.greet(
                  name: _name.text.trim(),
                  excited: _excited,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _RunButton(
              label: 'Greet (GET)',
              filled: false,
              running: _running == 'get',
              onPressed: () => _run(
                'get',
                () => widget.repository.greetViaQuery(_name.text.trim()),
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
}

/// Invokes `shout`, which returns the text uppercased as plain text.
class _ShoutCard extends StatefulWidget {
  const _ShoutCard({required this.repository});

  final FunctionsRepository repository;

  @override
  State<_ShoutCard> createState() => _ShoutCardState();
}

class _ShoutCardState extends State<_ShoutCard> {
  final _text = TextEditingController(text: 'edge functions');
  String? _result;
  bool _running = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final result = await widget.repository.shout(_text.text);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Plain text',
      description:
          'Sends text to the shout function, which returns it uppercased as '
          'text/plain. A plain-text response arrives as a Dart String.',
      children: [
        TextField(
          controller: _text,
          decoration: const InputDecoration(labelText: 'Text to shout'),
        ),
        _RunButton(label: 'Shout', running: _running, onPressed: _run),
        if (_result case final result?) _Result(result),
      ],
    );
  }
}

/// Invokes `word-count`, which validates its input and responds with a 400 when
/// the text is empty, surfacing here as a [FunctionException].
class _WordCountCard extends StatefulWidget {
  const _WordCountCard({required this.repository});

  final FunctionsRepository repository;

  @override
  State<_WordCountCard> createState() => _WordCountCardState();
}

class _WordCountCardState extends State<_WordCountCard> {
  final _text = TextEditingController(text: 'Functions run close to the user');
  WordCount? _result;
  bool _running = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final result = await widget.repository.countWords(_text.text.trim());
      if (mounted) setState(() => _result = result);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Validation and errors',
      description:
          'Sends text to the word-count function. Clearing the field makes it '
          'respond with a 400, which surfaces as a FunctionException shown '
          'below.',
      children: [
        TextField(
          controller: _text,
          decoration: const InputDecoration(labelText: 'Text to count'),
        ),
        _RunButton(label: 'Count words', running: _running, onPressed: _run),
        if (_result case final result?)
          _Result('${result.words} words, ${result.characters} characters'),
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
