import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subject_repository.dart';
import 'package:conecta_itt/academic_planner/view/subject_sessions_page.dart';
import 'package:conecta_itt/academic_planner/widgets/widgets.dart';
import 'package:flutter/material.dart';

class SubjectsManagementView extends StatefulWidget {
  const SubjectsManagementView({
    super.key,
    required this.selectedIndex,
    required this.onSectionSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSectionSelected;

  @override
  State<SubjectsManagementView> createState() => _SubjectsManagementViewState();
}

class _SubjectsManagementViewState extends State<SubjectsManagementView> {
  final AcademicSubjectRepository _subjectRepository =
      AcademicSubjectRepository();

  late Future<List<AcademicSubject>> _subjectsFuture;

  bool _showArchived = false;
  bool _processingAction = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  void _loadSubjects() {
    _subjectsFuture = _subjectRepository.getAll(includeArchived: _showArchived);
  }

  Future<void> _refreshSubjects() async {
    setState(_loadSubjects);
    await _subjectsFuture;
  }

  Future<void> _openSubjectForm({AcademicSubject? subject}) async {
    final result = await showModalBottomSheet<AcademicSubjectFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => AcademicSubjectFormSheet(subject: subject),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _processingAction = true;
    });

    try {
      if (subject == null) {
        await _subjectRepository.create(
          name: result.name,
          code: result.code,
          teacherName: result.teacherName,
          colorValue: result.colorValue,
          notes: result.notes,
        );
      } else {
        await _subjectRepository.update(
          AcademicSubject(
            id: subject.id,
            name: result.name,
            code: result.code,
            teacherName: result.teacherName,
            colorValue: result.colorValue,
            notes: result.notes,
            isArchived: subject.isArchived,
            createdAt: subject.createdAt,
            updatedAt: subject.updatedAt,
          ),
        );
      }

      if (!mounted) return;

      await _refreshSubjects();
    } catch (error) {
      if (!mounted) return;
      await _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _processingAction = false;
        });
      }
    }
  }

  Future<void> _handleAction(
    AcademicSubject subject,
    AcademicSubjectAction action,
  ) async {
    switch (action) {
      case AcademicSubjectAction.edit:
        await _openSubjectForm(subject: subject);

      case AcademicSubjectAction.archive:
        await _setArchived(subject, archived: true);

      case AcademicSubjectAction.restore:
        await _setArchived(subject, archived: false);

      case AcademicSubjectAction.delete:
        await _deleteSubject(subject);
    }
  }

  Future<void> _setArchived(
    AcademicSubject subject, {
    required bool archived,
  }) async {
    if (_processingAction) return;

    setState(() {
      _processingAction = true;
    });

    try {
      await _subjectRepository.setArchived(id: subject.id, archived: archived);

      if (!mounted) return;

      await _refreshSubjects();
    } catch (error) {
      if (!mounted) return;
      await _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _processingAction = false;
        });
      }
    }
  }

  Future<void> _deleteSubject(AcademicSubject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.delete_outline_rounded),
            title: const Text('Eliminar materia'),
            content: Text(
              '¿Deseas eliminar “${subject.name}” definitivamente?\n\n'
              'También se eliminarán sus sesiones de clase. '
              'Las tareas registradas se conservarán, pero dejarán '
              'de estar vinculadas a esta materia.',
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

    if (!(confirmed ?? false) || !mounted || _processingAction) {
      return;
    }

    setState(() {
      _processingAction = true;
    });

    try {
      await _subjectRepository.delete(subject.id);

      if (!mounted) return;

      await _refreshSubjects();
    } catch (error) {
      if (!mounted) return;
      await _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _processingAction = false;
        });
      }
    }
  }

  Future<void> _showError(Object error) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline_rounded),
            title: const Text('No se pudo completar la acción'),
            content: Text(
              error is ArgumentError
                  ? error.message?.toString() ??
                      'Revisa la información ingresada.'
                  : 'Ocurrió un problema con el almacenamiento local. '
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario'),
        actions: [
          IconButton(
            tooltip:
                _showArchived
                    ? 'Ocultar materias archivadas'
                    : 'Mostrar materias archivadas',
            onPressed:
                _processingAction
                    ? null
                    : () {
                      setState(() {
                        _showArchived = !_showArchived;
                        _loadSubjects();
                      });
                    },
            icon: Icon(
              _showArchived
                  ? Icons.inventory_2_rounded
                  : Icons.inventory_2_outlined,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: AcademicPlannerSectionSwitch(
            selectedIndex: widget.selectedIndex,
            onSelected: widget.onSectionSelected,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _processingAction ? null : () => _openSubjectForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Materia'),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshSubjects,
          child: FutureBuilder<List<AcademicSubject>>(
            future: _subjectsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingSubjects();
              }

              if (snapshot.hasError) {
                return _SubjectsError(onRetry: _refreshSubjects);
              }

              final subjects = snapshot.data ?? const [];

              if (subjects.isEmpty) {
                return _EmptySubjects(
                  showingArchived: _showArchived,
                  onCreate: () => _openSubjectForm(),
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  112 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: subjects.length + 1,
                separatorBuilder:
                    (_, index) =>
                        index == 0
                            ? const SizedBox(height: AppSpacing.lg)
                            : const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _SubjectsHeader(
                      total: subjects.length,
                      showingArchived: _showArchived,
                    );
                  }

                  final subject = subjects[index - 1];

                  return AcademicSubjectCard(
                    subject: subject,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SubjectSessionsPage(subject: subject),
                        ),
                      );
                    },
                    onAction: (action) {
                      _handleAction(subject, action);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SubjectsHeader extends StatelessWidget {
  const _SubjectsHeader({required this.total, required this.showingArchived});

  final int total;
  final bool showingArchived;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis materias',
          style: AppTextStyle.h4.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          showingArchived
              ? '$total materias activas y archivadas'
              : '$total materias activas',
          style: AppTextStyle.body.copyWith(color: colors.deactive),
        ),
      ],
    );
  }
}

class _EmptySubjects extends StatelessWidget {
  const _EmptySubjects({required this.showingArchived, required this.onCreate});

  final bool showingArchived;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        72,
        AppSpacing.lg,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xlg),
          decoration: BoxDecoration(
            color: colors.background02,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.deactive.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF075578).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 38,
                  color: Color(0xFF075578),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                showingArchived
                    ? 'No hay materias registradas'
                    : 'Agrega tu primera materia',
                textAlign: TextAlign.center,
                style: AppTextStyle.h4.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Registra el nombre, docente y color de cada materia. '
                'Después podrás asignarle días, horarios y aulas.',
                textAlign: TextAlign.center,
                style: AppTextStyle.body.copyWith(
                  color: colors.deactive,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.xlg),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar materia'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingSubjects extends StatelessWidget {
  const _LoadingSubjects();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _SubjectsError extends StatelessWidget {
  const _SubjectsError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xlg),
      children: [
        const SizedBox(height: 72),
        Icon(Icons.storage_rounded, size: 52, color: colors.deactive),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'No fue posible cargar tus materias',
          textAlign: TextAlign.center,
          style: AppTextStyle.h4,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Desliza hacia abajo o intenta abrir nuevamente '
          'el almacenamiento local.',
          textAlign: TextAlign.center,
          style: AppTextStyle.body.copyWith(color: colors.deactive),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }
}
