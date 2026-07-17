import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// All database access for the CRUD example lives here, so the UI stays thin and
/// every `supabase.from(...)` call is easy to read and to exercise from an
/// integration test.
class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  /// Columns for a task plus its related project, used everywhere a task is
  /// returned so the join is consistent.
  static const _taskColumns = '*, projects(name)';

  /// SELECT every project, ordered alphabetically by name.
  Future<List<Project>> fetchProjects() async {
    final rows = await _client.from('projects').select().order('name');
    return rows.map(Project.fromJson).toList();
  }

  /// SELECT tasks joined to their project, with optional filters and ordering.
  ///
  /// * [projectId] restricts to a single project (`eq`).
  /// * [search] matches the title case-insensitively (`ilike`).
  /// * [onlyIncomplete] hides finished tasks (`eq`).
  ///
  /// Results are ordered by priority (highest first) then creation time.
  Future<List<Task>> fetchTasks({
    String? projectId,
    String? search,
    bool onlyIncomplete = false,
  }) async {
    // Embed the related project row (`projects(name)`) to demonstrate a join.
    var query = _client.from('tasks').select(_taskColumns);

    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    if (search != null && search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }
    if (onlyIncomplete) {
      query = query.eq('is_complete', false);
    }

    final rows = await query
        .order('priority', ascending: false)
        .order('created_at');
    return rows.map(Task.fromJson).toList();
  }

  /// INSERT a task and return the created row (joined to its project).
  Future<Task> createTask({
    required String projectId,
    required String title,
    int priority = 1,
  }) async {
    final row = await _client
        .from('tasks')
        .insert({
          'project_id': projectId,
          'title': title,
          'priority': priority,
        })
        .select(_taskColumns)
        .single();
    return Task.fromJson(row);
  }

  /// UPDATE a task's completion state and return the updated row.
  Future<Task> setTaskComplete({
    required String id,
    required bool isComplete,
  }) async {
    final row = await _client
        .from('tasks')
        .update({'is_complete': isComplete})
        .eq('id', id)
        .select(_taskColumns)
        .single();
    return Task.fromJson(row);
  }

  /// UPDATE a task's title and return the updated row.
  Future<Task> renameTask({required String id, required String title}) async {
    final row = await _client
        .from('tasks')
        .update({'title': title})
        .eq('id', id)
        .select(_taskColumns)
        .single();
    return Task.fromJson(row);
  }

  /// DELETE a task.
  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }
}
