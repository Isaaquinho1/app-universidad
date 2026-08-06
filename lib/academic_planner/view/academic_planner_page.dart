import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class AcademicPlannerPage extends StatelessWidget {
  const AcademicPlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Horario')),
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.background02,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.background03),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF003B5C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 34,
                      color: Color(0xFF075578),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Gestión académica personal',
                    textAlign: TextAlign.center,
                    style: AppTextStyle.h4.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Organiza tus materias, clases, aulas, docentes y '
                    'actividades universitarias desde un solo lugar.',
                    textAlign: TextAlign.center,
                    style: AppTextStyle.body.copyWith(
                      color: colors.deactive,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _FeaturePreview(
                    icon: Icons.view_day_outlined,
                    title: 'Horario diario y semanal',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _FeaturePreview(
                    icon: Icons.location_on_outlined,
                    title: 'Edificios, salones y docentes',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _FeaturePreview(
                    icon: Icons.task_alt_rounded,
                    title: 'Tareas, categorías y recordatorios',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003B5C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Estamos preparando tu espacio académico.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF075578),
                      ),
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

class _FeaturePreview extends StatelessWidget {
  const _FeaturePreview({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.background03,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: colors.active),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title,
            style: AppTextStyle.bodyBold.copyWith(color: colors.active),
          ),
        ),
      ],
    );
  }
}
