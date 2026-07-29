import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/theme/theme_mode.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/login/login.dart';
import 'package:conecta_itt/profile/widgets/widgets.dart';
import 'package:conecta_itt/l10n/l10n.dart';

enum ThemeOption { light, dark, system }

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).profile)),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            return const CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(child: _InitialProfileStatePage()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InitialProfileStatePage extends StatefulWidget {
  const _InitialProfileStatePage();

  @override
  State<_InitialProfileStatePage> createState() =>
      _InitialProfileStatePageState();
}

class _InitialProfileStatePageState extends State<_InitialProfileStatePage> {
  late ThemeOption _selectedTheme;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _selectedTheme = _getCurrentThemeOption();
      _initialized = true;
    }
  }

  ThemeOption _getCurrentThemeOption() {
    final mode = AdaptiveTheme.of(context).mode;
    if (mode == AdaptiveThemeMode.light) {
      return ThemeOption.light;
    } else if (mode == AdaptiveThemeMode.dark) {
      return ThemeOption.dark;
    } else {
      return ThemeOption.system;
    }
  }

  void _setTheme(ThemeOption option) {
    setState(() => _selectedTheme = option);

    switch (option) {
      case ThemeOption.light:
        CustomThemeMode.setAmoled(false);
        AdaptiveTheme.of(context).setLight();
        break;
      case ThemeOption.dark:
        CustomThemeMode.setAmoled(false);
        AdaptiveTheme.of(context).setDark();
        break;
      case ThemeOption.system:
        CustomThemeMode.setAmoled(false);
        AdaptiveTheme.of(context).setSystem();
        break;
    }
  }

  Widget _buildThemeOption(ThemeOption option, String title, dynamic icon) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isSelected = _selectedTheme == option;

    return InkWell(
      onTap: () => _setTheme(option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? colors.primary.withValues(alpha: 0.1)
                  : colors.background03,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.primary : colors.background03,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? colors.primary : colors.active,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyle.body.copyWith(
                color: isSelected ? colors.primary : colors.active,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final appState = context.watch<AppBloc>().state;
    final profile = appState.institutionalProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!appState.status.isLoggedIn) ...[
          SettingsSection(
            title: 'Acceso institucional',
            children: [
              SettingsItem(
                text: 'Iniciar sesión',
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedUserAccount,
                  color: colors.active,
                ),
                onPressed: () {
                  Navigator.of(context).push<void>(LoginWithEmailPage.route());
                },
                trailing: Icon(Icons.chevron_right, color: colors.deactive),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Usa tu correo institucional y contraseña para consultar '
                  'comunicados personalizados y completar tu perfil académico.',
                  style: AppTextStyle.captionL.copyWith(color: colors.deactive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ] else ...[
          SettingsSection(
            title: 'Cuenta institucional',
            children: [
              SettingsItem(
                text: profile?.displayName ?? appState.user.name ?? 'Usuario',
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedUserCircle,
                  color: colors.active,
                ),
                onPressed: null,
                trailing: const SizedBox.shrink(),
              ),
              const Divider(height: 24, thickness: 0.5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  appState.user.email ?? 'Correo institucional no disponible',
                  style: AppTextStyle.body.copyWith(color: colors.active),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Rol: ${profile?.role.value ?? 'cargando perfil...'}',
                  style: AppTextStyle.captionL.copyWith(color: colors.deactive),
                ),
              ),
              const Divider(height: 24, thickness: 0.5),
              SettingsItem(
                text: 'Cerrar sesión',
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedLogout03,
                  color: colors.active,
                ),
                onPressed: () {
                  context.read<AppBloc>().add(const AppLogoutRequested());
                },
                trailing: const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (profile?.canManageAnnouncements ?? false) ...[
          SettingsSection(
            title: 'Administración',
            children: [
              SettingsItem(
                text: 'Gestión de publicaciones',
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMegaphone01,
                  color: colors.active,
                ),
                onPressed: () => context.go('/profile/announcement-management'),
                trailing: Icon(Icons.chevron_right, color: colors.deactive),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        SettingsSection(
          title: "General",
          children: [
            SettingsItem(
              text: 'Sobre la aplicación',
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCoffee02,
                color: colors.active,
              ),
              onPressed: () => context.go('/profile/about'),
              trailing: Icon(Icons.chevron_right, color: colors.deactive),
            ),
            const Divider(height: 24, thickness: 0.5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'Tema de la aplicación',
                    style: AppTextStyle.titleM.copyWith(
                      color: colors.active,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeOption(
                        ThemeOption.light,
                        'Claro',
                        Icons.wb_sunny_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOption(
                        ThemeOption.dark,
                        'Oscuro',
                        Icons.nightlight_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOption(
                        ThemeOption.system,
                        'Sistema',
                        Icons.settings_suggest_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}
