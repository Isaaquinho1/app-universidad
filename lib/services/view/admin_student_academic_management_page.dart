import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Administrative interface for reviewing and updating student academic
/// placement.
///
/// Authorization and data consistency are enforced again by Supabase.
class AdminStudentAcademicManagementPage extends StatefulWidget {
  const AdminStudentAcademicManagementPage({super.key});

  @override
  State<AdminStudentAcademicManagementPage> createState() =>
      _AdminStudentAcademicManagementPageState();
}

class _AdminStudentAcademicManagementPageState
    extends State<AdminStudentAcademicManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  List<AdminStudentAcademicProfile> _students = const [];
  bool _isLoading = true;
  String? _errorMessage;

  AppUserProfileRepository get _repository =>
      context.read<AppUserProfileRepository>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents({String? query}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final students = await _repository.searchStudentAcademicProfilesAsAdmin(
        query: query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'No fue posible consultar los perfiles académicos.';
      });
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    await _loadStudents(query: _searchController.text);
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
    await _loadStudents();
  }

  Future<void> _openEditor(AdminStudentAcademicProfile student) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (sheetContext) => _AcademicProfileEditor(
            student: student,
            profileRepository: _repository,
            catalogRepository: context.read<AcademicCatalogRepository>(),
          ),
    );

    if (changed != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Información académica actualizada correctamente.'),
        ),
      );

    await _loadStudents(query: _searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = context.watch<AppBloc>().state.institutionalProfile;

    if (currentProfile == null || !currentProfile.canManageStudentAcademics) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión académica de estudiantes')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xlg),
            child: Text(
              'No tienes permisos para administrar información académica.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión académica')),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Nombre, correo o número de control',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      _searchController.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _search,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Buscar estudiante'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _AcademicManagementMessage(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos cargar los estudiantes',
        description: _errorMessage!,
        actionLabel: 'Reintentar',
        onAction: () => _loadStudents(query: _searchController.text),
      );
    }

    if (_students.isEmpty) {
      return _AcademicManagementMessage(
        icon: Icons.person_search_outlined,
        title: 'Sin resultados',
        description:
            'No encontramos estudiantes que coincidan con tu búsqueda.',
        actionLabel: 'Mostrar todos',
        onAction: _clearSearch,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadStudents(query: _searchController.text),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: _students.length,
        separatorBuilder:
            (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final student = _students[index];

          return _StudentAcademicCard(
            student: student,
            onTap: student.active ? () => _openEditor(student) : null,
          );
        },
      ),
    );
  }
}

class _StudentAcademicCard extends StatelessWidget {
  const _StudentAcademicCard({required this.student, required this.onTap});

  final AdminStudentAcademicProfile student;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.10),
                child: Text(
                  _initials(student.preferredName),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.preferredName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (student.email?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 3),
                      Text(
                        student.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (student.controlNumber?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Control ${student.controlNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _AcademicBadge(
                          icon: Icons.school_outlined,
                          label: _careerLabel(student.careerId),
                        ),
                        _AcademicBadge(
                          icon: Icons.calendar_month_outlined,
                          label:
                              student.semester == null
                                  ? 'Semestre pendiente'
                                  : '${student.semester}.º semestre',
                        ),
                        if (student.groupId?.trim().isNotEmpty ?? false)
                          _AcademicBadge(
                            icon: Icons.groups_outlined,
                            label: student.groupId!,
                          ),
                        if (!student.active)
                          const _AcademicBadge(
                            icon: Icons.block_outlined,
                            label: 'Inactivo',
                          ),
                        if (!student.profileCompleted)
                          const _AcademicBadge(
                            icon: Icons.pending_actions_outlined,
                            label: 'Perfil pendiente',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                student.active
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademicProfileEditor extends StatefulWidget {
  const _AcademicProfileEditor({
    required this.student,
    required this.profileRepository,
    required this.catalogRepository,
  });

  final AdminStudentAcademicProfile student;
  final AppUserProfileRepository profileRepository;
  final AcademicCatalogRepository catalogRepository;

  @override
  State<_AcademicProfileEditor> createState() => _AcademicProfileEditorState();
}

class _AcademicProfileEditorState extends State<_AcademicProfileEditor> {
  static const _semesters = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];

  String? _careerId;
  int? _semester;
  String? _groupId;

  List<AcademicGroup> _groups = const [];

  bool _loadingGroups = false;
  bool _saving = false;
  String? _groupsError;

  @override
  void initState() {
    super.initState();

    _careerId = widget.student.careerId;
    _semester = widget.student.semester;
    _groupId = widget.student.groupId;

    if (_careerId != null && _semester != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadGroups(preserveCurrentGroup: true);
      });
    }
  }

  bool get _hasChanges =>
      _careerId != widget.student.careerId ||
      _semester != widget.student.semester ||
      _groupId != widget.student.groupId;

  bool get _formValid {
    final basicValid = _careerId != null && _semester != null;
    final groupValid = _groups.isEmpty || _groupId != null;

    return basicValid && groupValid && !_loadingGroups && _groupsError == null;
  }

  bool get _canSave => _hasChanges && _formValid && !_saving;

  Future<void> _loadGroups({bool preserveCurrentGroup = false}) async {
    final careerId = _careerId;
    final semester = _semester;

    if (careerId == null || semester == null) {
      setState(() {
        _groups = const [];
        _groupId = null;
        _groupsError = null;
      });
      return;
    }

    final previousGroup = preserveCurrentGroup ? _groupId : null;

    setState(() {
      _loadingGroups = true;
      _groups = const [];
      _groupsError = null;

      if (!preserveCurrentGroup) {
        _groupId = null;
      }
    });

    try {
      final groups = await widget.catalogRepository.fetchGroups(
        careerId: careerId,
        semester: semester,
      );

      if (!mounted) {
        return;
      }

      final canPreserve =
          previousGroup != null &&
          groups.any((group) => group.id == previousGroup);

      setState(() {
        _groups = groups;
        _groupId = canPreserve ? previousGroup : null;
        _loadingGroups = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingGroups = false;
        _groupsError = 'No fue posible consultar los grupos disponibles.';
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }

    final careerId = _careerId!;
    final semester = _semester!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Confirmar cambio académico'),
            content: Text(
              'Actualizarás la información académica de '
              '${widget.student.preferredName}.\n\n'
              'Carrera: ${_careerLabel(careerId)}\n'
              'Semestre: $semester.º\n'
              'Grupo: ${_groupLabel(_groupId)}\n\n'
              'El cambio afectará la segmentación institucional '
              'del estudiante y quedará registrado en auditoría.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirmar cambio'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.profileRepository.updateStudentAcademicProfileAsAdmin(
        uid: widget.student.id,
        careerId: careerId,
        semester: semester,
        groupId: _groupId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _saving = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No fue posible actualizar la información académica. '
              'Verifica la carrera, semestre y grupo.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xlg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información académica',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.student.preferredName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.student.controlNumber?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 3),
              Text(
                'Control ${widget.student.controlNumber}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xlg),
            DropdownButtonFormField<String>(
              initialValue: _careerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Carrera',
                border: OutlineInputBorder(),
              ),
              items: InstitutionalCareers.values
                  .map(
                    (career) => DropdownMenuItem<String>(
                      value: career.id,
                      child: Text(career.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged:
                  _saving
                      ? null
                      : (value) {
                        setState(() => _careerId = value);
                        _loadGroups();
                      },
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _semester,
              decoration: const InputDecoration(
                labelText: 'Semestre',
                border: OutlineInputBorder(),
              ),
              items: _semesters
                  .map(
                    (semester) => DropdownMenuItem<int>(
                      value: semester,
                      child: Text('$semester.º semestre'),
                    ),
                  )
                  .toList(growable: false),
              onChanged:
                  _saving
                      ? null
                      : (value) {
                        setState(() => _semester = value);
                        _loadGroups();
                      },
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loadingGroups)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_groupsError != null)
              _InlineAcademicMessage(
                message: _groupsError!,
                onRetry: _loadGroups,
              )
            else if (_careerId == null || _semester == null)
              const _InlineAcademicMessage(
                message:
                    'Selecciona una carrera y un semestre '
                    'para consultar los grupos.',
              )
            else if (_groups.isEmpty)
              const _InlineAcademicMessage(
                message:
                    'No existen grupos configurados para esta '
                    'combinación. El perfil podrá guardarse sin grupo.',
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _groupId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Grupo',
                  border: OutlineInputBorder(),
                ),
                items: _groups
                    .map(
                      (group) => DropdownMenuItem<String>(
                        value: group.id,
                        child: Text(
                          group.name.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    _saving
                        ? null
                        : (value) {
                          setState(() => _groupId = value);
                        },
              ),
            const SizedBox(height: AppSpacing.xlg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'El número de control, nombre, correo y rol no se '
                'modifican desde esta herramienta.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xlg),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child:
                    _saving
                        ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.3),
                        )
                        : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademicBadge extends StatelessWidget {
  const _AcademicBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicManagementMessage extends StatelessWidget {
  const _AcademicManagementMessage({
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
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _InlineAcademicMessage extends StatelessWidget {
  const _InlineAcademicMessage({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

String _careerLabel(String? careerId) {
  final normalized = careerId?.trim();

  if (normalized == null || normalized.isEmpty) {
    return 'Carrera pendiente';
  }

  return InstitutionalCareers.labelFor(normalized);
}

String _groupLabel(String? groupId) {
  final normalized = groupId?.trim();

  if (normalized == null || normalized.isEmpty) {
    return 'Sin grupo';
  }

  return normalized;
}

String _initials(String value) {
  final parts =
      value
          .trim()
          .split(RegExp(r'\\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .toList();

  if (parts.isEmpty) {
    return 'E';
  }

  return parts.map((part) => part[0].toUpperCase()).join();
}
