import 'package:unicons/unicons.dart';
import 'package:flutter/material.dart';
import 'package:app_ui/app_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Acerca de la aplicación")),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildContributorsSection(),
                const SizedBox(height: 24),
                _buildFeedbackButton(context),
                const SizedBox(height: 96),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppInfoRow(context),
          const SizedBox(height: 8),
          Text(
            'Conecta ITT es una plataforma institucional desarrollada '
            'para el Tecnológico Nacional de México Campus Tlalpan. '
            'Su propósito es centralizar servicios, avisos, calendario '
            'académico e información útil para la comunidad estudiantil.',
            style: AppTextStyle.body,
          ),
          const SizedBox(height: 16),
          _buildSocialIcons(context),
        ],
      ),
    );
  }

  Widget _buildAppInfoRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [Text('Acerca del proyecto', style: AppTextStyle.h4)],
    );
  }

  Widget _buildSocialIcons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          width: 90,
          child: SocialIconButton(
            icon: Icon(
              UniconsLine.github,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onClick: () {
              launchUrlString(
                'https://github.com/Isaaquinho1/app-universidad',
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 40,
          width: 90,
          child: SocialIconButton(
            icon: Icon(
              UniconsLine.telegram,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onClick: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                content: Text('Comunidad de la aplicación próximamente.'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildContributorsSection() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Equipo del proyecto', style: AppTextStyle.h4),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Esteban Isaac Méndez Vázquez',
          style: AppTextStyle.bodyBold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Responsable del desarrollo y adaptación de la aplicación móvil para el TecNM Campus Tlalpan.',
          style: AppTextStyle.body,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Jessica Vianney Sánchez Díaz',
          style: AppTextStyle.bodyBold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Colaboradora del proyecto.',
          style: AppTextStyle.body,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Jesús Ali Lucas Mendoza',
          style: AppTextStyle.bodyBold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Colaborador del proyecto.',
          style: AppTextStyle.body,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Institución', style: AppTextStyle.h4),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Tecnológico Nacional de México — Campus Tlalpan',
          style: AppTextStyle.body,
        ),
      ],
    ),
  );
}

  Widget _buildFeedbackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 40,
        width: double.infinity,
        child: ColorfulButton(
          text: 'Reportar un error',
          backgroundColor: Theme.of(
            context,
          ).extension<AppColors>()!.colorful07.withBlue(180),
          onClick: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
              content: Text('Soporte de la aplicación próximamente.'),
              ),
            );
          },
        ),
      ),
    );
  }
}
