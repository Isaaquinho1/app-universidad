import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const _semesters = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];

  late final TextEditingController _nameController;

  String? _careerId;
  int? _semester;
  String? _groupId;

  List<AcademicGroup> _groups = const [];
  bool _loadingGroups = false;
  bool _saving = false;
  String? _groupsError;

  AppUserProfile? _initialProfile;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }

    _initialized = true;
    final profile = context.read<AppBloc>().state.institutionalProfile;
    _initialProfile = profile;

    _nameController = TextEditingController(
      text: profile?.displayName?.trim() ?? '',
    );
    _careerId = profile?.careerId;
    _semester = profile?.semester;
    _groupId = profile?.groupId;

    if (_careerId != null && _semester != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadGroups(preserveCurrentGroup: true);
      });
    }
  }

  bool get _hasChanges {
    final profile = _initialProfile;

    if (profile == null) {
      return false;
    }

    return _nameController.text.trim() != (profile.displayName?.trim() ?? '') ||
        _careerId != profile.careerId ||
        _semester != profile.semester ||
        _groupId != profile.groupId;
  }

  bool get _formValid {
    final nameValid = _nameController.text.trim().length >= 3;
    final academicValid = _careerId != null && _semester != null;
    final groupValid = _groups.isEmpty || _groupId != null;

    return nameValid &&
        academicValid &&
        groupValid &&
        !_loadingGroups &&
        _groupsError == null;
  }

  bool get _canSave =>
      _hasChanges && _formValid && !_saving && _initialProfile != null;

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
      final groups = await context
          .read<AcademicCatalogRepository>()
          .fetchGroups(careerId: careerId, semester: semester);

      if (!mounted) {
        return;
      }

      final preserved =
          previousGroup != null &&
          groups.any((group) => group.id == previousGroup);

      setState(() {
        _groups = groups;
        _groupId = preserved ? previousGroup : null;
        _loadingGroups = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingGroups = false;
        _groupsError =
            'No fue posible consultar los grupos académicos disponibles.';
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Guardar cambios'),
            content: const Text(
              'Se actualizará tu información institucional y académica.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Guardar'),
              ),
            ],
          ),
    );

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    final profile = _initialProfile!;

    setState(() => _saving = true);

    try {
      final updatedProfile = await context
          .read<AppUserProfileRepository>()
          .updateProfile(
            uid: profile.uid,
            displayName: _nameController.text.trim(),
            careerId: _careerId,
            semester: _semester,
            groupId: _groupId,
            profileCompleted: true,
          );

      if (!mounted) {
        return;
      }

      context.read<AppBloc>().add(
        AppInstitutionalProfileChanged(updatedProfile),
      );

      _initialProfile = updatedProfile;

      final messenger = ScaffoldMessenger.maybeOf(context);

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Perfil institucional actualizado correctamente.'),
        ),
      );

      context.go('/profile');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _saving = false);

      final messenger = ScaffoldMessenger.maybeOf(context);

      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible actualizar el perfil. Intenta nuevamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _initialProfile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: const Center(
          child: Text('No se encontró el perfil institucional.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              'Información personal',
              style: AppTextStyle.h4.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: _decoration(
                context,
                label: 'Nombre completo',
                hint: 'Nombre y apellidos',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              initialValue: profile.email ?? '',
              readOnly: true,
              decoration: _decoration(
                context,
                label: 'Correo institucional',
                hint: 'No disponible',
                locked: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              initialValue: profile.controlNumber ?? '',
              readOnly: true,
              decoration: _decoration(
                context,
                label: 'Número de control',
                hint: 'No disponible',
                locked: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xlg),
            Text(
              'Información académica',
              style: AppTextStyle.h4.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _careerId,
              isExpanded: true,
              dropdownColor: theme.colorScheme.surfaceContainerHigh,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: _decoration(
                context,
                label: 'Carrera',
                hint: 'Selecciona tu carrera',
              ),
              items: InstitutionalCareers.values
                  .map(
                    (career) => DropdownMenuItem<String>(
                      value: career.id,
                      child: Text(career.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() => _careerId = value);
                _loadGroups();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _semester,
              dropdownColor: theme.colorScheme.surfaceContainerHigh,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: _decoration(
                context,
                label: 'Semestre',
                hint: 'Selecciona tu semestre',
              ),
              items: _semesters
                  .map(
                    (semester) => DropdownMenuItem<int>(
                      value: semester,
                      child: Text('$semester.º semestre'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() => _semester = value);
                _loadGroups();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loadingGroups)
              const Center(child: CircularProgressIndicator())
            else if (_groupsError != null)
              _InlineMessage(message: _groupsError!, onRetry: _loadGroups)
            else if (_careerId == null || _semester == null)
              const _InfoMessage(
                message:
                    'Selecciona una carrera y un semestre para consultar los '
                    'grupos disponibles.',
              )
            else if (_groups.isEmpty)
              const _InfoMessage(
                message:
                    'No existen grupos configurados para esta combinación. '
                    'Podrás guardar el perfil sin seleccionar grupo.',
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _groupId,
                isExpanded: true,
                dropdownColor: theme.colorScheme.surfaceContainerHigh,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: _decoration(
                  context,
                  label: 'Grupo',
                  hint: 'Selecciona tu grupo',
                ),
                items: _groups
                    .map(
                      (group) => DropdownMenuItem<String>(
                        value: group.id,
                        child: Text(group.name.toUpperCase()),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _groupId = value),
              ),
            const SizedBox(height: AppSpacing.xlg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF163342) : const Color(0xFFE8F1F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'El correo institucional, número de control y rol no pueden '
                'modificarse desde la aplicación.',
              ),
            ),
            const SizedBox(height: AppSpacing.xlg),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF003B5C),
                  foregroundColor: Colors.white,
                ),
                child:
                    _saving
                        ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String label,
    required String hint,
    bool locked = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor:
          locked
              ? (isDark ? const Color(0xFF151719) : const Color(0xFFEEF0F3))
              : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF7F8FC)),
      suffixIcon:
          locked
              ? Icon(
                Icons.lock_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              )
              : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF55555A) : const Color(0xFFD4D8E3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF075578), width: 1.6),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
