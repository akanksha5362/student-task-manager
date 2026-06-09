import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';
import 'package:student_task_manager/models/task_model.dart';
import 'package:student_task_manager/utils/constants.dart';
import 'package:student_task_manager/utils/task_service.dart';



/// Add a new task OR edit an existing one.
/// Pass [existingTask] to enter edit mode.
class AddTaskPage extends StatefulWidget {
  final Task? existingTask;

  const AddTaskPage({super.key, this.existingTask});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {

  // ── Form ───────────────────────────────────────────────────────────────────
  final _formKey            = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _completionNoteCtrl;

  // ── Task field values ──────────────────────────────────────────────────────
  String   _subject  = kSubjects.first;
  String   _priority = 'Medium';
  DateTime _dueDate  = DateTime.now().add(const Duration(days: 1));

  // ── Attachment state ───────────────────────────────────────────────────────
  // Full list of paths — mix of already-saved paths (edit mode) + new picks
  final List<String> _attachmentPaths = [];

  // Only newly-picked paths that still need to be copied to app storage
  final List<String> _pendingPaths = [];

  // ── Misc state ─────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get _isEditMode => widget.existingTask != null;

  final _imagePicker = ImagePicker();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _titleCtrl          = TextEditingController(text: t?.title ?? '');
    _descCtrl           = TextEditingController(text: t?.description ?? '');
    _completionNoteCtrl = TextEditingController(text: t?.completionNote ?? '');
    if (t != null) {
      _subject  = t.subject;
      _priority = t.priority;
      _dueDate  = t.dueDate;
      _attachmentPaths.addAll(t.attachments);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _completionNoteCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  // ── Attachment pickers ─────────────────────────────────────────────────────

  /// Bottom sheet with camera and gallery options.
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Sheet title ───────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Add Photo Attachment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Attach photos of notes, assignments, or reference images',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),

              // ── Camera option ─────────────────────────────────────────────
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                ),
                title: const Text('Take a Photo'),
                subtitle: const Text('Open camera and capture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),

              // ── Gallery — single image ────────────────────────────────────
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.photo_outlined, color: AppColors.success),
                ),
                title: const Text('Choose Photo from Gallery'),
                subtitle: const Text('Pick one image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),

              // ── Gallery — multiple images ─────────────────────────────────
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.photo_library_outlined, color: AppColors.warning),
                ),
                title: const Text('Choose Multiple Photos'),
                subtitle: const Text('Pick several images at once'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open camera and capture one photo.
  Future<void> _pickFromCamera() async {
    try {
      final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (xfile != null) _addAttachmentPath(xfile.path);
    } catch (e) {
      _showPickerError('Could not open camera. Check camera permissions.');
    }
  }

  /// Pick one image from gallery.
  Future<void> _pickFromGallery() async {
    try {
      final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (xfile != null) _addAttachmentPath(xfile.path);
    } catch (e) {
      _showPickerError('Could not open gallery. Check storage permissions.');
    }
  }

  /// Pick multiple images from gallery at once.
  Future<void> _pickMultipleFromGallery() async {
    try {
      final List<XFile> xfiles = await _imagePicker.pickMultiImage(
        imageQuality: 80,
      );
      for (final xfile in xfiles) {
        _addAttachmentPath(xfile.path);
      }
    } catch (e) {
      _showPickerError('Could not open gallery. Check storage permissions.');
    }
  }

  /// Add a path to both lists and rebuild.
  void _addAttachmentPath(String path) {
    setState(() {
      _attachmentPaths.add(path);
      _pendingPaths.add(path);
    });
  }

  /// Remove an attachment by index.
  void _removeAttachment(int index) {
    final path = _attachmentPaths[index];
    setState(() {
      _attachmentPaths.removeAt(index);
      _pendingPaths.remove(path);
    });
  }

  void _showPickerError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Save task ──────────────────────────────────────────────────────────────

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Generate task ID now so attachment folder uses the same ID
    final String taskId =
    _isEditMode ? widget.existingTask!.id : const Uuid().v4();

    // Copy newly-picked files into permanent app storage
    final List<String> savedPaths = [];
    for (final String path in _attachmentPaths) {
      if (_pendingPaths.contains(path)) {
        // New file — copy from temp location to app documents dir
        final String saved =
        await TaskService.saveAttachment(taskId, File(path));
        savedPaths.add(saved);
      } else {
        // Already in permanent storage — keep as-is
        savedPaths.add(path);
      }
    }

    bool success;

    if (_isEditMode) {
      final Task updated = widget.existingTask!.copyWith(
        title:          _titleCtrl.text.trim(),
        description:    _descCtrl.text.trim(),
        subject:        _subject,
        priority:       _priority,
        dueDate:        _dueDate,
        completionNote: _completionNoteCtrl.text.trim(),
        attachments:    savedPaths,
      );
      success = await TaskService.updateTask(updated);
    } else {
      final Task newTask = Task(
        id:          taskId,
        title:       _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        subject:     _subject,
        priority:    _priority,
        dueDate:     _dueDate,
        attachments: savedPaths,
        createdAt:   DateTime.now(),
      );
      success = await TaskService.addTask(newTask);
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true); // true = tell HomePage to refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save task. Please try again.')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Task' : 'Add New Task'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete task',
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              _sectionLabel('Task Title *'),
              _titleField(),
              const SizedBox(height: 16),

              _sectionLabel('Description  (optional)'),
              _descriptionField(),
              const SizedBox(height: 16),

              _sectionLabel('Subject *'),
              _subjectDropdown(),
              const SizedBox(height: 16),

              _sectionLabel('Priority *'),
              _prioritySelector(),
              const SizedBox(height: 16),

              _sectionLabel('Due Date *'),
              _dueDatePicker(),
              const SizedBox(height: 16),

              // Completion Note only shown in edit mode
              if (_isEditMode) ...[
                _sectionLabel('Completion Note  (optional)'),
                _completionNoteField(),
                const SizedBox(height: 16),
              ],

              _sectionLabel('Photo Attachments  (optional)'),
              _attachmentsSection(),
              const SizedBox(height: 32),

              _saveButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Form field widgets ─────────────────────────────────────────────────────

  Widget _titleField() => TextFormField(
    controller: _titleCtrl,
    maxLength: 80,
    decoration: InputDecoration(
      hintText: 'e.g. Complete Chapter 5 notes',
      prefixIcon: const Icon(Icons.task_alt_outlined),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    validator: (v) =>
    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
  );

  Widget _descriptionField() => TextFormField(
    controller: _descCtrl,
    maxLines: 3,
    maxLength: 200,
    decoration: InputDecoration(
      hintText: 'Add extra details…',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _completionNoteField() => TextFormField(
    controller: _completionNoteCtrl,
    maxLines: 2,
    maxLength: 200,
    decoration: InputDecoration(
      hintText: 'e.g. Submitted to teacher, scored 85%',
      prefixIcon: const Icon(Icons.note_outlined),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _subjectDropdown() => DropdownButtonFormField<String>(
    value: _subject,
    isExpanded: true,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.book_outlined),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    items: kSubjects
        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
        .toList(),
    onChanged: (v) => setState(() => _subject = v ?? kSubjects.first),
  );

  Widget _prioritySelector() {
    return Row(
      children: kPriorities.map((priority) {
        final bool   isSelected = priority == _priority;
        final Color  color      = priorityColor(priority);
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _priority = priority),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded,
                      color: isSelected ? Colors.white : color, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    priority,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _dueDatePicker() => GestureDetector(
    onTap: _pickDate,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          DateFormat('EEEE, dd MMM yyyy').format(_dueDate),
          style: const TextStyle(
              fontSize: 15, color: AppColors.textPrimary),
        ),
        const Spacer(),
        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ]),
    ),
  );

  // ── Attachments section ────────────────────────────────────────────────────

  Widget _attachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of picked images
        if (_attachmentPaths.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _attachmentPaths.length,
            itemBuilder: (_, i) => _attachmentGridTile(i),
          ),
          const SizedBox(height: 12),
        ],

        // Add attachment button
        OutlinedButton.icon(
          onPressed: _showAttachmentOptions,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _attachmentPaths.isEmpty ? 'Add Photo' : 'Add More Photos',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// Square thumbnail in the attachment grid with a remove ✕ button.
  Widget _attachmentGridTile(int index) {
    final String path  = _attachmentPaths[index];
    final File   file  = File(path);
    final bool   exists = file.existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Thumbnail ─────────────────────────────────────────────────────
        GestureDetector(
          onTap: exists ? () => OpenFilex.open(path) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: exists
                ? Image.file(file, fit: BoxFit.cover)
                : Container(
              color: AppColors.primary.withValues(alpha: 0.08),
              child: const Icon(Icons.broken_image_outlined,
                  color: AppColors.textSecondary),
            ),
          ),
        ),

        // ── Remove button (top-right corner) ──────────────────────────────
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeAttachment(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Save button ────────────────────────────────────────────────────────────

  Widget _saveButton() => SizedBox(
    height: 52,
    child: ElevatedButton.icon(
      onPressed: _isLoading ? null : _saveTask,
      icon: _isLoading
          ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2))
          : Icon(_isEditMode ? Icons.save_outlined : Icons.add),
      label: Text(
        _isEditMode ? 'Save Changes' : 'Add Task',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmAndDelete() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text(
            'Are you sure? This will also delete all attachments.'),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await TaskService.deleteTask(widget.existingTask!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
    ),
  );
}