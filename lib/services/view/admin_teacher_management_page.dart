import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTeacherManagementPage extends StatefulWidget {
  const AdminTeacherManagementPage({super.key});

  @override
  State<AdminTeacherManagementPage> createState() =>
      _AdminTeacherManagementPageState();
}

class _AdminTeacherManagementPageState
    extends State<AdminTeacherManagementPage> {
  final TeacherAcademicRepository _repository = TeacherAcademicRepository();

  late final AcademicCatalogRepository _catalogRepository =
      AcademicCatalogRepository(supabaseClient: Supabase.instance.client);

  final TextEditingController _assignmentSearchController =
      TextEditingController();

  int _section = 0;
  bool _includeInactiveAssignments = false;

  late Future<List<InstitutionalSubject>> _subjectsFuture;
  late Future<List<TeacherAssignment>> _assignmentsFuture;

  @override
  void initState() {
    super.initState();
    _reloadSubjects();
    _reloadAssignments();
  }

  @override
  void dispose() {
    _assignmentSearchController.dispose();
    super.dispose();
  }

  void _reloadSubjects() {
    _subjectsFuture = _repository.searchSubjectsAsAdmin(includeInactive: true);
  }

  void _reloadAssignments() {
    _assignmentsFuture = _repository.searchAssignmentsAsAdmin(
      query: _assignmentSearchController.text,
      includeInactive: _includeInactiveAssignments,
    );
  }

  Future<void> _refreshSubjects() async {
    setState(_reloadSubjects);
    await _subjectsFuture;
  }

  Future<void> _refreshAssignments() async {
    setState(_reloadAssignments);
    await _assignmentsFuture;
  }

  Future<void> _createSubject() async {
    final result = await showDialog<_SubjectFormResult>(
      context: context,
      builder: (_) => const _SubjectFormDialog(),
    );

    if (result == null) {
      return;
    }

    try {
      await _repository.createSubjectAsAdmin(
        name: result.name,
        code: result.code,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Materia institucional creada.')),
        );

      await _refreshSubjects();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _toggleSubject(InstitutionalSubject subject) async {
    try {
      await _repository.setSubjectActiveAsAdmin(
        subjectId: subject.id,
        active: !subject.active,
      );

      await _refreshSubjects();
      await _refreshAssignments();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _createAssignment() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => _AssignmentFormSheet(
            repository: _repository,
            catalogRepository: _catalogRepository,
          ),
    );

    if (created != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Asignación docente creada.')),
      );

    await _refreshAssignments();
  }

  Future<void> _toggleAssignment(TeacherAssignment assignment) async {
    try {
      await _repository.setAssignmentActiveAsAdmin(
        assignmentId: assignment.id,
        active: !assignment.active,
      );

      await _refreshAssignments();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _addSession(TeacherAssignment assignment) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => _SessionFormSheet(
            assignment: assignment,
            repository: _repository,
          ),
    );

    if (created == true) {
      await _refreshAssignments();
    }
  }

  Future<void> _deleteSession(TeacherAssignmentSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar sesión'),
          content: Text(
            '¿Deseas eliminar ${session.weekdayLabel.toLowerCase()} '
            '${session.timeLabel} del horario institucional?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteSessionAsAdmin(sessionId: session.id);

      await _refreshAssignments();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_friendlyError(error))));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    if (profile == null || !profile.canManageTeaching) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión docente')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xlg),
            child: Text(
              'No tienes permisos para administrar la estructura docente.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión docente')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _section == 0 ? _createSubject : _createAssignment,
        icon: Icon(
          _section == 0
              ? Icons.menu_book_outlined
              : Icons.person_add_alt_1_outlined,
        ),
        label: Text(_section == 0 ? 'Materia' : 'Asignación'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: ConectaSegmentedSelector<int>(
              selectedValue: _section,
              onChanged: (value) {
                setState(() {
                  _section = value;
                });
              },
              items: const [
                ConectaSegmentedItem(value: 0, label: 'Materias'),
                ConectaSegmentedItem(value: 1, label: 'Asignaciones'),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _section,
              children: [_buildSubjects(), _buildAssignments()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjects() {
    return FutureBuilder<List<InstitutionalSubject>>(
      future: _subjectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _TeacherManagementMessage(
            icon: Icons.error_outline,
            title: 'No fue posible cargar las materias',
            description: _friendlyError(snapshot.error!),
            actionLabel: 'Reintentar',
            onAction: _refreshSubjects,
          );
        }

        final subjects = snapshot.data ?? const [];

        if (subjects.isEmpty) {
          return _TeacherManagementMessage(
            icon: Icons.menu_book_outlined,
            title: 'Sin materias institucionales',
            description:
                'Crea la primera materia para empezar a generar '
                'asignaciones docentes.',
            actionLabel: 'Crear materia',
            onAction: _createSubject,
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshSubjects,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xlg + MediaQuery.paddingOf(context).bottom + 80,
            ),
            itemCount: subjects.length,
            separatorBuilder:
                (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final subject = subjects[index];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      subject.active
                          ? Icons.menu_book_rounded
                          : Icons.archive_outlined,
                    ),
                  ),
                  title: Text(
                    subject.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (subject.code?.trim().isNotEmpty ?? false)
                        subject.code!.trim(),
                      subject.active ? 'Activa' : 'Inactiva',
                    ].join(' · '),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (_) => _toggleSubject(subject),
                    itemBuilder:
                        (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              subject.active ? 'Desactivar' : 'Reactivar',
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
    );
  }

  Widget _buildAssignments() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: TextField(
            controller: _assignmentSearchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _refreshAssignments(),
            decoration: InputDecoration(
              labelText: 'Buscar asignaciones',
              hintText: 'Docente, materia o grupo',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Buscar',
                onPressed: _refreshAssignments,
                icon: const Icon(Icons.arrow_forward),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SwitchListTile.adaptive(
          value: _includeInactiveAssignments,
          title: const Text('Mostrar asignaciones inactivas'),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          onChanged: (value) {
            setState(() {
              _includeInactiveAssignments = value;
              _reloadAssignments();
            });
          },
        ),
        Expanded(
          child: FutureBuilder<List<TeacherAssignment>>(
            future: _assignmentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _TeacherManagementMessage(
                  icon: Icons.error_outline,
                  title: 'No fue posible cargar las asignaciones',
                  description: _friendlyError(snapshot.error!),
                  actionLabel: 'Reintentar',
                  onAction: _refreshAssignments,
                );
              }

              final assignments = snapshot.data ?? const [];

              if (assignments.isEmpty) {
                return _TeacherManagementMessage(
                  icon: Icons.school_outlined,
                  title: 'Sin asignaciones',
                  description:
                      'Asigna una materia institucional a un docente '
                      'y grupo para el periodo académico vigente.',
                  actionLabel: 'Crear asignación',
                  onAction: _createAssignment,
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshAssignments,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xlg + MediaQuery.paddingOf(context).bottom + 80,
                  ),
                  itemCount: assignments.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final assignment = assignments[index];

                    return _AssignmentCard(
                      assignment: assignment,
                      onToggle: () => _toggleAssignment(assignment),
                      onAddSession:
                          assignment.active
                              ? () => _addSession(assignment)
                              : null,
                      onDeleteSession: _deleteSession,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.onToggle,
    required this.onDeleteSession,
    this.onAddSession,
  });

  final TeacherAssignment assignment;
  final VoidCallback onToggle;
  final VoidCallback? onAddSession;
  final ValueChanged<TeacherAssignmentSession> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(
                    assignment.active
                        ? Icons.school_outlined
                        : Icons.archive_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.subjectDisplayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        assignment.teacherName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (_) => onToggle(),
                  itemBuilder:
                      (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            assignment.active
                                ? 'Desactivar asignación'
                                : 'Reactivar asignación',
                          ),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _AssignmentBadge(
                  icon: Icons.groups_outlined,
                  label: assignment.groupDisplayName,
                ),
                if (assignment.semester != null)
                  _AssignmentBadge(
                    icon: Icons.layers_outlined,
                    label: '${assignment.semester}.º semestre',
                  ),
                _AssignmentBadge(
                  icon: Icons.calendar_month_outlined,
                  label: assignment.academicPeriodName,
                ),
                if (!assignment.active)
                  const _AssignmentBadge(
                    icon: Icons.archive_outlined,
                    label: 'Inactiva',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  'Horario',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (onAddSession != null)
                  TextButton.icon(
                    onPressed: onAddSession,
                    icon: const Icon(Icons.add),
                    label: const Text('Sesión'),
                  ),
              ],
            ),
            if (assignment.sessions.isEmpty)
              Text(
                'Sin sesiones registradas.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...assignment.sessions.map(
                (session) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text('${session.weekdayLabel} · ${session.timeLabel}'),
                  subtitle:
                      session.locationLabel == null
                          ? null
                          : Text(session.locationLabel!),
                  trailing:
                      assignment.active
                          ? IconButton(
                            tooltip: 'Eliminar sesión',
                            onPressed: () => onDeleteSession(session),
                            icon: const Icon(Icons.delete_outline),
                          )
                          : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentBadge extends StatelessWidget {
  const _AssignmentBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectFormDialog extends StatefulWidget {
  const _SubjectFormDialog();

  @override
  State<_SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends State<_SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva materia institucional'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Escribe el nombre de la materia.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Clave o código',
                  hintText: 'Opcional',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            Navigator.of(context).pop(
              _SubjectFormResult(
                name: _nameController.text.trim(),
                code: _normalizeOptional(_codeController.text),
              ),
            );
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class _AssignmentFormSheet extends StatefulWidget {
  const _AssignmentFormSheet({
    required this.repository,
    required this.catalogRepository,
  });

  final TeacherAcademicRepository repository;
  final AcademicCatalogRepository catalogRepository;

  @override
  State<_AssignmentFormSheet> createState() => _AssignmentFormSheetState();
}

class _AssignmentFormSheetState extends State<_AssignmentFormSheet> {
  final _teacherSearchController = TextEditingController();

  bool _loading = true;
  bool _loadingGroups = false;
  bool _saving = false;

  List<TeacherProfileSummary> _teachers = const [];
  List<InstitutionalSubject> _subjects = const [];
  List<AcademicGroup> _groups = const [];

  String? _teacherId;
  String? _subjectId;
  String? _careerId;
  int? _semester;
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _teacherSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        widget.repository.searchTeachersAsAdmin(limit: 100),
        widget.repository.searchSubjectsAsAdmin(limit: 250),
      ]);

      if (!mounted) return;

      setState(() {
        _teachers = results[0] as List<TeacherProfileSummary>;
        _subjects = results[1] as List<InstitutionalSubject>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(error);
    }
  }

  Future<void> _searchTeachers() async {
    try {
      final teachers = await widget.repository.searchTeachersAsAdmin(
        query: _teacherSearchController.text,
        limit: 100,
      );

      if (!mounted) return;

      setState(() {
        _teachers = teachers;

        if (_teacherId != null &&
            !teachers.any((item) => item.id == _teacherId)) {
          _teacherId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _loadGroups() async {
    final careerId = _careerId;
    final semester = _semester;

    setState(() {
      _groupId = null;
      _groups = const [];
    });

    if (careerId == null || semester == null) {
      return;
    }

    setState(() {
      _loadingGroups = true;
    });

    try {
      final groups = await widget.catalogRepository.fetchGroups(
        careerId: careerId,
        semester: semester,
      );

      if (!mounted) return;

      setState(() {
        _groups = groups;
        _loadingGroups = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingGroups = false;
      });

      _showError(error);
    }
  }

  bool get _valid {
    return _teacherId != null &&
        _subjectId != null &&
        _careerId != null &&
        _semester != null &&
        _groupId != null &&
        !_loadingGroups &&
        !_saving;
  }

  Future<void> _save() async {
    if (!_valid) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.createAssignmentAsAdmin(
        teacherId: _teacherId!,
        subjectId: _subjectId!,
        academicGroupId: _groupId!,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_friendlyError(error))));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child:
          _loading
              ? const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nueva asignación docente',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Vincula un docente aprobado, materia y grupo '
                      'al periodo académico vigente.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xlg),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _teacherSearchController,
                            decoration: const InputDecoration(
                              labelText: 'Buscar docente',
                              hintText: 'Nombre o correo',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _searchTeachers(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.filledTonal(
                          tooltip: 'Buscar',
                          onPressed: _searchTeachers,
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: _teacherId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Docente',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final teacher in _teachers)
                          DropdownMenuItem(
                            value: teacher.id,
                            child: Text(
                              teacher.preferredName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _teacherId = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: _subjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Materia institucional',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final subject in _subjects)
                          DropdownMenuItem(
                            value: subject.id,
                            child: Text(
                              subject.displayName,
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
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: _careerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Carrera',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final career in InstitutionalCareers.values)
                          DropdownMenuItem(
                            value: career.id,
                            child: Text(
                              career.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _careerId = value;
                        });
                        _loadGroups();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<int>(
                      initialValue: _semester,
                      decoration: const InputDecoration(
                        labelText: 'Semestre',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var semester = 1; semester <= 9; semester++)
                          DropdownMenuItem(
                            value: semester,
                            child: Text('$semester.º semestre'),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _semester = value;
                        });
                        _loadGroups();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_loadingGroups)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          '${_careerId ?? '-'}-${_semester ?? '-'}',
                        ),
                        initialValue: _groupId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Grupo',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final group in _groups)
                            DropdownMenuItem(
                              value: group.id,
                              child: Text(
                                group.name.isEmpty ? group.id : group.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _groupId = value;
                          });
                        },
                      ),
                    const SizedBox(height: AppSpacing.xlg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _valid ? _save : null,
                        icon:
                            _saving
                                ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.save_outlined),
                        label: const Text('Crear asignación'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _SessionFormSheet extends StatefulWidget {
  const _SessionFormSheet({required this.assignment, required this.repository});

  final TeacherAssignment assignment;
  final TeacherAcademicRepository repository;

  @override
  State<_SessionFormSheet> createState() => _SessionFormSheetState();
}

class _SessionFormSheetState extends State<_SessionFormSheet> {
  final _buildingController = TextEditingController();
  final _roomController = TextEditingController();

  int _weekday = 1;
  TimeOfDay? _startsAt;
  TimeOfDay? _endsAt;
  bool _saving = false;

  @override
  void dispose() {
    _buildingController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _startsAt ?? const TimeOfDay(hour: 7, minute: 0),
    );

    if (value != null) {
      setState(() {
        _startsAt = value;
      });
    }
  }

  Future<void> _pickEnd() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _endsAt ?? const TimeOfDay(hour: 8, minute: 0),
    );

    if (value != null) {
      setState(() {
        _endsAt = value;
      });
    }
  }

  bool get _valid {
    final start = _startsAt;
    final end = _endsAt;

    if (start == null || end == null || _saving) {
      return false;
    }

    return start.hour * 60 + start.minute < end.hour * 60 + end.minute;
  }

  Future<void> _save() async {
    if (!_valid) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.createSessionAsAdmin(
        assignmentId: widget.assignment.id,
        weekday: _weekday,
        startsAt: _databaseTime(_startsAt!),
        endsAt: _databaseTime(_endsAt!),
        building: _buildingController.text,
        room: _roomController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agregar sesión',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${widget.assignment.subjectDisplayName} · '
              '${widget.assignment.groupDisplayName}',
            ),
            const SizedBox(height: AppSpacing.xlg),
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(
                labelText: 'Día',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Lunes')),
                DropdownMenuItem(value: 2, child: Text('Martes')),
                DropdownMenuItem(value: 3, child: Text('Miércoles')),
                DropdownMenuItem(value: 4, child: Text('Jueves')),
                DropdownMenuItem(value: 5, child: Text('Viernes')),
                DropdownMenuItem(value: 6, child: Text('Sábado')),
                DropdownMenuItem(value: 7, child: Text('Domingo')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _weekday = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _startsAt == null
                          ? 'Hora inicial'
                          : _startsAt!.format(context),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _endsAt == null ? 'Hora final' : _endsAt!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _buildingController,
              decoration: const InputDecoration(
                labelText: 'Edificio',
                hintText: 'Opcional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Aula',
                hintText: 'Opcional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xlg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _valid ? _save : null,
                icon: const Icon(Icons.add),
                label: const Text('Agregar al horario'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherManagementMessage extends StatelessWidget {
  const _TeacherManagementMessage({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _SubjectFormResult {
  const _SubjectFormResult({required this.name, this.code});

  final String name;
  final String? code;
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();

  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

String _databaseTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');

  return '$hour:$minute:00';
}

String _friendlyError(Object error) {
  final text = error.toString();

  if (text.contains('Teacher schedule conflict')) {
    return 'El docente ya tiene otra clase en ese horario.';
  }

  if (text.contains('Academic group schedule conflict')) {
    return 'El grupo ya tiene otra clase en ese horario.';
  }

  if (text.contains('duplicate key')) {
    return 'Esa asignación o materia ya existe.';
  }

  if (text.contains('teacher role')) {
    return 'El usuario seleccionado ya no tiene rol docente.';
  }

  if (text.contains('requires institutional approval')) {
    return 'El docente aún requiere aprobación institucional.';
  }

  return text;
}
