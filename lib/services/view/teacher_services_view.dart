import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter/material.dart';

class TeacherServicesView extends StatefulWidget {
  const TeacherServicesView({super.key});

  @override
  State<TeacherServicesView> createState() => _TeacherServicesViewState();
}

class _TeacherServicesViewState extends State<TeacherServicesView> {
  final TeacherAcademicRepository _repository = TeacherAcademicRepository();

  late Future<List<TeacherAssignment>> _assignmentsFuture;

  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  void _loadAssignments() {
    _assignmentsFuture = _repository.getMyAssignments();
  }

  Future<void> _refresh() async {
    setState(_loadAssignments);
    await _assignmentsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TeacherAssignment>>(
      future: _assignmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _TeacherStateMessage(
            icon: Icons.error_outline,
            title: 'No fue posible cargar Docencia',
            description:
                'No se pudieron consultar tus asignaciones institucionales.',
            actionLabel: 'Reintentar',
            onAction: _refresh,
          );
        }

        final assignments = snapshot.data ?? const [];

        if (assignments.isEmpty) {
          return _TeacherStateMessage(
            icon: Icons.school_outlined,
            title: 'Sin asignaciones docentes',
            description:
                'No tienes materias o grupos asignados para el '
                'periodo académico vigente.',
            actionLabel: 'Actualizar',
            onAction: _refresh,
          );
        }

        return Column(
          children: [
            _TeacherHeader(assignments: assignments),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: ConectaSegmentedSelector<int>(
                selectedValue: _selectedSection,
                onChanged: (value) {
                  setState(() {
                    _selectedSection = value;
                  });
                },
                items: const [
                  ConectaSegmentedItem(value: 0, label: 'Materias'),
                  ConectaSegmentedItem(value: 1, label: 'Grupos'),
                  ConectaSegmentedItem(value: 2, label: 'Horario'),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedSection,
                children: [
                  _TeacherSubjectsView(
                    assignments: assignments,
                    onRefresh: _refresh,
                  ),
                  _TeacherGroupsView(
                    assignments: assignments,
                    onRefresh: _refresh,
                  ),
                  _TeacherScheduleView(
                    assignments: assignments,
                    onRefresh: _refresh,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({required this.assignments});

  final List<TeacherAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final first = assignments.first;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.school_outlined, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    first.teacherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    first.academicPeriodName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
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

class _TeacherSubjectsView extends StatelessWidget {
  const _TeacherSubjectsView({
    required this.assignments,
    required this.onRefresh,
  });

  final List<TeacherAssignment> assignments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: assignments.length,
        separatorBuilder:
            (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final assignment = assignments[index];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Text(
                      assignment.subjectCode?.trim().isNotEmpty ?? false
                          ? assignment.subjectCode!.trim().substring(0, 1)
                          : assignment.subjectName.trim().substring(0, 1),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.subjectName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (assignment.subjectCode?.trim().isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 3),
                          Text(assignment.subjectCode!.trim()),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _TeacherBadge(
                              icon: Icons.groups_outlined,
                              label: assignment.groupDisplayName,
                            ),
                            if (assignment.semester != null)
                              _TeacherBadge(
                                icon: Icons.layers_outlined,
                                label: '${assignment.semester}.º semestre',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TeacherGroupsView extends StatelessWidget {
  const _TeacherGroupsView({
    required this.assignments,
    required this.onRefresh,
  });

  final List<TeacherAssignment> assignments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TeacherAssignment>>{};

    for (final assignment in assignments) {
      groups
          .putIfAbsent(assignment.academicGroupId, () => <TeacherAssignment>[])
          .add(assignment);
    }

    final entries =
        groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: entries.length,
        separatorBuilder:
            (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final groupAssignments = entry.value;
          final first = groupAssignments.first;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.groups_outlined)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              first.groupDisplayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (first.semester != null)
                              Text(
                                '${first.semester}.º semestre',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    groupAssignments.length == 1
                        ? 'Materia asignada'
                        : 'Materias asignadas',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final assignment in groupAssignments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_outlined, size: 17),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(child: Text(assignment.subjectDisplayName)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TeacherScheduleView extends StatelessWidget {
  const _TeacherScheduleView({
    required this.assignments,
    required this.onRefresh,
  });

  final List<TeacherAssignment> assignments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final sessions = <_TeacherScheduledSession>[];

    for (final assignment in assignments) {
      for (final session in assignment.sessions) {
        sessions.add(
          _TeacherScheduledSession(assignment: assignment, session: session),
        );
      }
    }

    sessions.sort((a, b) {
      final weekdayComparison = a.session.weekday.compareTo(b.session.weekday);

      if (weekdayComparison != 0) {
        return weekdayComparison;
      }

      return a.session.startsAt.compareTo(b.session.startsAt);
    });

    if (sessions.isEmpty) {
      return _TeacherStateMessage(
        icon: Icons.calendar_month_outlined,
        title: 'Sin horario registrado',
        description:
            'Tus asignaciones todavía no tienen sesiones '
            'institucionales registradas.',
        actionLabel: 'Actualizar',
        onAction: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: sessions.length,
        separatorBuilder:
            (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = sessions[index];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(child: Icon(Icons.schedule_outlined)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.session.weekdayLabel,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.assignment.subjectDisplayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(item.session.timeLabel),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _TeacherBadge(
                              icon: Icons.groups_outlined,
                              label: item.assignment.groupDisplayName,
                            ),
                            if (item.session.locationLabel != null)
                              _TeacherBadge(
                                icon: Icons.location_on_outlined,
                                label: item.session.locationLabel!,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TeacherBadge extends StatelessWidget {
  const _TeacherBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherStateMessage extends StatelessWidget {
  const _TeacherStateMessage({
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
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onAction,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xlg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(description, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.tonal(
                        onPressed: onAction,
                        child: Text(actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TeacherScheduledSession {
  const _TeacherScheduledSession({
    required this.assignment,
    required this.session,
  });

  final TeacherAssignment assignment;
  final TeacherAssignmentSession session;
}
