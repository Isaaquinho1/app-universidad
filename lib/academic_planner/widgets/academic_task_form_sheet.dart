import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_subtask.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';
import 'package:flutter/material.dart';

class AcademicTaskFormData {
  const AcademicTaskFormData({
    required this.title,
    required this.priority,
    required this.status,
    this.description,
    this.subjectId,
    this.categoryId,
    this.dueAt,
    this.reminderAt,
    this.subtasks = const [],
  });

  final String title;
  final String? description;
  final String? subjectId;
  final String? categoryId;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final List<AcademicSubtask> subtasks;
  final TaskPriority priority;
  final AcademicTaskStatus status;
}

class AcademicTaskFormSheet extends StatefulWidget {
  const AcademicTaskFormSheet({
    super.key,
    required this.subjects,
    required this.categories,
    this.subtasks = const [],
    this.task,
  });

  final List<AcademicSubject> subjects;
  final List<TaskCategory> categories;
  final List<AcademicSubtask> subtasks;
  final AcademicTask? task;

  @override
  State<AcademicTaskFormSheet> createState() => _AcademicTaskFormSheetState();
}

class _AcademicTaskFormSheetState extends State<AcademicTaskFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String? _subjectId;
  String? _categoryId;
  DateTime? _dueAt;
  DateTime? _reminderAt;
  late List<AcademicSubtask> _subtasks;
  late TaskPriority _priority;
  late AcademicTaskStatus _status;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(text: task?.title ?? '');

    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    _subjectId = task?.subjectId;
    _categoryId = task?.categoryId;
    _dueAt = task?.dueAt;
    _reminderAt = task?.reminderAt;
    _subtasks = List<AcademicSubtask>.from(widget.subtasks);
    _priority = task?.priority ?? TaskPriority.medium;
    _status = task?.status ?? AcademicTaskStatus.pending;

    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _normalizeOptional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now.add(const Duration(days: 1));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Fecha de entrega',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final initialTime =
        _dueAt == null
            ? const TimeOfDay(hour: 23, minute: 59)
            : TimeOfDay.fromDateTime(_dueAt!);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Hora de entrega',
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _dueAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  void _clearDueDate() {
    setState(() {
      _dueAt = null;
      _reminderAt = null;
    });
  }

  String _dueDateLabel(BuildContext context) {
    final dueAt = _dueAt;

    if (dueAt == null) {
      return 'Sin fecha límite';
    }

    final localizations = MaterialLocalizations.of(context);

    return '${localizations.formatMediumDate(dueAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dueAt))}';
  }

  Future<void> _selectReminder() async {
    final dueAt = _dueAt;

    if (dueAt == null) {
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              icon: const Icon(Icons.event_busy_rounded),
              title: const Text('Primero agrega una entrega'),
              content: const Text(
                'Selecciona una fecha y hora de entrega antes '
                'de configurar el recordatorio.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
      return;
    }

    final option = await showModalBottomSheet<_ReminderOption>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomSafeArea = MediaQuery.paddingOf(sheetContext).bottom;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg + bottomSafeArea,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recordatorio',
                  style: AppTextStyle.h4.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final option in _ReminderOption.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(option.icon),
                    title: Text(option.label),
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (option == null || !mounted) {
      return;
    }

    if (option == _ReminderOption.none) {
      setState(() {
        _reminderAt = null;
      });
      return;
    }

    if (option == _ReminderOption.custom) {
      await _selectCustomReminder();
      return;
    }

    final offset = option.offset;

    if (offset == null) {
      return;
    }

    final candidate = dueAt.subtract(offset);

    if (!candidate.isAfter(DateTime.now())) {
      await _showInvalidReminder();
      return;
    }

    setState(() {
      _reminderAt = candidate;
    });
  }

  Future<void> _selectCustomReminder() async {
    final now = DateTime.now();
    final dueAt = _dueAt;

    if (dueAt == null) {
      return;
    }

    final initial = _reminderAt ?? dueAt.subtract(const Duration(hours: 1));

    final safeInitial =
        initial.isAfter(now) ? initial : now.add(const Duration(minutes: 2));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: dueAt,
      helpText: 'Fecha del recordatorio',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(safeInitial),
      helpText: 'Hora del recordatorio',
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    final candidate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (!candidate.isAfter(now) || candidate.isAfter(dueAt)) {
      await _showInvalidReminder();
      return;
    }

    setState(() {
      _reminderAt = candidate;
    });
  }

  Future<void> _showInvalidReminder() {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded),
            title: const Text('Recordatorio no válido'),
            content: const Text(
              'El recordatorio debe programarse en el futuro '
              'y no puede ser posterior a la entrega.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  String _reminderLabel(BuildContext context) {
    final reminderAt = _reminderAt;

    if (reminderAt == null) {
      return 'Sin recordatorio';
    }

    final localizations = MaterialLocalizations.of(context);

    return '${localizations.formatMediumDate(reminderAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(reminderAt))}';
  }

  void _clearReminder() {
    setState(() {
      _reminderAt = null;
    });
  }

  Future<void> _addSubtask() async {
    var draftTitle = '';

    final title = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Nueva subtarea'),
            content: TextFormField(
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Ej. Preparar diagrama',
              ),
              onChanged: (value) {
                draftTitle = value;
              },
              onFieldSubmitted: (value) {
                final normalized = value.trim();

                if (normalized.isNotEmpty) {
                  Navigator.of(dialogContext).pop(normalized);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final normalized = draftTitle.trim();

                  if (normalized.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(normalized);
                },
                child: const Text('Agregar'),
              ),
            ],
          ),
    );

    if (title == null || !mounted) {
      return;
    }

    final now = DateTime.now();

    setState(() {
      _subtasks.add(
        AcademicSubtask(
          id: 'draft-${now.microsecondsSinceEpoch}',
          taskId: widget.task?.id ?? '',
          title: title,
          isCompleted: false,
          position: _subtasks.length,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  Future<void> _editSubtask(AcademicSubtask subtask) async {
    var draftTitle = subtask.title;

    final title = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Editar subtarea'),
            content: TextFormField(
              initialValue: subtask.title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Descripción'),
              onChanged: (value) {
                draftTitle = value;
              },
              onFieldSubmitted: (value) {
                final normalized = value.trim();

                if (normalized.isNotEmpty) {
                  Navigator.of(dialogContext).pop(normalized);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final normalized = draftTitle.trim();

                  if (normalized.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(normalized);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );

    if (title == null || !mounted) {
      return;
    }

    setState(() {
      final index = _subtasks.indexWhere((item) => item.id == subtask.id);

      if (index == -1) {
        return;
      }

      _subtasks[index] = subtask.copyWith(
        title: title,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _toggleSubtask(AcademicSubtask subtask, bool value) {
    setState(() {
      final index = _subtasks.indexWhere((item) => item.id == subtask.id);

      if (index == -1) {
        return;
      }

      _subtasks[index] = subtask.copyWith(
        isCompleted: value,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _deleteSubtask(AcademicSubtask subtask) {
    setState(() {
      _subtasks.removeWhere((item) => item.id == subtask.id);

      _subtasks = [
        for (var index = 0; index < _subtasks.length; index++)
          _subtasks[index].copyWith(position: index, updatedAt: DateTime.now()),
      ];
    });
  }

  void _reorderSubtasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final item = _subtasks.removeAt(oldIndex);
      _subtasks.insert(newIndex, item);

      _subtasks = [
        for (var index = 0; index < _subtasks.length; index++)
          _subtasks[index].copyWith(position: index, updatedAt: DateTime.now()),
      ];
    });
  }

  bool _sameDateTime(DateTime? first, DateTime? second) {
    if (first == null || second == null) {
      return first == second;
    }

    return first.isAtSameMomentAs(second);
  }

  bool _sameSubtasks(
    List<AcademicSubtask> first,
    List<AcademicSubtask> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      final a = first[index];
      final b = second[index];

      if (a.id != b.id ||
          a.title != b.title ||
          a.isCompleted != b.isCompleted) {
        return false;
      }
    }

    return true;
  }

  bool get _hasChanges {
    final task = widget.task;

    if (task == null) {
      return true;
    }

    return _titleController.text.trim() != task.title ||
        _normalizeOptional(_descriptionController.text) != task.description ||
        _subjectId != task.subjectId ||
        _categoryId != task.categoryId ||
        !_sameDateTime(_dueAt, task.dueAt) ||
        !_sameDateTime(_reminderAt, task.reminderAt) ||
        _priority != task.priority ||
        _status != task.status ||
        !_sameSubtasks(_subtasks, widget.subtasks);
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      AcademicTaskFormData(
        title: _titleController.text.trim(),
        description: _normalizeOptional(_descriptionController.text),
        subjectId: _subjectId,
        categoryId: _categoryId,
        dueAt: _dueAt,
        reminderAt: _reminderAt,
        subtasks: _subtasks,
        priority: _priority,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + keyboardInset,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.deactive.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _isEditing ? 'Editar tarea' : 'Nueva tarea',
                  style: AppTextStyle.h4.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Organiza tus entregas, proyectos y actividades.',
                  style: AppTextStyle.body.copyWith(color: colors.deactive),
                ),
                const SizedBox(height: AppSpacing.xlg),
                TextFormField(
                  controller: _titleController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 120,
                  decoration: _decoration(
                    label: 'Título',
                    hint: 'Ej. Entregar reporte de investigación',
                    icon: Icons.task_alt_rounded,
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';

                    if (normalized.isEmpty) {
                      return 'Escribe el título de la tarea.';
                    }

                    if (normalized.length < 2) {
                      return 'El título es demasiado corto.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 600,
                  decoration: _decoration(
                    label: 'Descripción',
                    hint: 'Indicaciones o información adicional',
                    icon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: _subjectId,
                  decoration: _decoration(
                    label: 'Materia',
                    icon: Icons.menu_book_outlined,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin materia'),
                    ),
                    for (final subject in widget.subjects)
                      DropdownMenuItem<String?>(
                        value: subject.id,
                        child: Text(
                          subject.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _subjectId = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: _decoration(
                    label: 'Categoría',
                    icon: Icons.category_outlined,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin categoría'),
                    ),
                    for (final category in widget.categories)
                      DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _categoryId = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<TaskPriority>(
                  initialValue: _priority,
                  decoration: _decoration(
                    label: 'Prioridad',
                    icon: Icons.flag_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TaskPriority.low,
                      child: Text('Baja'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.medium,
                      child: Text('Media'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.high,
                      child: Text('Alta'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.urgent,
                      child: Text('Urgente'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _priority = value;
                    });
                  },
                ),
                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<AcademicTaskStatus>(
                    initialValue: _status,
                    decoration: _decoration(
                      label: 'Estado',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AcademicTaskStatus.pending,
                        child: Text('Pendiente'),
                      ),
                      DropdownMenuItem(
                        value: AcademicTaskStatus.inProgress,
                        child: Text('En progreso'),
                      ),
                      DropdownMenuItem(
                        value: AcademicTaskStatus.completed,
                        child: Text('Completada'),
                      ),
                      DropdownMenuItem(
                        value: AcademicTaskStatus.archived,
                        child: Text('Archivada'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _status = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Fecha de entrega', style: AppTextStyle.bodyBold),
                const SizedBox(height: AppSpacing.sm),
                Material(
                  color: colors.background02,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _selectDueDate,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.deactive.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              _dueDateLabel(context),
                              style: AppTextStyle.bodyBold,
                            ),
                          ),
                          if (_dueAt != null)
                            IconButton(
                              tooltip: 'Quitar fecha',
                              onPressed: _clearDueDate,
                              icon: const Icon(Icons.close_rounded),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text('Subtareas', style: AppTextStyle.bodyBold),
                    ),
                    TextButton.icon(
                      onPressed: _addSubtask,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_subtasks.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.background02,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.deactive.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      'Divide esta tarea en pasos pequeños.',
                      style: AppTextStyle.body.copyWith(color: colors.deactive),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _subtasks.length,
                    onReorder: _reorderSubtasks,
                    itemBuilder: (context, index) {
                      final subtask = _subtasks[index];

                      return ListTile(
                        key: ValueKey(subtask.id),
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: subtask.isCompleted,
                          onChanged: (value) {
                            _toggleSubtask(subtask, value ?? false);
                          },
                        ),
                        title: Text(
                          subtask.title,
                          style: AppTextStyle.body.copyWith(
                            decoration:
                                subtask.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                            color:
                                subtask.isCompleted
                                    ? colors.deactive
                                    : colors.active,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Editar subtarea',
                              onPressed: () => _editSubtask(subtask),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Eliminar subtarea',
                              onPressed: () => _deleteSubtask(subtask),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text('Recordatorio', style: AppTextStyle.bodyBold),
                const SizedBox(height: AppSpacing.sm),
                Material(
                  color: colors.background02,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _selectReminder,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.deactive.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_outlined),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              _reminderLabel(context),
                              style: AppTextStyle.bodyBold,
                            ),
                          ),
                          if (_reminderAt != null)
                            IconButton(
                              tooltip: 'Quitar recordatorio',
                              onPressed: _clearReminder,
                              icon: const Icon(Icons.close_rounded),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xlg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: !_isEditing || _hasChanges ? _submit : null,
                    icon: Icon(
                      _isEditing ? Icons.save_rounded : Icons.add_task_rounded,
                    ),
                    label: Text(
                      _isEditing ? 'Guardar cambios' : 'Agregar tarea',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ReminderOption {
  none(label: 'Sin recordatorio', icon: Icons.notifications_off_outlined),
  atDueTime(
    label: 'A la hora de entrega',
    icon: Icons.alarm_rounded,
    offset: Duration.zero,
  ),
  tenMinutes(
    label: '10 minutos antes',
    icon: Icons.timer_outlined,
    offset: Duration(minutes: 10),
  ),
  thirtyMinutes(
    label: '30 minutos antes',
    icon: Icons.timer_outlined,
    offset: Duration(minutes: 30),
  ),
  oneHour(
    label: '1 hora antes',
    icon: Icons.schedule_rounded,
    offset: Duration(hours: 1),
  ),
  oneDay(
    label: '1 día antes',
    icon: Icons.event_outlined,
    offset: Duration(days: 1),
  ),
  custom(label: 'Fecha y hora personalizadas', icon: Icons.tune_rounded);

  const _ReminderOption({required this.label, required this.icon, this.offset});

  final String label;
  final IconData icon;
  final Duration? offset;
}
