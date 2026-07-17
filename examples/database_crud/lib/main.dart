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

const _priorityLabels = {1: 'Low', 2: 'Medium', 3: 'High'};

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
  Timer? _debounce;

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
    try {
      final tasks = await _repository.fetchTasks(
        projectId: _projectFilter,
        search: _search.text.trim(),
        onlyIncomplete: _onlyIncomplete,
      );
      if (mounted) setState(() => _tasks = tasks);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Debounces the search field so typing doesn't fire a query per keystroke
  /// and race the responses back out of order.
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadTasks);
  }

  Future<void> _toggle(Task task) async {
    try {
      await _repository.setTaskComplete(
        id: task.id,
        isComplete: !task.isComplete,
      );
      await _loadTasks();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Task task) async {
    try {
      await _repository.deleteTask(task.id);
      await _loadTasks();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _create() async {
    final result = await showDialog<_TaskFormResult>(
      context: context,
      builder: (context) => _TaskDialog(projects: _projects),
    );
    if (result == null) return;
    try {
      await _repository.createTask(
        projectId: result.projectId,
        title: result.title,
        priority: result.priority,
      );
      await _loadTasks();
    } catch (error) {
      _showError(error);
    }
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
    try {
      await _repository.renameTask(id: task.id, title: title);
      await _loadTasks();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _projects.isEmpty ? null : _create,
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
          Row(
            children: [
              Checkbox(
                value: onlyIncomplete,
                onChanged: (value) => onOnlyIncompleteChanged(value ?? false),
              ),
              const Text('Only incomplete'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final priority = _priorityLabels[task.priority] ?? '${task.priority}';
    return ListTile(
      leading: Checkbox(
        value: task.isComplete,
        onChanged: (_) => onToggle(),
      ),
      title: Text(
        task.title,
        style: task.isComplete
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text('${task.projectName ?? 'Unknown'}  ·  $priority priority'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit), onPressed: onRename),
          IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
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
  final int priority;
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
  int _priority = 1;

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
          DropdownButtonFormField<int>(
            initialValue: _priority,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: [
              for (final entry in _priorityLabels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
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
