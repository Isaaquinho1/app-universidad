import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/theme/theme_mode.dart';
import 'package:flutter/material.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentMode = AdaptiveTheme.of(context).mode;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              'Apariencia',
              style: AppTextStyle.h4.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Elige cómo quieres visualizar Conecta ITT.',
              style: AppTextStyle.body.copyWith(
                color: Theme.of(context).extension<AppColors>()!.deactive,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ThemeOption(
              title: 'Claro',
              description: 'Usa colores claros en toda la aplicación.',
              icon: Icons.light_mode_outlined,
              selected: currentMode == AdaptiveThemeMode.light,
              onPressed: () {
                CustomThemeMode.setAmoled(false);
                AdaptiveTheme.of(context).setLight();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _ThemeOption(
              title: 'Oscuro',
              description: 'Reduce el brillo y utiliza superficies oscuras.',
              icon: Icons.dark_mode_outlined,
              selected: currentMode == AdaptiveThemeMode.dark,
              onPressed: () {
                CustomThemeMode.setAmoled(false);
                AdaptiveTheme.of(context).setDark();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _ThemeOption(
              title: 'Según el sistema',
              description:
                  'Adapta la apariencia a la configuración del dispositivo.',
              icon: Icons.settings_suggest_outlined,
              selected: currentMode == AdaptiveThemeMode.system,
              onPressed: () {
                CustomThemeMode.setAmoled(false);
                AdaptiveTheme.of(context).setSystem();
              },
            ),
            const SizedBox(height: AppSpacing.xlg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notifications_active_outlined),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Los comunicados institucionales se entregan según tu '
                      'perfil, audiencia y permisos de notificación del '
                      'dispositivo.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Material(
      color:
          selected
              ? const Color(0xFF003B5C).withValues(alpha: 0.12)
              : colors.background02,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFF075578) : colors.background03,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFF003B5C) : colors.background03,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : colors.active,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyle.bodyBold.copyWith(
                        color: colors.active,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: AppTextStyle.captionL.copyWith(
                        color: colors.deactive,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? const Color(0xFF075578) : colors.deactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
