import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'supabase_schema.g.dart';

/// All database access for the CRUD example lives here, so the UI stays thin
/// and every `supabase.table(...)` call is easy to read and to exercise from an
/// integration test.
///
/// The tables, columns and relations used here come from
/// `supabase_schema.g.dart`, which `supabase gen types --lang dart` generates
/// from the database schema, so a misspelled column or a value of the wrong
/// type is a compile error rather than a failed request.
class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  /// SELECT every project, ordered alphabetically by name.
  Future<List<ProjectsRow>> fetchProjects() =>
      _client.table(Projects.table).select().order(Projects.name.asc());

  /// SELECT tasks joined to their project, with optional filters and ordering.
  ///
  /// * [projectId] restricts to a single project (`eq`).
  /// * [search] matches the title case-insensitively (`ilike`).
  /// * [onlyIncomplete] hides finished tasks (`isFalse`).
  ///
  /// Results are ordered by priority (highest first) then newest first.
  Future<List<Task>> fetchTasks({
    String? projectId,
    String? search,
    bool onlyIncomplete = false,
  }) async {
    // Filters are values, so the optional ones are collected and combined
    // with `&` instead of reassigning the query builder.
    final filters = [
      if (projectId != null) Tasks.projectId.eq(projectId),
      if (search != null && search.isNotEmpty) Tasks.title.ilike('%$search%'),
      if (onlyIncomplete) Tasks.isComplete.isFalse(),
    ];

    // Embed the related project's name to demonstrate a join.
    var query = _client.table(Tasks.table).selectOnly(Task.columns);
    if (filters.isNotEmpty) {
      query = query.where(filters.reduce((all, filter) => all & filter));
    }

    final rows = await query
        .order(Tasks.priority.desc())
        .order(Tasks.createdAt.desc());
    return rows.map(Task.new).toList();
  }

  /// INSERT a task and return the created row (joined to its project).
  Future<Task> createTask({
    required String projectId,
    required String title,
    Priority priority = Priority.low,
  }) async {
    final row = await _client
        .table(Tasks.table)
        .insert(
          TasksInsert(
            projectId: projectId,
            title: title,
            priority: priority.value,
          ),
        )
        .selectOnly(Task.columns)
        .single();
    return Task(row);
  }

  /// UPDATE a task's completion state and return the updated row.
  Future<Task> setTaskComplete({
    required String id,
    required bool isComplete,
  }) => _updateTask(id, TasksUpdate(isComplete: isComplete));

  /// UPDATE a task's title and return the updated row.
  Future<Task> renameTask({required String id, required String title}) =>
      _updateTask(id, TasksUpdate(title: title));

  Future<Task> _updateTask(String id, TasksUpdate values) async {
    final row = await _client
        .table(Tasks.table)
        .update(values)
        .where(Tasks.id.eq(id))
        .selectOnly(Task.columns)
        .single();
    return Task(row);
  }

  /// Calls the `complete_all_tasks` database function, which marks every open
  /// task complete, or only those of [projectId] when given, and returns how
  /// many it changed.
  ///
  /// `client.rpc.completeAllTasks` is generated from the function's signature,
  /// so its parameters and result are typed like the table API.
  Future<int> completeAllTasks({String? projectId}) async =>
      await _client.rpc.completeAllTasks(targetProjectId: projectId) ?? 0;

  /// DELETE a task.
  Future<void> deleteTask(String id) async {
    await _client.table(Tasks.table).delete().where(Tasks.id.eq(id));
  }
}
