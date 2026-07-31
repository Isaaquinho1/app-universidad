import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  static const _repositoryUrl =
      'https://github.com/Isaaquinho1/app-universidad';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de Conecta ITT')),
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
            const _AboutHeader(),
            const SizedBox(height: AppSpacing.xlg),
            const _InformationCard(
              title: 'Propósito',
              icon: Icons.school_outlined,
              children: [
                Text(
                  'Conecta ITT es una aplicación móvil institucional para el '
                  'Tecnológico Nacional de México, Campus Tlalpan. Su objetivo '
                  'es centralizar comunicados, servicios, información '
                  'académica y herramientas útiles para la comunidad.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _InformationCard(
              title: 'Equipo del proyecto',
              icon: Icons.groups_outlined,
              children: [
                _Contributor(
                  name: 'Esteban Isaac Méndez Vázquez',
                  description:
                      'Responsable del desarrollo y adaptación de la '
                      'aplicación móvil.',
                ),
                Divider(height: 28),
                _Contributor(
                  name: 'Jessica Vianney Sánchez Díaz',
                  description: 'Colaboradora del proyecto.',
                ),
                Divider(height: 28),
                _Contributor(
                  name: 'Jesús Ali Lucas Mendoza',
                  description: 'Colaborador del proyecto.',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _InformationCard(
              title: 'Institución',
              icon: Icons.account_balance_outlined,
              children: [
                Text(
                  'Tecnológico Nacional de México — Campus Tlalpan',
                  style: TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xlg),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed:
                    () => launchUrlString(
                      _repositoryUrl,
                      mode: LaunchMode.externalApplication,
                    ),
                icon: const Icon(Icons.code_rounded),
                label: const Text('Consultar repositorio del proyecto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF003B5C),
                  side: const BorderSide(color: Color(0xFF003B5C)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'El canal institucional de soporte estará '
                        'disponible próximamente.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Reportar un problema'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF003B5C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xlg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002A43), Color(0xFF003B5C), Color(0xFF075578)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/branding/conecta_itt_logo_clean.png',
            width: 74,
            height: 74,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Conecta ITT',
            style: AppTextStyle.h4.copyWith(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'TecNM Campus Tlalpan',
            style: AppTextStyle.body.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.background02,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.background03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF075578)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyle.bodyBold.copyWith(
                  fontSize: 17,
                  color: colors.active,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _Contributor extends StatelessWidget {
  const _Contributor({required this.name, required this.description});

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppTextStyle.bodyBold.copyWith(color: colors.active)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          description,
          style: AppTextStyle.body.copyWith(
            color: colors.deactive,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
