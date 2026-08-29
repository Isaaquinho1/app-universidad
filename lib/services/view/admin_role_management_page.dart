import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Allows a superAdmin to review institutional accounts and assign
/// non-superAdmin application roles through the trusted backend flow.
class AdminRoleManagementPage extends StatefulWidget {
  const AdminRoleManagementPage({super.key});

  @override
  State<AdminRoleManagementPage> createState() =>
      _AdminRoleManagementPageState();
}

class _AdminRoleManagementPageState extends State<AdminRoleManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  List<RoleManagementProfile> _profiles = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _updatingUserId;

  AppUserProfileRepository get _repository =>
      context.read<AppUserProfileRepository>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfiles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles({String? query}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profiles = await _repository.searchRoleManagementProfiles(
        query: query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'No fue posible cargar los usuarios institucionales.';
      });
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    await _loadProfiles(query: _searchController.text);
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    await _loadProfiles();
  }

  Future<void> _requestRoleChange(
    RoleManagementProfile profile,
    AppUserRole newRole,
  ) async {
    if (_updatingUserId != null || profile.role == newRole) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Confirmar cambio de rol'),
            content: Text(
              'Cambiarás a ${_profileName(profile)} de '
              '${_roleLabel(profile.role)} a ${_roleLabel(newRole)}.\n\n'
              'Este cambio modifica sus permisos dentro de Conecta ITT '
              'y quedará registrado en la auditoría institucional.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Cambiar rol'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _updatingUserId = profile.id;
    });

    try {
      await _repository.updateRole(uid: profile.id, role: newRole);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Rol actualizado a ${_roleLabel(newRole)}.')),
        );

      await _loadProfiles(query: _searchController.text);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No fue posible actualizar el rol. '
              'Verifica tus permisos e inténtalo nuevamente.',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _updatingUserId = null;
        });
      }
    }
  }

  Future<void> _showRoleSelector(RoleManagementProfile profile) async {
    final currentProfile = context.read<AppBloc>().state.institutionalProfile;

    final isCurrentUser = currentProfile?.uid == profile.id;
    final canChange =
        profile.canChangeRole && !isCurrentUser && _updatingUserId == null;

    if (!canChange) {
      return;
    }

    final selectedRole = await showModalBottomSheet<AppUserRole>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xlg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cambiar rol',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _profileName(profile),
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final role in const [
                    AppUserRole.student,
                    AppUserRole.teacher,
                    AppUserRole.admin,
                  ])
                    _RoleOption(
                      role: role,
                      selected: role == profile.role,
                      onTap: () => Navigator.of(sheetContext).pop(role),
                    ),
                ],
              ),
            ),
          ),
    );

    if (selectedRole == null || selectedRole == profile.role || !mounted) {
      return;
    }

    await _requestRoleChange(profile, selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppBloc>().state;
    final currentProfile = appState.institutionalProfile;

    if (currentProfile == null || !currentProfile.canManageAdmins) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de usuarios y roles')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xlg),
            child: Text(
              'No tienes permisos para administrar roles institucionales.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de usuarios y roles')),
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
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _search,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Buscar'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildContent(currentProfile)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppUserProfile currentProfile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _RoleManagementMessage(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos cargar los usuarios',
        description: _errorMessage!,
        actionLabel: 'Reintentar',
        onAction: () => _loadProfiles(query: _searchController.text),
      );
    }

    if (_profiles.isEmpty) {
      return _RoleManagementMessage(
        icon: Icons.person_search_outlined,
        title: 'Sin resultados',
        description:
            'No encontramos cuentas institucionales que coincidan '
            'con tu búsqueda.',
        actionLabel: 'Mostrar todos',
        onAction: _clearSearch,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProfiles(query: _searchController.text),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: _profiles.length,
        separatorBuilder:
            (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          final isCurrentUser = currentProfile.uid == profile.id;
          final isUpdating = _updatingUserId == profile.id;

          return _RoleManagementCard(
            profile: profile,
            isCurrentUser: isCurrentUser,
            isUpdating: isUpdating,
            onTap:
                profile.canChangeRole && !isCurrentUser && !isUpdating
                    ? () => _showRoleSelector(profile)
                    : null,
          );
        },
      ),
    );
  }
}

class _RoleManagementCard extends StatelessWidget {
  const _RoleManagementCard({
    required this.profile,
    required this.isCurrentUser,
    required this.isUpdating,
    required this.onTap,
  });

  final RoleManagementProfile profile;
  final bool isCurrentUser;
  final bool isUpdating;
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
                  _initials(_profileName(profile)),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _profileName(profile),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isCurrentUser)
                          const _RoleBadge(
                            label: 'Tú',
                            icon: Icons.person_outline_rounded,
                          ),
                      ],
                    ),
                    if (profile.email?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 3),
                      Text(
                        profile.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (profile.controlNumber?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Control ${profile.controlNumber}',
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
                        _RoleBadge(
                          label: _roleLabel(profile.role),
                          icon: _roleIcon(profile.role),
                        ),
                        if (!profile.active)
                          const _RoleBadge(
                            label: 'Inactiva',
                            icon: Icons.block_outlined,
                          ),
                        if (profile.staffApprovalPending)
                          const _RoleBadge(
                            label: 'Aprobación pendiente',
                            icon: Icons.pending_actions_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isUpdating)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (profile.role == AppUserRole.superAdmin)
                Icon(
                  Icons.lock_outline_rounded,
                  color: colorScheme.onSurfaceVariant,
                )
              else if (!isCurrentUser)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

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
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AppUserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_roleIcon(role)),
      title: Text(_roleLabel(role)),
      subtitle: Text(_roleDescription(role)),
      trailing:
          selected
              ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
              : const Icon(Icons.chevron_right_rounded),
      onTap: selected ? null : onTap,
    );
  }
}

class _RoleManagementMessage extends StatelessWidget {
  const _RoleManagementMessage({
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
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
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
                color: colorScheme.onSurfaceVariant,
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

String _profileName(RoleManagementProfile profile) {
  final displayName = profile.displayName?.trim();

  if (displayName != null && displayName.isNotEmpty) {
    return displayName;
  }

  final email = profile.email?.trim();

  if (email != null && email.isNotEmpty) {
    return email;
  }

  return 'Usuario institucional';
}

String _initials(String value) {
  final parts =
      value
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .toList();

  if (parts.isEmpty) {
    return 'U';
  }

  return parts.map((part) => part[0].toUpperCase()).join();
}

String _roleLabel(AppUserRole role) {
  return switch (role) {
    AppUserRole.student => 'Estudiante',
    AppUserRole.teacher => 'Docente',
    AppUserRole.admin => 'Administrador',
    AppUserRole.superAdmin => 'Superadministrador',
  };
}

String _roleDescription(AppUserRole role) {
  return switch (role) {
    AppUserRole.student => 'Acceso estándar para estudiantes.',
    AppUserRole.teacher => 'Cuenta destinada a personal docente.',
    AppUserRole.admin => 'Acceso a herramientas administrativas.',
    AppUserRole.superAdmin => 'Máximo nivel de administración.',
  };
}

IconData _roleIcon(AppUserRole role) {
  return switch (role) {
    AppUserRole.student => Icons.school_outlined,
    AppUserRole.teacher => Icons.co_present_outlined,
    AppUserRole.admin => Icons.admin_panel_settings_outlined,
    AppUserRole.superAdmin => Icons.security_rounded,
  };
}
