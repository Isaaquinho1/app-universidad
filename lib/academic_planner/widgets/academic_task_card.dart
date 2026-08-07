import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_subtask.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';
import 'package:flutter/material.dart';

enum AcademicTaskAction { edit, toggleCompleted, delete }

class AcademicTaskCard extends StatelessWidget {
  const AcademicTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onAction,
    this.subject,
    this.category,
    this.subtasks = const [],
  });

  final AcademicTask task;
  final AcademicSubject? subject;
  final TaskCategory? category;
  final List<AcademicSubtask> subtasks;
  final VoidCallback onTap;
  final ValueChanged<AcademicTaskAction> onAction;

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Baja',
      TaskPriority.medium => 'Media',
      TaskPriority.high => 'Alta',
      TaskPriority.urgent => 'Urgente',
    };
  }

  Color _priorityColor(BuildContext context) {
    return switch (task.priority) {
      TaskPriority.low => const Color(0xFF2E7D32),
      TaskPriority.medium => const Color(0xFF1565C0),
      TaskPriority.high => const Color(0xFFEF6C00),
      TaskPriority.urgent => const Color(0xFFC62828),
    };
  }

  String _dueLabel(BuildContext context) {
    final dueAt = task.dueAt;

    if (dueAt == null) {
      return 'Sin fecha límite';
    }

    final localizations = MaterialLocalizations.of(context);

    return '${localizations.formatMediumDate(dueAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dueAt))}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final priorityColor = _priorityColor(context);
    final completed = task.status == AcademicTaskStatus.completed;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.background02,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              task.isOverdue
                  ? const Color(0xFFC62828)
                  : colors.deactive.withValues(alpha: 0.18),
          width: task.isOverdue ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: completed,
                onChanged: (_) {
                  onAction(AcademicTaskAction.toggleCompleted);
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppTextStyle.bodyBold.copyWith(
                        fontSize: 17,
                        color: completed ? colors.deactive : colors.active,
                        decoration:
                            completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.body.copyWith(
                          color: colors.deactive,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _TaskTag(
                          icon: Icons.flag_outlined,
                          label: _priorityLabel(task.priority),
                          color: priorityColor,
                        ),
                        if (category != null)
                          _TaskTag(
                            icon: Icons.category_outlined,
                            label: category!.name,
                            color: Color(category!.colorValue),
                          ),
                        if (subject != null)
                          _TaskTag(
                            icon: Icons.menu_book_outlined,
                            label: subject!.name,
                            color: Color(subject!.colorValue),
                          ),
                      ],
                    ),
                    if (subtasks.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Builder(
                        builder: (context) {
                          final completedCount =
                              subtasks
                                  .where((subtask) => subtask.isCompleted)
                                  .length;

                          final progress = completedCount / subtasks.length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.checklist_rounded,
                                    size: 17,
                                    color: colors.deactive,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$completedCount/'
                                    '${subtasks.length} subtareas',
                                    style: AppTextStyle.body.copyWith(
                                      fontSize: 12,
                                      color: colors.deactive,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(progress * 100).round()}%',
                                    style: AppTextStyle.bodyBold.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(
                          task.isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.event_outlined,
                          size: 17,
                          color:
                              task.isOverdue
                                  ? const Color(0xFFC62828)
                                  : colors.deactive,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            task.isOverdue
                                ? 'Vencida · ${_dueLabel(context)}'
                                : _dueLabel(context),
                            style: AppTextStyle.body.copyWith(
                              fontSize: 12,
                              color:
                                  task.isOverdue
                                      ? const Color(0xFFC62828)
                                      : colors.deactive,
                              fontWeight:
                                  task.isOverdue ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.reminderAt != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 17,
                            color: colors.deactive,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              task.reminderAt!.isAfter(DateTime.now())
                                  ? 'Recordatorio programado'
                                  : 'Recordatorio enviado',
                              style: AppTextStyle.body.copyWith(
                                fontSize: 12,
                                color: colors.deactive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<AcademicTaskAction>(
                tooltip: 'Opciones de tarea',
                onSelected: onAction,
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: AcademicTaskAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: AcademicTaskAction.toggleCompleted,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            completed
                                ? Icons.undo_rounded
                                : Icons.check_circle_outline_rounded,
                          ),
                          title: Text(
                            completed
                                ? 'Marcar pendiente'
                                : 'Marcar completada',
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: AcademicTaskAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Eliminar'),
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTag extends StatelessWidget {
  const _TaskTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.body.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
