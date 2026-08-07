import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
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
  });

  final String title;
  final String? description;
  final String? subjectId;
  final String? categoryId;
  final DateTime? dueAt;
  final TaskPriority priority;
  final AcademicTaskStatus status;
}

class AcademicTaskFormSheet extends StatefulWidget {
  const AcademicTaskFormSheet({
    super.key,
    required this.subjects,
    required this.categories,
    this.task,
  });

  final List<AcademicSubject> subjects;
  final List<TaskCategory> categories;
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
    _priority = task?.priority ?? TaskPriority.medium;
    _status = task?.status ?? AcademicTaskStatus.pending;
  }

  @override
  void dispose() {
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
                const SizedBox(height: AppSpacing.xlg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
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
