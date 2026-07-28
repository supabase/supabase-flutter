import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'tasks_repository.dart';

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
  runApp(const CrudExampleApp());
}

SupabaseClient get supabase => Supabase.instance.client;

class CrudExampleApp extends StatelessWidget {
  const CrudExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Database CRUD',
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const TasksPage(),
    );
  }
}

/// Lists tasks with filtering, ordering and a join to their project, and lets
/// you create, update and delete them.
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _repository = TasksRepository(supabase);
  final _search = TextEditingController();

  List<Project> _projects = [];
  List<Task> _tasks = [];
  String? _projectFilter;
  bool _onlyIncomplete = false;
  bool _loading = true;
  bool _mutating = false;
  Timer? _debounce;

  /// Bumped on every task reload so a slower earlier request can't overwrite the
  /// results of a later one.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Loads the projects once, then the tasks for the current filters.
  Future<void> _init() async {
    try {
      final projects = await _repository.fetchProjects();
      if (mounted) setState(() => _projects = projects);
    } catch (error) {
      _showError(error);
    }
    await _loadTasks();
  }

  /// Reloads the task list for the current filters. Leaves the previous list on
  /// screen while it runs, so changing a filter or toggling a task doesn't flash
  /// a spinner over the whole list.
  Future<void> _loadTasks() async {
    final requestId = ++_requestId;
    // Ignore a response if a newer reload started or the widget went away while
    // this request was in flight.
    bool isStale() => !mounted || requestId != _requestId;
    try {
      final tasks = await _repository.fetchTasks(
        projectId: _projectFilter,
        search: _search.text.trim(),
        onlyIncomplete: _onlyIncomplete,
      );
      if (isStale()) return;
      setState(() => _tasks = tasks);
    } catch (error) {
      if (isStale()) return;
      _showError(error);
    } finally {
      if (!isStale()) setState(() => _loading = false);
    }
  }

  /// Debounces the search field so typing doesn't fire a query per keystroke
  /// and race the responses back out of order.
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadTasks);
  }

  /// Runs a single write, then reloads the list. Ignores the call if another
  /// write is already in flight, so a double tap can't fire duplicate requests.
  Future<void> _mutate(Future<void> Function() write) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await write();
      await _loadTasks();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _toggle(Task task) => _mutate(
    () => _repository.setTaskComplete(
      id: task.id,
      isComplete: !task.isComplete,
    ),
  );

  Future<void> _delete(Task task) =>
      _mutate(() => _repository.deleteTask(task.id));

  Future<void> _create() async {
    final result = await showDialog<_TaskFormResult>(
      context: context,
      builder: (context) => _TaskDialog(projects: _projects),
    );
    if (result == null) return;
    await _mutate(
      () => _repository.createTask(
        projectId: result.projectId,
        title: result.title,
        priority: result.priority,
      ),
    );
  }

  Future<void> _rename(Task task) async {
    final controller = TextEditingController(text: task.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    await _mutate(() => _repository.renameTask(id: task.id, title: title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _projects.isEmpty || _mutating ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: Column(
        children: [
          _Filters(
            projects: _projects,
            projectFilter: _projectFilter,
            search: _search,
            onlyIncomplete: _onlyIncomplete,
            onProjectChanged: (value) {
              setState(() => _projectFilter = value);
              unawaited(_loadTasks());
            },
            onSearchChanged: _onSearchChanged,
            onOnlyIncompleteChanged: (value) {
              setState(() => _onlyIncomplete = value);
              unawaited(_loadTasks());
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                ? const Center(child: Text('No tasks match these filters.'))
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return _TaskTile(
                          task: task,
                          enabled: !_mutating,
                          onToggle: () => _toggle(task),
                          onRename: () => _rename(task),
                          onDelete: () => _delete(task),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.projects,
    required this.projectFilter,
    required this.search,
    required this.onlyIncomplete,
    required this.onProjectChanged,
    required this.onSearchChanged,
    required this.onOnlyIncompleteChanged,
  });

  final List<Project> projects;
  final String? projectFilter;
  final TextEditingController search;
  final bool onlyIncomplete;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onOnlyIncompleteChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    labelText: 'Search title',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: projectFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Project',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(child: Text('All projects')),
                    for (final project in projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(project.name),
                      ),
                  ],
                  onChanged: onProjectChanged,
                ),
              ),
            ],
          ),
          CheckboxListTile(
            value: onlyIncomplete,
            onChanged: (value) => onOnlyIncompleteChanged(value ?? false),
            title: const Text('Only incomplete'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.enabled,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  final Task task;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: task.isComplete,
        onChanged: enabled ? (_) => onToggle() : null,
      ),
      title: Text(
        task.title,
        style: task.isComplete
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        '${task.projectName ?? 'Unknown'}  ·  ${task.priority.label} priority',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: enabled ? onRename : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: enabled ? onDelete : null,
          ),
        ],
      ),
    );
  }
}

class _TaskFormResult {
  const _TaskFormResult({
    required this.projectId,
    required this.title,
    required this.priority,
  });

  final String projectId;
  final String title;
  final Priority priority;
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.projects});

  final List<Project> projects;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final _title = TextEditingController();
  late String _projectId = widget.projects.first.id;
  Priority _priority = Priority.low;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _TaskFormResult(
        projectId: _projectId,
        title: title,
        priority: _priority,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _projectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Project'),
            items: [
              for (final project in widget.projects)
                DropdownMenuItem(
                  value: project.id,
                  child: Text(project.name),
                ),
            ],
            onChanged: (value) => setState(() => _projectId = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Priority>(
            initialValue: _priority,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: [
              for (final priority in Priority.values)
                DropdownMenuItem(value: priority, child: Text(priority.label)),
            ],
            onChanged: (value) => setState(() => _priority = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
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
