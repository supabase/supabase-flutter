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
      priority: json['priority'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      projectName: project?['name'] as String?,
    );
  }

  final String id;
  final String projectId;
  final String title;
  final bool isComplete;
  final int priority;
  final DateTime createdAt;

  /// Name of the task's project, populated from the embedded `projects` row when
  /// the task is fetched with a join.
  final String? projectName;
}
