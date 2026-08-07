import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subject_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_task_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/task_category_repository.dart';
import 'package:conecta_itt/academic_planner/view/task_categories_page.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_task_card.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_task_form_sheet.dart';
import 'package:flutter/material.dart';

class AcademicTasksView extends StatefulWidget {
  const AcademicTasksView({super.key});

  @override
  State<AcademicTasksView> createState() => _AcademicTasksViewState();
}

class _AcademicTasksViewState extends State<AcademicTasksView> {
  final AcademicTaskRepository _taskRepository = AcademicTaskRepository();

  final AcademicSubjectRepository _subjectRepository =
      AcademicSubjectRepository();

  final TaskCategoryRepository _categoryRepository = TaskCategoryRepository();

  late Future<_TaskViewData> _dataFuture;

  bool _processing = false;
  _TaskFilter _selectedFilter = _TaskFilter.pending;

  @override
  void initState() {
    super.initState();
    _loadData();
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

    return _TaskViewData(
      tasks: results[0] as List<AcademicTask>,
      subjects: results[1] as List<AcademicSubject>,
      categories: results[2] as List<TaskCategory>,
    );
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

  Future<void> _openTaskForm({
    AcademicTask? task,
    required List<AcademicSubject> subjects,
    required List<TaskCategory> categories,
  }) async {
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
        await _taskRepository.create(
          title: result.title,
          description: result.description,
          subjectId: result.subjectId,
          categoryId: result.categoryId,
          dueAt: result.dueAt,
          priority: result.priority,
        );
      } else {
        await _taskRepository.update(
          AcademicTask(
            id: task.id,
            title: result.title,
            description: result.description,
            subjectId: result.subjectId,
            categoryId: result.categoryId,
            dueAt: result.dueAt,
            priority: result.priority,
            status: result.status,
            reminderAt: task.reminderAt,
            completedAt: task.completedAt,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
          ),
        );
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

      await _taskRepository.updateStatus(task: task, status: nextStatus);

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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_TaskFilter>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _TaskFilter.pending,
                          label: Text('Pendientes'),
                        ),
                        ButtonSegment(
                          value: _TaskFilter.completed,
                          label: Text('Completadas'),
                        ),
                        ButtonSegment(
                          value: _TaskFilter.all,
                          label: Text('Todas'),
                        ),
                      ],
                      selected: {_selectedFilter},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _selectedFilter = selection.first;
                        });
                      },
                    ),
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
  });

  final List<AcademicTask> tasks;
  final List<AcademicSubject> subjects;
  final List<TaskCategory> categories;
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
