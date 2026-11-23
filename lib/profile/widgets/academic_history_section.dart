import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/institutional_profile/constants/institutional_careers.dart';
import 'package:conecta_itt/institutional_profile/models/student_academic_period_assignment.dart';
import 'package:conecta_itt/institutional_profile/repositories/student_academic_history_repository.dart';
import 'package:conecta_itt/profile/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Academic history for exactly one authenticated student.
///
/// This widget is keyed by the signed-in user's ID in the profile.
/// It does not persist academic history between sessions.
class AcademicHistorySection extends StatefulWidget {
  const AcademicHistorySection({required this.userId, super.key});

  final String userId;

  @override
  State<AcademicHistorySection> createState() => _AcademicHistorySectionState();
}

class _AcademicHistorySectionState extends State<AcademicHistorySection> {
  late Future<List<StudentAcademicPeriodAssignment>> _history;

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }

  @override
  void didUpdateWidget(covariant AcademicHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _history = _loadHistory();
    }
  }

  Future<List<StudentAcademicPeriodAssignment>> _loadHistory() {
    final client = Supabase.instance.client;

    if (client.auth.currentUser?.id != widget.userId) {
      return Future.error(StateError('La sesión institucional ha cambiado.'));
    }

    return StudentAcademicHistoryRepository(
      supabaseClient: client,
    ).fetchMyAcademicHistory();
  }

  void _retry() {
    setState(() {
      _history = _loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Never display a previous user's completed request after
    // the authenticated Supabase identity changes.
    if (Supabase.instance.client.auth.currentUser?.id != widget.userId) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).extension<AppColors>()!;

    return SettingsSection(
      title: 'Mi historial académico',
      children: [
        FutureBuilder<List<StudentAcademicPeriodAssignment>>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No fue posible consultar tu historial académico.',
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final history =
                snapshot.data ?? const <StudentAcademicPeriodAssignment>[];

            if (history.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.history_edu_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aún no hay periodos académicos registrados '
                        'en tu historial institucional.',
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (var index = 0; index < history.length; index++) ...[
                  if (index > 0) const Divider(height: 24, thickness: 0.5),
                  _AcademicPeriodRow(
                    assignment: history[index],
                    accentColor: colors.active,
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AcademicPeriodRow extends StatelessWidget {
  const _AcademicPeriodRow({
    required this.assignment,
    required this.accentColor,
  });

  final StudentAcademicPeriodAssignment assignment;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final group = assignment.groupId ?? 'Sin grupo asignado';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_outlined, size: 22, color: accentColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Periodo ${assignment.periodCode}',
                  style: AppTextStyle.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  InstitutionalCareers.labelFor(assignment.careerId),
                  style: AppTextStyle.captionL,
                ),
                const SizedBox(height: 5),
                Text(
                  '${assignment.semester}.º semestre'
                  '  ·  $group',
                  style: AppTextStyle.body.copyWith(
                    fontWeight: FontWeight.w600,
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
