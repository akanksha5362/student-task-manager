import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_task_manager/models/task_model.dart';
import 'package:student_task_manager/utils/constants.dart';
import 'package:student_task_manager/utils/task_service.dart';
import 'package:student_task_manager/widgets/task_card.dart';
import 'package:student_task_manager/pages/add_task_page.dart';
import 'package:student_task_manager/pages/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // ── State fields ──────────────────────────────────────────────────────────
  List<Task>       _allTasks    = [];
  Map<String, int> _stats       = {};
  bool             _isLoading   = true;
  String           _username    = 'Student';
  int              _filterIndex = 0; // 0=All  1=Pending  2=Done  3=Overdue

  late TabController     _tabController;
  static const _tabLabels = ['All', 'Pending', 'Done', 'Overdue'];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this)
      ..addListener(_onTabChange);
    _loadData();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChange)
      ..dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() => _filterIndex = _tabController.index);
    }
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(PrefKeys.username) ?? 'Student';
    _allTasks = await TaskService.loadTasks();
    _stats    = await TaskService.getStats();

    // Incomplete tasks first, then sort by due date ascending
    _allTasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });

    setState(() => _isLoading = false);
  }

  List<Task> get _filteredTasks {
    switch (_filterIndex) {
      case 1:  return _allTasks.where((t) => !t.isCompleted).toList();
      case 2:  return _allTasks.where((t) =>  t.isCompleted).toList();
      case 3:  return _allTasks.where((t) =>  t.isOverdue).toList();
      default: return _allTasks;
    }
  }

  // ── Task actions ──────────────────────────────────────────────────────────

  Future<void> _toggleComplete(Task task) async {
    await TaskService.toggleComplete(task.id);
    await _loadData();

    if (!mounted) return;
    final nowDone = !task.isCompleted; // toggled
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            nowDone ? '✅  "${task.title}" marked as done!' : '↩️  Marked as pending',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await TaskService.toggleComplete(task.id);
              await _loadData();
            },
          ),
        ),
      );
  }

  Future<void> _deleteTask(Task task) async {
    await TaskService.deleteTask(task.id);
    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${task.title}" deleted'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await TaskService.addTask(task);
              await _loadData();
            },
          ),
        ),
      );
  }

  Future<void> _logout() async {
    final ok = await _showConfirmDialog(
      title: 'Logout',
      body: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      isDestructive: true,
    );
    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.isLoggedIn, false);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _goToAddTask({Task? existing}) async {
    final refreshNeeded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddTaskPage(existingTask: existing)),
    );
    if (refreshNeeded == true) await _loadData();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            _buildTaskList(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Task Manager'),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Logout',
          onPressed: _logout,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
      ),
    );
  }

  // ── Floating action button ───────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _goToAddTask(),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Add Task',
          style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  // ── Stats header card ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    final total     = _stats['total']     ?? 0;
    final pending   = _stats['pending']   ?? 0;
    final completed = _stats['completed'] ?? 0;
    final dueToday  = _stats['dueToday']  ?? 0;
    final overdue   = _stats['overdue']   ?? 0;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    final subtitle = total == 0
        ? 'No tasks yet — tap + to add one!'
        : [
      '$pending pending',
      if (dueToday > 0) '$dueToday due today',
      if (overdue  > 0) '$overdue overdue',
    ].join('  •  ');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text('$greeting, $_username! 👋',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 16),

          // Stat pills
          Row(children: [
            _statPill('Total',   total,     Colors.white.withValues(alpha: 0.25)),
            const SizedBox(width: 8),
            _statPill('Pending', pending,   Colors.orange.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            _statPill('Done',    completed, Colors.green.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            _statPill('Overdue', overdue,   Colors.red.withValues(alpha: 0.4)),
          ]),

          // Progress bar
          if (total > 0) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? completed / total : 0,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${total > 0 ? ((completed / total) * 100).toStringAsFixed(0) : 0}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _statPill(String label, int count, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text('$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 10)),
        ]),
      ),
    );
  }

  // ── Task list sliver ──────────────────────────────────────────────────────
  Widget _buildTaskList() {
    final tasks = _filteredTasks;
    if (tasks.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final task = tasks[index];
          return TaskCard(
            key: ValueKey(task.id),
            task: task,
            onToggleComplete: () => _toggleComplete(task),
            onDelete: () => _deleteTask(task),
            onTap: () => _goToAddTask(existing: task),
          );
        },
        childCount: tasks.length,
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    const icons = [
      Icons.inbox_outlined,
      Icons.pending_actions_outlined,
      Icons.check_circle_outline,
      Icons.timer_off_outlined,
    ];
    const messages = [
      'No tasks yet',
      'Nothing pending 🎉',
      'No completed tasks yet',
      'No overdue tasks — great job! ✅',
    ];
    const subtitles = [
      'Tap the + button to add your first task',
      'All your tasks are either done or overdue',
      'Tap the checkbox on a task to mark it done',
      '',
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icons[_filterIndex], size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(messages[_filterIndex],
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
            if (subtitles[_filterIndex].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subtitles[_filterIndex],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400)),
            ],
            if (_filterIndex == 0) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _goToAddTask(),
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Reusable confirm dialog ───────────────────────────────────────────────
  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}