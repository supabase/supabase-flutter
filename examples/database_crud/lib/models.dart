import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_schema.g.dart';

/// How urgent a [Task] is. Stored in the database as the integer [value].
enum Priority {
  low(1, 'Low'),
  medium(2, 'Medium'),
  high(3, 'High');

  const Priority(this.value, this.label);

  factory Priority.fromValue(int value) =>
      values.firstWhere((priority) => priority.value == value);

  final int value;
  final String label;
}

/// A task as the example selects it: every column of `tasks` plus the name of
/// the project it belongs to, read through the generated column constants.
extension type const Task(PostgrestPartialRow<TasksRow> _row)
    implements Object {
  /// The selection that [Task] reads, the same as `*, projects(name)`.
  static final columns = [
    Tasks.table.allColumns,
    Tasks.projects(Projects.name),
  ];

  String get id => _row.read(Tasks.id);
  String get title => _row.read(Tasks.title);
  bool get isComplete => _row.read(Tasks.isComplete);
  Priority get priority => Priority.fromValue(_row.read(Tasks.priority));

  /// Name of the task's project, read from the embedded `projects` row.
  String? get projectName => _row.read(Tasks.projects)?.read(Projects.name);
}
