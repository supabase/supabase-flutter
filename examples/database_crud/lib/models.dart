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

/// A project that groups tasks together.
class Project {
  const Project({required this.id, required this.name});

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String,
  );

  final String id;
  final String name;
}

/// A single task belonging to a [Project].
class Task {
  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    required this.isComplete,
    required this.priority,
    required this.createdAt,
    this.projectName,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // When the task is fetched with a join, the related project is nested under
    // the `projects` key.
    final project = json['projects'] as Map<String, dynamic>?;
    return Task(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String,
      isComplete: json['is_complete'] as bool,
      priority: Priority.fromValue(json['priority'] as int),
      createdAt: DateTime.parse(json['created_at'] as String),
      projectName: project?['name'] as String?,
    );
  }

  final String id;
  final String projectId;
  final String title;
  final bool isComplete;
  final Priority priority;
  final DateTime createdAt;

  /// Name of the task's project, populated from the embedded `projects` row when
  /// the task is fetched with a join.
  final String? projectName;
}
