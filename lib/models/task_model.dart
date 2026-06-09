import 'dart:convert';

/// Represents a single student task with full tracking:
/// subject, priority, due date, completion status, completion note,
/// and a list of file/image attachment paths stored locally.
class Task {
  final String   id;
  String         title;
  String         description;
  String         subject;
  String         priority;       // 'High' | 'Medium' | 'Low'
  DateTime       dueDate;
  bool           isCompleted;
  DateTime?      completedAt;    // set when the task is marked done
  String         completionNote; // optional note added on completion
  List<String>   attachments;    // absolute file paths saved locally
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description    = '',
    required this.subject,
    required this.priority,
    required this.dueDate,
    this.isCompleted    = false,
    this.completedAt,
    this.completionNote = '',
    List<String>? attachments,
    required this.createdAt,
  }) : attachments = attachments ?? [];

  // ── Computed helpers ───────────────────────────────────────────────────────

  /// True if the task is past its due date and not yet completed.
  bool get isOverdue {
    final today = _dateOnly(DateTime.now());
    return !isCompleted && _dateOnly(dueDate).isBefore(today);
  }

  /// True if the due date is today (regardless of completion).
  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  /// Number of attachments attached to this task.
  int get attachmentCount => attachments.length;

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':             id,
    'title':          title,
    'description':    description,
    'subject':        subject,
    'priority':       priority,
    'dueDate':        dueDate.toIso8601String(),
    'isCompleted':    isCompleted,
    'completedAt':    completedAt?.toIso8601String(),
    'completionNote': completionNote,
    'attachments':    attachments,
    'createdAt':      createdAt.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id:             json['id']          as String,
    title:          json['title']        as String,
    description:    (json['description'] ?? '') as String,
    subject:        json['subject']      as String,
    priority:       json['priority']     as String,
    dueDate:        DateTime.parse(json['dueDate'] as String),
    isCompleted:    (json['isCompleted'] ?? false) as bool,
    completedAt:    json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
    completionNote: (json['completionNote'] ?? '') as String,
    attachments:    List<String>.from(
        (json['attachments'] as List?)?.map((e) => e.toString()) ?? []),
    createdAt:      DateTime.parse(json['createdAt'] as String),
  );

  String toJsonString() => jsonEncode(toJson());

  factory Task.fromJsonString(String s) =>
      Task.fromJson(jsonDecode(s) as Map<String, dynamic>);

  // ── copyWith ───────────────────────────────────────────────────────────────

  Task copyWith({
    String?        title,
    String?        description,
    String?        subject,
    String?        priority,
    DateTime?      dueDate,
    bool?          isCompleted,
    DateTime?      completedAt,
    String?        completionNote,
    List<String>?  attachments,
  }) =>
      Task(
        id:             id,
        title:          title          ?? this.title,
        description:    description    ?? this.description,
        subject:        subject        ?? this.subject,
        priority:       priority       ?? this.priority,
        dueDate:        dueDate        ?? this.dueDate,
        isCompleted:    isCompleted    ?? this.isCompleted,
        completedAt:    completedAt    ?? this.completedAt,
        completionNote: completionNote ?? this.completionNote,
        attachments:    attachments    ?? List<String>.from(this.attachments),
        createdAt:      createdAt,
      );

  // ── Internal ───────────────────────────────────────────────────────────────
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}