import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_subtask.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subject_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subtask_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_task_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/task_category_repository.dart';
import 'package:conecta_itt/academic_planner/services/academic_task_reminder_service.dart';
import 'package:conecta_itt/academic_planner/view/academic_task_detail_page.dart';
import 'package:conecta_itt/academic_planner/view/task_categories_page.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_task_card.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_task_form_sheet.dart';
import 'package:flutter/material.dart';

typedef AcademicTaskEditLauncher =
    Future<void> Function(
      AcademicTask task,
      List<AcademicSubject> subjects,
      List<TaskCategory> categories,
    );

class AcademicTasksView extends StatefulWidget {
  const AcademicTasksView({super.key, this.onEditLauncherReady});

  final ValueChanged<AcademicTaskEditLauncher>? onEditLauncherReady;

  @override
  State<AcademicTasksView> createState() => _AcademicTasksViewState();
}

class _AcademicTasksViewState extends State<AcademicTasksView> {
  final AcademicTaskRepository _taskRepository = AcademicTaskRepository();

  final AcademicSubtaskRepository _subtaskRepository =
      AcademicSubtaskRepository();

  final AcademicSubjectRepository _subjectRepository =
      AcademicSubjectRepository();

  final TaskCategoryRepository _categoryRepository = TaskCategoryRepository();

  final AcademicTaskReminderService _reminderService =
      AcademicTaskReminderService();

  late Future<_TaskViewData> _dataFuture;

  Timer? _reminderStatusTimer;
  bool _processing = false;
  _TaskFilter _selectedFilter = _TaskFilter.pending;

  @override
  void initState() {
    super.initState();
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.onEditLauncherReady?.call(_editTaskFromOutside);
    });
  }

  Future<void> _editTaskFromOutside(
    AcademicTask task,
    List<AcademicSubject> subjects,
    List<TaskCategory> categories,
  ) {
    return _openTaskForm(
      task: task,
      subjects: subjects,
      categories: categories,
    );
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_TaskViewData> _fetchData() async {
    final results = await Future.wait<Object>([
      _taskRepository.getAll(),
      _subjectRepository.getAll(),
      _categoryRepository.getAll(),
    ]);

    final tasks = results[0] as List<AcademicTask>;

    final subtaskEntries = await Future.wait(
      tasks.map(
        (task) async =>
            MapEntry(task.id, await _subtaskRepository.getForTask(task.id)),
      ),
    );

    _scheduleReminderStatusRefresh(tasks);

    return _TaskViewData(
      tasks: tasks,
      subjects: results[1] as List<AcademicSubject>,
      categories: results[2] as List<TaskCategory>,
      subtasksByTaskId: Map<String, List<AcademicSubtask>>.fromEntries(
        subtaskEntries,
      ),
    );
  }

  void _scheduleReminderStatusRefresh(List<AcademicTask> tasks) {
    _reminderStatusTimer?.cancel();

    final now = DateTime.now();

    final futureReminders =
        tasks
            .map((task) => task.reminderAt)
            .whereType<DateTime>()
            .where((reminderAt) => reminderAt.isAfter(now))
            .toList()
          ..sort();

    if (futureReminders.isEmpty) {
      _reminderStatusTimer = null;
      return;
    }

    final nextReminder = futureReminders.first;
    final delay = nextReminder.difference(now) + const Duration(seconds: 1);

    _reminderStatusTimer = Timer(delay, () {
      if (!mounted) {
        return;
      }

      setState(() {});

      _scheduleReminderStatusRefresh(tasks);
    });
  }

  @override
  void dispose() {
    _reminderStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(_loadData);
    await _dataFuture;
  }

  List<AcademicTask> _applyFilter(List<AcademicTask> tasks) {
    return switch (_selectedFilter) {
      _TaskFilter.pending => tasks
          .where(
            (task) =>
                task.status == AcademicTaskStatus.pending ||
                task.status == AcademicTaskStatus.inProgress,
          )
          .toList(growable: false),
      _TaskFilter.completed => tasks
          .where((task) => task.status == AcademicTaskStatus.completed)
          .toList(growable: false),
      _TaskFilter.all => tasks,
    };
  }

  Future<bool> _prepareReminderPermissions() async {
    final notificationsGranted = await _reminderService.requestPermission();

    if (!notificationsGranted) {
      return false;
    }

    await _reminderService.requestExactAlarmPermission();
    return true;
  }

  Future<void> _openTaskDetail(AcademicTask task) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => AcademicTaskDetailPage(
              taskId: task.id,
              onEdit: (task, subjects, categories) async {
                await _openTaskForm(
                  task: task,
                  subjects: subjects,
                  categories: categories,
                );
              },
            ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  Future<void> _openTaskForm({
    AcademicTask? task,
    required List<AcademicSubject> subjects,
    required List<TaskCategory> categories,
  }) async {
    final subtasks =
        task == null
            ? const <AcademicSubtask>[]
            : await _subtaskRepository.getForTask(task.id);

    if (!mounted) {
      return;
    }

    final result = await showModalBottomSheet<AcademicTaskFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder:
          (_) => AcademicTaskFormSheet(
            task: task,
            subjects: subjects,
            categories: categories,
            subtasks: subtasks,
          ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      if (task == null) {
        final created = await _taskRepository.create(
          title: result.title,
          description: result.description,
          subjectId: result.subjectId,
          categoryId: result.categoryId,
          dueAt: result.dueAt,
          priority: result.priority,
          reminderAt: result.reminderAt,
        );

        await _synchronizeSubtasks(
          taskId: created.id,
          previous: const <AcademicSubtask>[],
          updated: result.subtasks,
        );

        if (created.reminderAt != null) {
          final granted = await _prepareReminderPermissions();

          if (granted) {
            await _reminderService.synchronize(created);
          }
        }
      } else {
        final updated = await _taskRepository.update(
          AcademicTask(
            id: task.id,
            title: result.title,
            description: result.description,
            subjectId: result.subjectId,
            categoryId: result.categoryId,
            dueAt: result.dueAt,
            priority: result.priority,
            status: result.status,
            reminderAt: result.reminderAt,
            completedAt: task.completedAt,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
          ),
        );

        await _synchronizeSubtasks(
          taskId: updated.id,
          previous: subtasks,
          updated: result.subtasks,
        );

        if (updated.reminderAt != null && !updated.isCompleted) {
          final granted = await _prepareReminderPermissions();

          if (granted) {
            await _reminderService.synchronize(updated);
          }
        } else {
          await _reminderService.cancel(updated.id);
        }
      }

      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      await _showError();
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _synchronizeSubtasks({
    required String taskId,
    required List<AcademicSubtask> previous,
    required List<AcademicSubtask> updated,
  }) async {
    final previousById = {for (final subtask in previous) subtask.id: subtask};

    final retainedIds =
        updated
            .where((subtask) => !subtask.id.startsWith('draft-'))
            .map((subtask) => subtask.id)
            .toSet();

    for (final oldSubtask in previous) {
      if (!retainedIds.contains(oldSubtask.id)) {
        await _subtaskRepository.delete(oldSubtask.id);
      }
    }

    final persistedInOrder = <AcademicSubtask>[];

    for (final desired in updated) {
      if (desired.id.startsWith('draft-')) {
        var created = await _subtaskRepository.create(
          taskId: taskId,
          title: desired.title,
        );

        if (desired.isCompleted) {
          created = await _subtaskRepository.setCompleted(
            subtask: created,
            isCompleted: true,
          );
        }

        persistedInOrder.add(created);
        continue;
      }

      final original = previousById[desired.id];

      if (original == null) {
        continue;
      }

      var current = original;

      if (current.title != desired.title) {
        current = await _subtaskRepository.updateTitle(
          subtask: current,
          title: desired.title,
        );
      }

      if (current.isCompleted != desired.isCompleted) {
        current = await _subtaskRepository.setCompleted(
          subtask: current,
          isCompleted: desired.isCompleted,
        );
      }

      persistedInOrder.add(current);
    }

    if (persistedInOrder.isNotEmpty) {
      await _subtaskRepository.reorder(
        taskId: taskId,
        subtasks: persistedInOrder,
      );
    }
  }

  Future<void> _handleAction({
    required AcademicTask task,
    required AcademicTaskAction action,
    required List<AcademicSubject> subjects,
    required List<TaskCategory> categories,
  }) async {
    switch (action) {
      case AcademicTaskAction.edit:
        await _openTaskForm(
          task: task,
          subjects: subjects,
          categories: categories,
        );

      case AcademicTaskAction.toggleCompleted:
        await _toggleCompleted(task);

      case AcademicTaskAction.delete:
        await _deleteTask(task);
    }
  }

  Future<void> _toggleCompleted(AcademicTask task) async {
    if (_processing) return;

    setState(() {
      _processing = true;
    });

    try {
      final nextStatus =
          task.status == AcademicTaskStatus.completed
              ? AcademicTaskStatus.pending
              : AcademicTaskStatus.completed;

      final updated = await _taskRepository.updateStatus(
        task: task,
        status: nextStatus,
      );

      await _reminderService.synchronize(updated);

      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      await _showError();
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _deleteTask(AcademicTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.delete_outline_rounded),
            title: const Text('Eliminar tarea'),
            content: Text('¿Deseas eliminar “${task.title}” definitivamente?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (!(confirmed ?? false) || !mounted || _processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _reminderService.cancel(task.id);
      await _taskRepository.delete(task.id);

      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      await _showError();
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _showError() {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline_rounded),
            title: const Text('No se pudo completar la acción'),
            content: const Text(
              'Ocurrió un problema con el almacenamiento local. '
              'Intenta nuevamente.',
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TaskViewData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _TasksError(onRetry: _refresh);
        }

        final data = snapshot.data!;
        final tasks = _applyFilter(data.tasks);

        final subjectsById = {
          for (final subject in data.subjects) subject.id: subject,
        };

        final categoriesById = {
          for (final category in data.categories) category.id: category,
        };

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  100 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mis tareas',
                          style: AppTextStyle.h4.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Administrar categorías',
                        onPressed:
                            _processing
                                ? null
                                : () async {
                                  final changed = await Navigator.of(
                                    context,
                                  ).push<bool>(
                                    MaterialPageRoute<bool>(
                                      builder:
                                          (_) => const TaskCategoriesPage(),
                                    ),
                                  );

                                  if ((changed ?? false) && mounted) {
                                    await _refresh();
                                  }
                                },
                        icon: const Icon(Icons.category_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${data.tasks.length} '
                    '${data.tasks.length == 1 ? 'tarea registrada' : 'tareas registradas'}',
                    style: AppTextStyle.body.copyWith(
                      color: Theme.of(context).extension<AppColors>()!.deactive,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ConectaSegmentedSelector<_TaskFilter>(
                    selectedValue: _selectedFilter,
                    onChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    items: const [
                      ConectaSegmentedItem(
                        value: _TaskFilter.pending,
                        label: 'Pendientes',
                      ),
                      ConectaSegmentedItem(
                        value: _TaskFilter.completed,
                        label: 'Completadas',
                      ),
                      ConectaSegmentedItem(
                        value: _TaskFilter.all,
                        label: 'Todas',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (tasks.isEmpty)
                    _EmptyTasks(
                      filter: _selectedFilter,
                      onCreate:
                          () => _openTaskForm(
                            subjects: data.subjects,
                            categories: data.categories,
                          ),
                    )
                  else
                    for (var index = 0; index < tasks.length; index++) ...[
                      AcademicTaskCard(
                        task: tasks[index],
                        subject: subjectsById[tasks[index].subjectId],
                        category: categoriesById[tasks[index].categoryId],
                        subtasks:
                            data.subtasksByTaskId[tasks[index].id] ??
                            const <AcademicSubtask>[],
                        onTap: () {
                          _openTaskDetail(tasks[index]);
                        },
                        onAction: (action) {
                          _handleAction(
                            task: tasks[index],
                            action: action,
                            subjects: data.subjects,
                            categories: data.categories,
                          );
                        },
                      ),
                      if (index < tasks.length - 1)
                        const SizedBox(height: AppSpacing.md),
                    ],
                ],
              ),
            ),
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: FloatingActionButton.extended(
                heroTag: 'academic_tasks_fab',
                onPressed:
                    _processing
                        ? null
                        : () => _openTaskForm(
                          subjects: data.subjects,
                          categories: data.categories,
                        ),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Tarea'),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _TaskFilter { pending, completed, all }

class _TaskViewData {
  const _TaskViewData({
    required this.tasks,
    required this.subjects,
    required this.categories,
    required this.subtasksByTaskId,
  });

  final List<AcademicTask> tasks;
  final List<AcademicSubject> subjects;
  final List<TaskCategory> categories;
  final Map<String, List<AcademicSubtask>> subtasksByTaskId;
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.filter, required this.onCreate});

  final _TaskFilter filter;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final title = switch (filter) {
      _TaskFilter.pending => 'No tienes tareas pendientes',
      _TaskFilter.completed => 'Aún no completas tareas',
      _TaskFilter.all => 'Agrega tu primera tarea',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xlg),
      decoration: BoxDecoration(
        color: colors.background02,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.deactive.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const Icon(Icons.task_alt_rounded, size: 52),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyle.h4.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Registra tus entregas y trabajos universitarios '
            'para mantenerlos organizados.',
            textAlign: TextAlign.center,
            style: AppTextStyle.body.copyWith(color: colors.deactive),
          ),
          if (filter == _TaskFilter.all) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar tarea'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TasksError extends StatelessWidget {
  const _TasksError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    );
  }
}
