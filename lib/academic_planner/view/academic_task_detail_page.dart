import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_subtask.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subject_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subtask_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_task_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/task_category_repository.dart';
import 'package:flutter/material.dart';

typedef AcademicTaskDetailEditCallback =
    Future<void> Function(
      AcademicTask task,
      List<AcademicSubject> subjects,
      List<TaskCategory> categories,
    );

class AcademicTaskDetailPage extends StatefulWidget {
  const AcademicTaskDetailPage({
    super.key,
    required this.taskId,
    required this.onEdit,
  });

  final String taskId;
  final AcademicTaskDetailEditCallback onEdit;

  @override
  State<AcademicTaskDetailPage> createState() => _AcademicTaskDetailPageState();
}

class _AcademicTaskDetailPageState extends State<AcademicTaskDetailPage> {
  final AcademicTaskRepository _taskRepository = AcademicTaskRepository();

  final AcademicSubtaskRepository _subtaskRepository =
      AcademicSubtaskRepository();

  final AcademicSubjectRepository _subjectRepository =
      AcademicSubjectRepository();

  final TaskCategoryRepository _categoryRepository = TaskCategoryRepository();

  late Future<_AcademicTaskDetailData?> _dataFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _dataFuture = _fetchData();
  }

  Future<_AcademicTaskDetailData?> _fetchData() async {
    final task = await _taskRepository.getById(widget.taskId);

    if (task == null) {
      return null;
    }

    final results = await Future.wait<Object>([
      _subjectRepository.getAll(),
      _categoryRepository.getAll(),
      _subtaskRepository.getForTask(task.id),
    ]);

    final subjects = results[0] as List<AcademicSubject>;
    final categories = results[1] as List<TaskCategory>;
    final subtasks = results[2] as List<AcademicSubtask>;

    AcademicSubject? subject;
    for (final item in subjects) {
      if (item.id == task.subjectId) {
        subject = item;
        break;
      }
    }

    TaskCategory? category;
    for (final item in categories) {
      if (item.id == task.categoryId) {
        category = item;
        break;
      }
    }

    return _AcademicTaskDetailData(
      task: task,
      subject: subject,
      category: category,
      subjects: subjects,
      categories: categories,
      subtasks: subtasks,
    );
  }

  Future<void> _edit(_AcademicTaskDetailData data) async {
    await widget.onEdit(data.task, data.subjects, data.categories);

    if (!mounted) {
      return;
    }

    setState(_load);
    await _dataFuture;
  }

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Baja',
      TaskPriority.medium => 'Media',
      TaskPriority.high => 'Alta',
      TaskPriority.urgent => 'Urgente',
    };
  }

  String _statusLabel(AcademicTaskStatus status) {
    return switch (status) {
      AcademicTaskStatus.pending => 'Pendiente',
      AcademicTaskStatus.inProgress => 'En progreso',
      AcademicTaskStatus.completed => 'Completada',
      AcademicTaskStatus.archived => 'Archivada',
    };
  }

  String _dateTimeLabel(BuildContext context, DateTime dateTime) {
    final localizations = MaterialLocalizations.of(context);

    return '${localizations.formatMediumDate(dateTime)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de tarea')),
      body: FutureBuilder<_AcademicTaskDetailData?>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;

          if (data == null) {
            return const Center(child: Text('La tarea ya no está disponible.'));
          }

          return _TaskDetailContent(
            data: data,
            priorityLabel: _priorityLabel(data.task.priority),
            statusLabel: _statusLabel(data.task.status),
            dateTimeLabel: (dateTime) => _dateTimeLabel(context, dateTime),
            onEdit: () => _edit(data),
          );
        },
      ),
    );
  }
}

class _TaskDetailContent extends StatelessWidget {
  const _TaskDetailContent({
    required this.data,
    required this.priorityLabel,
    required this.statusLabel,
    required this.dateTimeLabel,
    required this.onEdit,
  });

  final _AcademicTaskDetailData data;
  final String priorityLabel;
  final String statusLabel;
  final String Function(DateTime) dateTimeLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final task = data.task;
    final subtasks = data.subtasks;

    final completedSubtasks =
        subtasks.where((subtask) => subtask.isCompleted).length;

    final progress =
        subtasks.isEmpty ? 0.0 : completedSubtasks / subtasks.length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            task.title,
            style: AppTextStyle.h3.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip(icon: Icons.flag_outlined, label: priorityLabel),
              _DetailChip(icon: Icons.task_alt_rounded, label: statusLabel),
              if (data.category != null)
                _DetailChip(
                  icon: Icons.category_outlined,
                  label: data.category!.name,
                ),
              if (data.subject != null)
                _DetailChip(
                  icon: Icons.menu_book_outlined,
                  label: data.subject!.name,
                ),
            ],
          ),
          if (task.description != null) ...[
            const SizedBox(height: AppSpacing.xlg),
            const _SectionTitle(title: 'Descripción'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              task.description!,
              style: AppTextStyle.body.copyWith(height: 1.45),
            ),
          ],
          const SizedBox(height: AppSpacing.xlg),
          const _SectionTitle(title: 'Planificación'),
          const SizedBox(height: AppSpacing.sm),
          _InformationCard(
            children: [
              _InformationRow(
                icon: Icons.event_outlined,
                title: 'Entrega',
                value:
                    task.dueAt == null
                        ? 'Sin fecha límite'
                        : dateTimeLabel(task.dueAt!),
              ),
              if (task.reminderAt != null)
                _InformationRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Recordatorio',
                  value: dateTimeLabel(task.reminderAt!),
                ),
            ],
          ),
          if (subtasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xlg),
            Row(
              children: [
                const Expanded(child: _SectionTitle(title: 'Subtareas')),
                Text(
                  '$completedSubtasks/${subtasks.length} · '
                  '${(progress * 100).round()}%',
                  style: AppTextStyle.bodyBold,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 7),
            ),
            const SizedBox(height: AppSpacing.md),
            _InformationCard(
              children: [
                for (final subtask in subtasks)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        subtask.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 21,
                        color:
                            subtask.isCompleted
                                ? colors.active
                                : colors.deactive,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          subtask.title,
                          style: AppTextStyle.body.copyWith(
                            color:
                                subtask.isCompleted
                                    ? colors.deactive
                                    : colors.active,
                            decoration:
                                subtask.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xlg),
          const _SectionTitle(title: 'Información'),
          const SizedBox(height: AppSpacing.sm),
          _InformationCard(
            children: [
              _InformationRow(
                icon: Icons.add_circle_outline_rounded,
                title: 'Creada',
                value: dateTimeLabel(task.createdAt),
              ),
              _InformationRow(
                icon: Icons.update_rounded,
                title: 'Última modificación',
                value: dateTimeLabel(task.updatedAt),
              ),
              if (task.completedAt != null)
                _InformationRow(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Completada',
                  value: dateTimeLabel(task.completedAt!),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xlg),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar tarea'),
          ),
          const SizedBox(height: AppSpacing.xlg),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyle.h4.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.deactive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.deactive),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyle.bodyBold.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.background02,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.deactive.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.deactive),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyle.bodyBold.copyWith(
                  fontSize: 12,
                  color: colors.deactive,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyle.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _AcademicTaskDetailData {
  const _AcademicTaskDetailData({
    required this.task,
    required this.subjects,
    required this.categories,
    required this.subtasks,
    this.subject,
    this.category,
  });

  final AcademicTask task;
  final AcademicSubject? subject;
  final TaskCategory? category;
  final List<AcademicSubject> subjects;
  final List<TaskCategory> categories;
  final List<AcademicSubtask> subtasks;
}
