import 'dart:convert';
import 'dart:io';

import 'queryable.dart';

/// The database `supabase db query` connects to.
sealed class DatabaseTarget {
  const DatabaseTarget();

  /// The `supabase db query` flags selecting this target.
  List<String> get arguments;
}

/// The database of the local Supabase stack started with `supabase start`.
final class LocalDatabase extends DatabaseTarget {
  /// Creates the local stack target.
  const LocalDatabase();

  @override
  List<String> get arguments => const ['--local'];
}

/// The database of the project linked with `supabase link`, or of
/// [projectRef], reached through the Management API with the credentials of
/// `supabase login`.
final class LinkedProject extends DatabaseTarget {
  /// Creates the linked project target, optionally overriding the linked
  /// project with [projectRef].
  const LinkedProject({this.projectRef});

  /// The project ref to query instead of the linked one.
  final String? projectRef;

  @override
  List<String> get arguments => [
    '--linked',
    if (projectRef != null) ...['--project-ref', projectRef!],
  ];
}

/// Any Postgres database, by connection string.
final class DatabaseUrl extends DatabaseTarget {
  /// Creates the connection string target.
  const DatabaseUrl(this.url);

  /// The `postgresql://` connection string.
  final String url;

  @override
  List<String> get arguments => ['--db-url', url];
}

/// Thrown when `supabase db query` cannot run or fails, with a [message]
/// that tells the user what to do.
class SupabaseCliException implements Exception {
  /// Creates the exception carrying [message].
  const SupabaseCliException(this.message);

  /// What went wrong and how to fix it.
  final String message;

  @override
  String toString() => message;
}

/// A [Queryable] that runs its queries through `supabase db query`, so the
/// Supabase CLI resolves and authenticates the connection.
///
/// All queries go out as one statement that aggregates each result with
/// `json_agg`, one round trip per introspection.
class SupabaseCliQueryable implements Queryable {
  /// Creates a [Queryable] for [target] using the [executable] on `PATH`.
  const SupabaseCliQueryable(this.target, {this.executable = 'supabase'});

  /// Where to connect.
  final DatabaseTarget target;

  /// The Supabase CLI binary.
  final String executable;

  @override
  Future<Map<String, List<Map<String, dynamic>>>> query(
    Map<String, String> queries,
  ) async {
    final directory = Directory.systemTemp.createTempSync('supabase_typegen_');
    try {
      final file = File('${directory.path}/introspection.sql')
        ..writeAsStringSync(combineQueries(queries));
      final ProcessResult result;
      try {
        result = await Process.run(executable, [
          'db',
          'query',
          ...target.arguments,
          '--output',
          'json',
          '--file',
          file.absolute.path,
        ]);
      } on ProcessException {
        throw const SupabaseCliException(
          'The Supabase CLI was not found on PATH. Install it from '
          'https://supabase.com/docs/guides/cli/getting-started and try '
          'again.',
        );
      }
      if (result.exitCode != 0) {
        throw SupabaseCliException(
          describeFailure(_stripAnsi(result.stderr as String)),
        );
      }
      return _rows(result.stdout as String, queries.keys);
    } finally {
      directory.deleteSync(recursive: true);
    }
  }
}

/// Folds [queries] into one `SELECT` with a `json_agg` column per query, so
/// a single `supabase db query` call returns every result set.
String combineQueries(Map<String, String> queries) => [
  'select',
  [
    for (final MapEntry(key: name, value: sql) in queries.entries)
      '  (select coalesce(json_agg(t), \'[]\'::json) from (\n'
          '$sql\n'
          '  ) t) as "$name"',
  ].join(',\n'),
].join('\n');

/// Turns the stderr of a failed `supabase db query` into the message shown
/// to the user, with dedicated wording for the setup problems the tool can
/// name.
String describeFailure(String stderr) {
  final output = stderr
      .split('\n')
      .where((line) => !line.startsWith('Connecting to '))
      .join('\n')
      .trim();
  if (output.contains('Access token not provided')) {
    return 'The Supabase CLI is not logged in. Run `supabase login`, or set '
        'SUPABASE_ACCESS_TOKEN, and try again.';
  }
  if (output.contains('Cannot find project ref')) {
    return 'No linked Supabase project was found. Run `supabase link` in '
        'your project directory, or pass --project-ref.';
  }
  return 'supabase db query failed:\n$output';
}

Map<String, List<Map<String, dynamic>>> _rows(
  String stdout,
  Iterable<String> names,
) {
  final Object? decoded;
  try {
    decoded = jsonDecode(stdout);
  } on FormatException {
    throw SupabaseCliException(
      'supabase db query did not return JSON:\n${stdout.trim()}',
    );
  }
  // Older CLI releases print the rows as a bare array; newer ones wrap them
  // in an object next to advisories and warnings.
  final rows = switch (decoded) {
    final List<dynamic> list => list,
    {'rows': final List<dynamic> list} => list,
    _ => null,
  };
  if (rows == null || rows.length != 1) {
    throw const SupabaseCliException(
      'supabase db query returned an unexpected result shape.',
    );
  }
  final row = rows.single as Map<String, dynamic>;
  return {
    for (final name in names)
      name: (row[name] as List<dynamic>).cast<Map<String, dynamic>>(),
  };
}

final _ansi = RegExp(r'\x1B\[[0-9;]*m');

String _stripAnsi(String text) => text.replaceAll(_ansi, '');
