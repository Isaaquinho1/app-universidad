import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/constants/institutional_careers.dart';
import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:conecta_itt/login/login.dart';
import 'package:conecta_itt/profile/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Displays the institutional account and academic profile.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppBloc>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        bottom: false,
        child:
            appState.status.isLoggedIn
                ? _AuthenticatedProfile(appState: appState)
                : const _UnauthenticatedProfile(),
      ),
    );
  }
}

class _AuthenticatedProfile extends StatelessWidget {
  const _AuthenticatedProfile({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final profile = appState.institutionalProfile;

    final displayName = _firstNonEmpty([
      profile?.displayName,
      appState.user.name,
      'Usuario',
    ]);

    final email = _firstNonEmpty([
      profile?.email,
      appState.user.email,
      'Correo institucional no disponible',
    ]);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _ProfileHeader(
          displayName: displayName,
          email: email,
          roleLabel: _roleLabel(profile?.role.value),
          active: profile?.active ?? true,
          profileCompleted: profile?.profileCompleted ?? false,
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/profile/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar perfil'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF003B5C),
              side: const BorderSide(color: Color(0xFF003B5C)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xlg),

        if (_hasAcademicIdentity(profile)) ...[
          SettingsSection(
            title: 'Información académica',
            children: [
              SettingsItem(
                text: 'Identificación digital',
                icon: const Icon(Icons.badge_rounded),
                onPressed: () => context.go('/profile/student-id'),
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(height: 24, thickness: 0.5),
              _ProfileDataRow(
                icon: Icons.badge_outlined,
                label: 'Número de control',
                value: _displayValue(profile?.controlNumber),
              ),
              const Divider(height: 24, thickness: 0.5),
              _ProfileDataRow(
                icon: Icons.school_outlined,
                label: 'Carrera',
                value: _careerLabel(profile?.careerId),
              ),
              const Divider(height: 24, thickness: 0.5),
              _ProfileDataRow(
                icon: Icons.calendar_today_outlined,
                label: 'Semestre',
                value:
                    profile?.semester == null
                        ? 'No registrado'
                        : '${profile!.semester}.º semestre',
              ),
              const Divider(height: 24, thickness: 0.5),
              _ProfileDataRow(
                icon: Icons.groups_outlined,
                label: 'Grupo',
                value: _displayValue(profile?.groupId).toUpperCase(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xlg),
        ],

        SettingsSection(
          title: 'Preferencias',
          children: [
            SettingsItem(
              text: 'Configuración',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.go('/profile/settings'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xlg),

        SettingsSection(
          title: 'Cuenta y soporte',
          children: [
            SettingsItem(
              text: 'Acerca de Conecta ITT',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => context.go('/profile/about'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(height: 24, thickness: 0.5),
            SettingsItem(
              text: 'Cerrar sesión',
              icon: Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed:
                  () => _confirmLogout(
                    context,
                    onConfirmed:
                        () => context.read<AppBloc>().add(
                          const AppLogoutRequested(),
                        ),
                  ),
              trailing: const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.roleLabel,
    required this.active,
    required this.profileCompleted,
  });

  final String displayName;
  final String email;
  final String roleLabel;
  final bool active;
  final bool profileCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xlg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002A43), Color(0xFF003B5C), Color(0xFF075578)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            child: Text(
              _initials(displayName),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: AppTextStyle.h4.copyWith(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            email,
            textAlign: TextAlign.center,
            style: AppTextStyle.body.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusChip(icon: Icons.person_outline_rounded, label: roleLabel),
              _StatusChip(
                icon: active ? Icons.verified_outlined : Icons.block_outlined,
                label: active ? 'Cuenta activa' : 'Cuenta inactiva',
              ),
              if (!profileCompleted)
                const _StatusChip(
                  icon: Icons.info_outline_rounded,
                  label: 'Perfil incompleto',
                ),
            ],
          ),
          if (!profileCompleted) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Completa tu información académica para recibir contenido '
              'segmentado correctamente.',
              textAlign: TextAlign.center,
              style: AppTextStyle.captionL.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 0),
          ColoredBox(color: colors.primary.withValues(alpha: 0)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyle.captionL.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDataRow extends StatelessWidget {
  const _ProfileDataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: colors.background03,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: colors.active),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyle.captionL.copyWith(
                    color: colors.deactive,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTextStyle.body.copyWith(
                    color: colors.active,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnauthenticatedProfile extends StatelessWidget {
  const _UnauthenticatedProfile();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 88,
              color: Color(0xFF003B5C),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Acceso institucional',
              style: AppTextStyle.h4.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Inicia sesión para consultar tu perfil académico y recibir '
              'contenido personalizado.',
              textAlign: TextAlign.center,
              style: AppTextStyle.body.copyWith(height: 1.45),
            ),
            const SizedBox(height: AppSpacing.xlg),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).push<void>(LoginWithEmailPage.route()),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF003B5C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Iniciar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasAcademicIdentity(AppUserProfile? profile) {
  if (profile == null) {
    return false;
  }

  return profile.isStudent ||
      (profile.controlNumber?.trim().isNotEmpty ?? false) ||
      (profile.careerId?.trim().isNotEmpty ?? false) ||
      profile.semester != null ||
      (profile.groupId?.trim().isNotEmpty ?? false);
}

String _careerLabel(String? careerId) {
  final normalized = careerId?.trim();

  if (normalized == null || normalized.isEmpty) {
    return 'No registrada';
  }

  return InstitutionalCareers.labelFor(normalized);
}

String _displayValue(String? value) {
  final normalized = value?.trim();

  if (normalized == null || normalized.isEmpty) {
    return 'No registrado';
  }

  return normalized;
}

String _roleLabel(String? role) {
  return switch (role) {
    'student' => 'Estudiante',
    'teacher' => 'Docente',
    'admin' => 'Administrador',
    'superAdmin' || 'super_admin' => 'Superadministrador',
    _ => 'Usuario institucional',
  };
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'U';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();

    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }

  return 'No disponible';
}

Future<void> _confirmLogout(
  BuildContext context, {
  required VoidCallback onConfirmed,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text(
            'Tendrás que volver a ingresar tus credenciales institucionales '
            'para acceder a tu cuenta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
  );

  if (confirmed ?? false) {
    onConfirmed();
  }
}
