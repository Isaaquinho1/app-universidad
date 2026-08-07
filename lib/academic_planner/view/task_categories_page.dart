import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:conecta_itt/academic_planner/repositories/task_category_repository.dart';
import 'package:conecta_itt/academic_planner/widgets/task_category_form_sheet.dart';
import 'package:flutter/material.dart';

class TaskCategoriesPage extends StatefulWidget {
  const TaskCategoriesPage({super.key});

  @override
  State<TaskCategoriesPage> createState() => _TaskCategoriesPageState();
}

class _TaskCategoriesPageState extends State<TaskCategoriesPage> {
  final TaskCategoryRepository _repository = TaskCategoryRepository();

  late Future<List<TaskCategory>> _categoriesFuture;
  bool _processing = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    _categoriesFuture = _repository.getAll();
  }

  Future<void> _refresh() async {
    setState(_loadCategories);
    await _categoriesFuture;
  }

  Future<void> _openForm({TaskCategory? category}) async {
    if (category?.isSystem ?? false) {
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              icon: const Icon(Icons.lock_outline_rounded),
              title: const Text('Categoría predeterminada'),
              content: const Text(
                'Las categorías incluidas por Conecta ITT '
                'no pueden modificarse ni eliminarse.',
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

    final result = await showModalBottomSheet<TaskCategoryFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => TaskCategoryFormSheet(category: category),
    );

    if (result == null || !mounted) return;

    setState(() {
      _processing = true;
    });

    try {
      if (category == null) {
        await _repository.create(
          name: result.name,
          colorValue: result.colorValue,
        );
      } else {
        await _repository.update(
          category: category,
          name: result.name,
          colorValue: result.colorValue,
        );
      }

      _changed = true;

      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      await _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _deleteCategory(TaskCategory category) async {
    if (category.isSystem || _processing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.delete_outline_rounded),
            title: const Text('Eliminar categoría'),
            content: Text(
              '¿Deseas eliminar “${category.name}”?\n\n'
              'Las tareas asociadas se conservarán, '
              'pero quedarán sin categoría.',
            ),
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

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _repository.delete(category.id);
      _changed = true;

      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      await _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _showError(Object error) {
    final message = switch (error) {
      StateError() => error.message,
      ArgumentError() =>
        error.message?.toString() ?? 'Revisa la información ingresada.',
      _ =>
        'No se pudo completar la acción. '
            'Es posible que ya exista una categoría '
            'con ese nombre.',
    };

    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline_rounded),
            title: const Text('No se pudo guardar'),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  Future<bool> _handlePop() async {
    Navigator.of(context).pop(_changed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handlePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorías'),
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).pop(_changed),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'task_categories_fab',
          onPressed: _processing ? null : () => _openForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Categoría'),
        ),
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<List<TaskCategory>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                );
              }

              final categories = snapshot.data ?? const <TaskCategory>[];

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    100 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: categories.length + 1,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Categorías de tareas',
                            style: AppTextStyle.h4.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Las predeterminadas están protegidas. '
                            'Puedes crear y personalizar las tuyas.',
                            style: AppTextStyle.body.copyWith(
                              color: colors.deactive,
                            ),
                          ),
                        ],
                      );
                    }

                    final category = categories[index - 1];
                    final color = Color(category.colorValue);

                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: colors.background02,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: colors.deactive.withValues(alpha: 0.18),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        onTap: () => _openForm(category: category),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            category.isSystem
                                ? Icons.lock_outline_rounded
                                : Icons.category_outlined,
                            color: color,
                          ),
                        ),
                        title: Text(
                          category.name,
                          style: AppTextStyle.bodyBold,
                        ),
                        subtitle: Text(
                          category.isSystem
                              ? 'Predeterminada'
                              : 'Personalizada',
                          style: AppTextStyle.body.copyWith(
                            color: colors.deactive,
                          ),
                        ),
                        trailing:
                            category.isSystem
                                ? const Icon(Icons.lock_rounded, size: 19)
                                : PopupMenuButton<String>(
                                  tooltip: 'Opciones de categoría',
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openForm(category: category);
                                    } else if (value == 'delete') {
                                      _deleteCategory(category);
                                    }
                                  },
                                  itemBuilder:
                                      (context) => const [
                                        PopupMenuItem<String>(
                                          value: 'edit',
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(Icons.edit_outlined),
                                            title: Text('Editar'),
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.delete_outline_rounded,
                                            ),
                                            title: Text('Eliminar'),
                                          ),
                                        ),
                                      ],
                                ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
