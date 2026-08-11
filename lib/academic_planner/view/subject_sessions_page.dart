import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:conecta_itt/academic_planner/repositories/class_session_repository.dart';
import 'package:conecta_itt/academic_planner/widgets/class_session_form_sheet.dart';
import 'package:conecta_itt/academic_planner/widgets/conecta_subject_hero.dart';
import 'package:flutter/material.dart';

class SubjectSessionsPage extends StatefulWidget {
  const SubjectSessionsPage({super.key, required this.subject});

  final AcademicSubject subject;

  @override
  State<SubjectSessionsPage> createState() => _SubjectSessionsPageState();
}

class _SubjectSessionsPageState extends State<SubjectSessionsPage> {
  static const _weekdayLabels = <int, String>{
    DateTime.monday: 'Lunes',
    DateTime.tuesday: 'Martes',
    DateTime.wednesday: 'Miércoles',
    DateTime.thursday: 'Jueves',
    DateTime.friday: 'Viernes',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };

  final ClassSessionRepository _repository = ClassSessionRepository();

  late Future<List<ClassSession>> _sessionsFuture;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    _sessionsFuture = _repository.getBySubject(widget.subject.id);
  }

  Future<void> _refresh() async {
    setState(_loadSessions);
    await _sessionsFuture;
  }

  Future<void> _openForm({ClassSession? session}) async {
    final result = await showModalBottomSheet<ClassSessionFormData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ClassSessionFormSheet(session: session),
    );

    if (result == null || !mounted) return;

    setState(() {
      _processing = true;
    });

    try {
      if (session == null) {
        await _repository.create(
          subjectId: widget.subject.id,
          weekday: result.weekday,
          startMinutes: result.startMinutes,
          endMinutes: result.endMinutes,
          building: result.building,
          room: result.room,
          reminderMinutes: result.reminderMinutes,
        );
      } else {
        await _repository.update(
          ClassSession(
            id: session.id,
            subjectId: session.subjectId,
            weekday: result.weekday,
            startMinutes: result.startMinutes,
            endMinutes: result.endMinutes,
            building: result.building,
            room: result.room,
            reminderMinutes: result.reminderMinutes,
            isActive: session.isActive,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
          ),
        );
      }

      if (!mounted) return;
      await _refresh();
    } on ClassScheduleConflictException {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded),
              title: const Text('Conflicto de horario'),
              content: const Text(
                'Esta sesión se traslapa con otra clase registrada. '
                'Elige un horario diferente.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
    } catch (_) {
      if (!mounted) return;
      await _showGenericError();
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _deleteSession(ClassSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.delete_outline_rounded),
            title: const Text('Eliminar sesión'),
            content: Text(
              '¿Deseas eliminar la sesión del '
              '${_weekdayLabels[session.weekday]?.toLowerCase()} '
              'de ${_formatMinutes(context, session.startMinutes)} '
              'a ${_formatMinutes(context, session.endMinutes)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (!(confirmed ?? false) || !mounted) return;

    setState(() {
      _processing = true;
    });

    try {
      await _repository.delete(session.id);

      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      await _showGenericError();
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _showGenericError() {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline_rounded),
            title: const Text('No se pudo completar la acción'),
            content: const Text(
              'Ocurrió un problema con el almacenamiento local. '
              'Intenta nuevamente.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  String _formatMinutes(BuildContext context, int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final subjectColor = Color(widget.subject.colorValue);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sesiones de clase'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'class_sessions_fab',
        onPressed: _processing ? null : () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Sesión'),
      ),
      body: ConectaAtmosphere(
        accent: subjectColor,
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<List<ClassSession>>(
            future: _sessionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _SessionsError(onRetry: _refresh);
              }

              final sessions = snapshot.data ?? const [];

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    100 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    Hero(
                      tag: 'academic-subject-${widget.subject.id}',
                      transitionOnUserGestures: true,
                      createRectTween: (begin, end) {
                        return MaterialRectArcTween(begin: begin, end: end);
                      },
                      child: ConectaSubjectHero(
                        subject: widget.subject,
                        color: subjectColor,
                        subtitle:
                            '${sessions.length} '
                            '${sessions.length == 1 ? 'sesión semanal' : 'sesiones semanales'}',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (sessions.isEmpty)
                      _EmptySessions(onCreate: () => _openForm())
                    else
                      for (var index = 0; index < sessions.length; index++) ...[
                        ConectaEntrance(
                          index: index + 2,
                          child: _SessionCard(
                            session: sessions[index],
                            color: subjectColor,
                            weekday:
                                _weekdayLabels[sessions[index].weekday] ??
                                'Día',
                            startLabel: _formatMinutes(
                              context,
                              sessions[index].startMinutes,
                            ),
                            endLabel: _formatMinutes(
                              context,
                              sessions[index].endMinutes,
                            ),
                            onEdit: () => _openForm(session: sessions[index]),
                            onDelete: () => _deleteSession(sessions[index]),
                          ),
                        ),
                        if (index < sessions.length - 1)
                          const SizedBox(height: AppSpacing.md),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.color,
    required this.weekday,
    required this.startLabel,
    required this.endLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final ClassSession session;
  final Color color;
  final String weekday;
  final String startLabel;
  final String endLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final location = [
      session.building,
      session.room,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.background02,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.deactive.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.schedule_rounded, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekday,
                    style: AppTextStyle.bodyBold.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$startLabel – $endLabel',
                    style: AppTextStyle.body.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: colors.deactive,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            location,
                            style: AppTextStyle.body.copyWith(
                              color: colors.deactive,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (session.reminderMinutes != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 17,
                          color: colors.deactive,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Aviso ${session.reminderMinutes} min antes',
                          style: AppTextStyle.body.copyWith(
                            color: colors.deactive,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones de sesión',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder:
                  (_) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Eliminar'),
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xlg),
      decoration: BoxDecoration(
        color: colors.background02,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.deactive.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_view_week_rounded, size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Agrega el horario de esta materia',
            textAlign: TextAlign.center,
            style: AppTextStyle.h4.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Puedes registrar varios días y aulas para la misma materia.',
            textAlign: TextAlign.center,
            style: AppTextStyle.body.copyWith(color: colors.deactive),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar sesión'),
          ),
        ],
      ),
    );
  }
}

class _SessionsError extends StatelessWidget {
  const _SessionsError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    );
  }
}
