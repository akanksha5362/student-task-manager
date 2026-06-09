import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_task_manager/models/task_model.dart';
import 'constants.dart';

/// All SharedPreferences CRUD operations for [Task] objects,
/// plus helpers for copying attachment files into local app storage.
class TaskService {
  TaskService._(); // prevent instantiation

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns every saved task, or [] on any error.
  static Future<List<Task>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getStringList(PrefKeys.taskList) ?? [];
      return raw.map(Task.fromJsonString).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Overwrites the full task list in storage.
  static Future<bool> saveTasks(List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setStringList(
        PrefKeys.taskList,
        tasks.map((t) => t.toJsonString()).toList(),
      );
    } catch (_) {
      return false;
    }
  }

  /// Appends [task] to the stored list.
  static Future<bool> addTask(Task task) async {
    final tasks = await loadTasks();
    tasks.add(task);
    return saveTasks(tasks);
  }

  /// Replaces the task whose id matches [updated].
  static Future<bool> updateTask(Task updated) async {
    final tasks = await loadTasks();
    final i = tasks.indexWhere((t) => t.id == updated.id);
    if (i == -1) return false;
    tasks[i] = updated;
    return saveTasks(tasks);
  }

  /// Deletes a task and all its locally-stored attachment files.
  static Future<bool> deleteTask(String taskId) async {
    final tasks = await loadTasks();
    final task  = tasks.firstWhere((t) => t.id == taskId,
        orElse: () => throw StateError('not found'));
    // Delete attachment files from disk
    for (final path in task.attachments) {
      try { await File(path).delete(); } catch (_) {}
    }
    tasks.removeWhere((t) => t.id == taskId);
    return saveTasks(tasks);
  }

  /// Toggles [Task.isCompleted] and records/clears [Task.completedAt].
  static Future<bool> toggleComplete(String taskId) async {
    final tasks = await loadTasks();
    final i     = tasks.indexWhere((t) => t.id == taskId);
    if (i == -1) return false;
    final current = tasks[i];
    tasks[i] = current.copyWith(
      isCompleted: !current.isCompleted,
      completedAt: !current.isCompleted ? DateTime.now() : null,
    );
    return saveTasks(tasks);
  }

  /// Marks a task complete and saves an optional [note].
  static Future<bool> markComplete(String taskId, {String note = ''}) async {
    final tasks = await loadTasks();
    final i     = tasks.indexWhere((t) => t.id == taskId);
    if (i == -1) return false;
    tasks[i] = tasks[i].copyWith(
      isCompleted:    true,
      completedAt:    DateTime.now(),
      completionNote: note,
    );
    return saveTasks(tasks);
  }

  // ── Attachment helpers ─────────────────────────────────────────────────────

  /// Copies [sourceFile] into the app's documents directory under a
  /// `task_attachments/<taskId>/` folder and returns the new absolute path.
  static Future<String> saveAttachment(String taskId, File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dest   = Directory(
        p.join(appDir.path, 'task_attachments', taskId));
    if (!dest.existsSync()) dest.createSync(recursive: true);

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourceFile.path)}';
    final saved    = await sourceFile.copy(p.join(dest.path, fileName));
    return saved.path;
  }

  /// Removes [filePath] from disk and from the task's attachment list.
  static Future<bool> deleteAttachment(String taskId, String filePath) async {
    try { await File(filePath).delete(); } catch (_) {}
    final tasks = await loadTasks();
    final i     = tasks.indexWhere((t) => t.id == taskId);
    if (i == -1) return false;
    final updated = List<String>.from(tasks[i].attachments)
      ..remove(filePath);
    tasks[i] = tasks[i].copyWith(attachments: updated);
    return saveTasks(tasks);
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  /// Returns: total, pending, completed, dueToday, overdue counts.
  static Future<Map<String, int>> getStats() async {
    final tasks = await loadTasks();
    final today = _dateOnly(DateTime.now());

    int pending = 0, completed = 0, dueToday = 0, overdue = 0;
    for (final t in tasks) {
      if (t.isCompleted) {
        completed++;
      } else {
        pending++;
        final due = _dateOnly(t.dueDate);
        if (due == today)        dueToday++;
        if (due.isBefore(today)) overdue++;
      }
    }
    return {
      'total':     tasks.length,
      'pending':   pending,
      'completed': completed,
      'dueToday':  dueToday,
      'overdue':   overdue,
    };
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}