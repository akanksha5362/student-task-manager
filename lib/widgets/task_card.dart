import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_task_manager/models/task_model.dart';
import 'package:student_task_manager/utils/constants.dart';

/// A single task list item with:
///  • Animated circular checkbox — tap to mark done/pending instantly
///  • Swipe right  → toggle complete
///  • Swipe left   → delete (with confirm dialog)
///  • Priority colour on left border
///  • Subject & priority chips
///  • Due date with overdue / due-today colouring
///  • Attachment thumbnail strip (up to 3 previews + overflow count)
///  • Completion timestamp shown when done
class TaskCard extends StatefulWidget {
  final Task         task;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  // Optimistic local state so checkbox feels instant
  late bool _localDone;

  late AnimationController _checkAnim;
  late Animation<double>   _checkScale;

  @override
  void initState() {
    super.initState();
    _localDone  = widget.task.isCompleted;
    _checkAnim  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _checkScale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _checkAnim, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(TaskCard old) {
    super.didUpdateWidget(old);
    _localDone = widget.task.isCompleted;
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  // ── Checkbox tap ──────────────────────────────────────────────────────────
  Future<void> _handleToggle() async {
    await _checkAnim.forward();
    _checkAnim.reverse();
    setState(() => _localDone = !_localDone);
    widget.onToggleComplete();
  }

  // ── Derived values ────────────────────────────────────────────────────────
  Color  get _pColor => priorityColor(widget.task.priority);
  Color  get _sColor => subjectColor(widget.task.subject);

  String get _statusLabel {
    if (_localDone)             return 'Done';
    if (widget.task.isOverdue)  return 'Overdue';
    if (widget.task.isDueToday) return 'Due Today';
    return '';
  }

  Color get _statusColor {
    if (_localDone)             return AppColors.success;
    if (widget.task.isOverdue)  return AppColors.danger;
    if (widget.task.isDueToday) return AppColors.warning;
    return Colors.transparent;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.task.id),
      // Swipe LEFT background  → delete
      background: _swipeBg(
        color:     AppColors.danger,
        icon:      Icons.delete_outline,
        label:     'Delete',
        alignment: Alignment.centerLeft,
      ),
      // Swipe RIGHT background → complete
      secondaryBackground: _swipeBg(
        color:     AppColors.success,
        icon:      Icons.check_circle_outline,
        label:     'Done',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          widget.onToggleComplete();
          return false; // don't remove from list, just toggle
        }
        return _confirmDelete(context); // swipe left = delete
      },
      onDismissed: (_) => widget.onDelete(),

      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _localDone ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: _pColor, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildCheckbox(),
                const SizedBox(width: 12),
                Expanded(child: _buildContent()),
                _buildDeleteButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Checkbox circle ───────────────────────────────────────────────────────
  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: _handleToggle,
      child: ScaleTransition(
        scale: _checkScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _localDone ? _pColor : Colors.transparent,
            border: Border.all(
              color: _localDone ? _pColor : Colors.grey.shade400,
              width: 2.2,
            ),
            boxShadow: _localDone
                ? [BoxShadow(
                color: _pColor.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2))]
                : [],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _localDone
                ? const Icon(Icons.check,
                color: Colors.white, size: 15, key: ValueKey('c'))
                : const SizedBox.shrink(key: ValueKey('u')),
          ),
        ),
      ),
    );
  }

  // ── Main content column ───────────────────────────────────────────────────
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + status badge
        Row(children: [
          Expanded(
            child: Text(
              widget.task.title,
              style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color: _localDone ? Colors.grey.shade400 : AppColors.textPrimary,
                decoration: _localDone
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: Colors.grey.shade400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_statusLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            _statusBadge(_statusLabel, _statusColor),
          ],
        ]),

        // Description
        if (widget.task.description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            widget.task.description,
            style: TextStyle(
              fontSize: 12,
              color: _localDone
                  ? Colors.grey.shade400
                  : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 8),

        // Subject / priority / due date row
        Row(children: [
          _chip(widget.task.subject, _sColor),
          const SizedBox(width: 6),
          _chip(widget.task.priority, _pColor, icon: Icons.flag_rounded),
          const Spacer(),
          _dueDateLabel(),
        ]),

        // Completion note
        if (_localDone && widget.task.completionNote.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.note_outlined,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.task.completionNote,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ],

        // Completed-at timestamp
        if (_localDone && widget.task.completedAt != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.check_circle_outline,
                size: 12, color: AppColors.success),
            const SizedBox(width: 4),
            Text(
              'Completed ${DateFormat('dd MMM, hh:mm a').format(widget.task.completedAt!)}',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ],

        // Attachment strip
        if (widget.task.attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          _attachmentStrip(),
        ],
      ],
    );
  }

  // ── Attachment thumbnail strip ────────────────────────────────────────────
  Widget _attachmentStrip() {
    const maxShow = 3;
    final paths   = widget.task.attachments;
    final extra   = paths.length - maxShow;

    return Row(
      children: [
        const Icon(Icons.attach_file, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        ...paths.take(maxShow).map((path) => _attachmentThumb(path)),
        if (extra > 0)
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('+$extra',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          '${paths.length} attachment${paths.length == 1 ? '' : 's'}',
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _attachmentThumb(String path) {
    final file    = File(path);
    // All attachments are images (camera / gallery) — show thumbnail directly
    return Container(
      width: 28, height: 28,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppColors.primary.withValues(alpha: 0.08),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : const Icon(Icons.image_outlined,
            size: 16, color: AppColors.primary),
      ),
    );
  }

  // ── Delete icon ───────────────────────────────────────────────────────────
  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () async {
          final ok = await _confirmDelete(context);
          if (ok == true) widget.onDelete();
        },
        child: Icon(Icons.delete_outline,
            size: 20, color: Colors.red.shade300),
      ),
    );
  }

  // ── Small reusable widgets ────────────────────────────────────────────────

  Widget _chip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _dueDateLabel() {
    final late = widget.task.isOverdue && !_localDone;
    return Row(children: [
      Icon(Icons.calendar_today_outlined,
          size: 12,
          color: late ? AppColors.danger : AppColors.textSecondary),
      const SizedBox(width: 3),
      Text(
        DateFormat('dd MMM yyyy').format(widget.task.dueDate),
        style: TextStyle(
          fontSize: 11,
          color: late ? AppColors.danger : AppColors.textSecondary,
          fontWeight: late ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ]);
  }

  Widget _swipeBg({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<bool?> _confirmDelete(BuildContext ctx) {
    return showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${widget.task.title}"?\nAttachments will also be removed.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

}