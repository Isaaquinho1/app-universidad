import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/scheduled_class.dart';
import 'package:conecta_itt/academic_planner/repositories/daily_schedule_repository.dart';
import 'package:conecta_itt/academic_planner/view/subject_sessions_page.dart';
import 'package:conecta_itt/academic_planner/widgets/conecta_subject_hero.dart';
import 'package:flutter/material.dart';

class DailyScheduleView extends StatefulWidget {
  const DailyScheduleView({super.key});

  @override
  State<DailyScheduleView> createState() => _DailyScheduleViewState();
}

class _DailyScheduleViewState extends State<DailyScheduleView> {
  static const _weekdayLabels = <int, String>{
    DateTime.monday: 'Lunes',
    DateTime.tuesday: 'Martes',
    DateTime.wednesday: 'Miércoles',
    DateTime.thursday: 'Jueves',
    DateTime.friday: 'Viernes',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };

  static const _shortWeekdayLabels = <int, String>{
    DateTime.monday: 'L',
    DateTime.tuesday: 'M',
    DateTime.wednesday: 'M',
    DateTime.thursday: 'J',
    DateTime.friday: 'V',
    DateTime.saturday: 'S',
    DateTime.sunday: 'D',
  };

  final DailyScheduleRepository _repository = DailyScheduleRepository();

  late int _selectedWeekday;
  late Future<List<ScheduledClass>> _classesFuture;

  int _dayTransitionDirection = 1;
  int _dayTransitionSequence = 0;

  @override
  void initState() {
    super.initState();
    _selectedWeekday = DateTime.now().weekday;
    _loadClasses();
  }

  void _loadClasses() {
    _classesFuture = _repository.getByWeekday(_selectedWeekday);
  }

  Future<void> _refresh() async {
    setState(_loadClasses);
    await _classesFuture;
  }

  void _selectWeekday(int weekday) {
    if (_selectedWeekday == weekday) {
      return;
    }

    final direction = weekday > _selectedWeekday ? 1 : -1;

    setState(() {
      _dayTransitionDirection = direction;
      _dayTransitionSequence++;
      _selectedWeekday = weekday;
      _loadClasses();
    });
  }

  int get _currentMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  _ClassTemporalStatus _statusFor(ScheduledClass item) {
    final today = DateTime.now().weekday;

    if (_selectedWeekday != today) {
      return _ClassTemporalStatus.scheduled;
    }

    final minutes = _currentMinutes;

    if (minutes >= item.startMinutes && minutes < item.endMinutes) {
      return _ClassTemporalStatus.inProgress;
    }

    if (minutes < item.startMinutes) {
      return _ClassTemporalStatus.upcoming;
    }

    return _ClassTemporalStatus.finished;
  }

  String _formatMinutes(BuildContext context, int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
  }

  String _dateLabel() {
    final now = DateTime.now();

    if (_selectedWeekday == now.weekday) {
      return 'Hoy';
    }

    return _weekdayLabels[_selectedWeekday] ?? 'Día';
  }

  String _scheduleSummary(List<ScheduledClass> classes) {
    if (classes.isEmpty) {
      return 'No tienes clases programadas';
    }

    if (classes.length == 1) {
      return '1 clase programada';
    }

    return '${classes.length} clases programadas';
  }

  Widget _buildDayContent(
    BuildContext context,
    AsyncSnapshot<List<ScheduledClass>> snapshot,
  ) {
    final classes = snapshot.data ?? const <ScheduledClass>[];

    return AnimatedSwitcher(
      duration: ConectaMotion.emphasized,
      switchInCurve: ConectaCurves.emphasized,
      switchOutCurve: ConectaCurves.exit,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: ConectaCurves.emphasized,
          reverseCurve: ConectaCurves.exit,
        );

        final offsetAnimation = Tween<Offset>(
          begin: Offset(0.055 * _dayTransitionDirection, 0),
          end: Offset.zero,
        ).animate(curvedAnimation);

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_dayTransitionSequence),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConectaEntrance(
              index: 1,
              child: _ScheduleHeader(
                title: _dateLabel(),
                summary: _scheduleSummary(classes),
                classes: classes,
              ),
            ),
            const SizedBox(height: AppSpacing.xlg),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _DailyScheduleError(onRetry: _refresh)
            else if (classes.isEmpty)
              const ConectaEntrance(index: 2, child: _EmptyDailySchedule())
            else
              for (var index = 0; index < classes.length; index++) ...[
                if (index > 0)
                  ConectaEntrance(
                    index: index + 2,
                    child: _FreeTimeIndicator(
                      previous: classes[index - 1],
                      current: classes[index],
                    ),
                  ),
                ConectaEntrance(
                  index: index + 2,
                  child: _DailyClassCard(
                    item: classes[index],
                    status: _statusFor(classes[index]),
                    startLabel: _formatMinutes(
                      context,
                      classes[index].startMinutes,
                    ),
                    endLabel: _formatMinutes(
                      context,
                      classes[index].endMinutes,
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        PageRouteBuilder<void>(
                          transitionDuration: ConectaMotion.sharedTransition,
                          reverseTransitionDuration: ConectaMotion.emphasized,
                          pageBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                          ) {
                            return SubjectSessionsPage(
                              subject: classes[index].subject,
                            );
                          },
                          transitionsBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: ConectaCurves.emphasized,
                              reverseCurve: ConectaCurves.exit,
                            );

                            final scale = Tween<double>(
                              begin: 0.985,
                              end: 1,
                            ).animate(curved);

                            return FadeTransition(
                              opacity: curved,
                              child: ScaleTransition(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                        ),
                      );

                      if (mounted) {
                        await _refresh();
                      }
                    },
                  ),
                ),
                if (index < classes.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ConectaAtmosphere(
      accent: colors.primary,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ScheduledClass>>(
          future: _classesFuture,
          builder: (context, snapshot) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                ConectaEntrance(
                  child: _DaySelector(
                    selectedWeekday: _selectedWeekday,
                    weekdayLabels: _shortWeekdayLabels,
                    onSelected: _selectWeekday,
                  ),
                ),
                const SizedBox(height: AppSpacing.xlg),
                _buildDayContent(context, snapshot),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _ClassTemporalStatus { scheduled, upcoming, inProgress, finished }

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({
    required this.title,
    required this.summary,
    required this.classes,
  });

  final String title;
  final String summary;
  final List<ScheduledClass> classes;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final nextClass = classes.isEmpty ? null : classes.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppTextStyle.captionL.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu horario',
                    style: AppTextStyle.h5.copyWith(
                      color: colors.active,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          summary,
          style: AppTextStyle.body.copyWith(color: colors.deactive),
        ),
        if (nextClass != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _SchedulePulse(item: nextClass),
        ],
      ],
    );
  }
}

class _SchedulePulse extends StatelessWidget {
  const _SchedulePulse({required this.item});

  final ScheduledClass item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final subjectColor = Color(item.subject.colorValue);

    return ConectaSurface(
      level: ConectaSurfaceLevel.base,
      borderRadius: BorderRadius.circular(ConectaRadius.control),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: subjectColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: subjectColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              item.subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.bodyBold.copyWith(
                color: colors.active,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.arrow_forward_rounded, size: 17, color: colors.deactive),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedWeekday,
    required this.weekdayLabels,
    required this.onSelected,
  });

  final int selectedWeekday;
  final Map<int, String> weekdayLabels;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final today = DateTime.now().weekday;

    return ConectaSurface(
      level: ConectaSurfaceLevel.raised,
      borderRadius: BorderRadius.circular(ConectaRadius.floating),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (final entry in weekdayLabels.entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ConectaInteractiveSurface(
                  haptics: false,
                  pressedScale: 0.94,
                  onTap: () => onSelected(entry.key),
                  child: AnimatedContainer(
                    duration: ConectaMotion.standard,
                    curve: ConectaCurves.emphasized,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          selectedWeekday == entry.key
                              ? colors.primary
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        ConectaRadius.control,
                      ),
                      boxShadow:
                          selectedWeekday == entry.key
                              ? [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.22),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                              : const [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          entry.value,
                          style: AppTextStyle.bodyBold.copyWith(
                            color:
                                selectedWeekday == entry.key
                                    ? colors.white
                                    : colors.active,
                          ),
                        ),
                        if (entry.key == today)
                          Positioned(
                            bottom: 6,
                            child: AnimatedContainer(
                              duration: ConectaMotion.standard,
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    selectedWeekday == entry.key
                                        ? colors.white.withValues(alpha: 0.8)
                                        : colors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyClassCard extends StatelessWidget {
  const _DailyClassCard({
    required this.item,
    required this.status,
    required this.startLabel,
    required this.endLabel,
    required this.onTap,
  });

  final ScheduledClass item;
  final _ClassTemporalStatus status;
  final String startLabel;
  final String endLabel;
  final VoidCallback onTap;

  String get _statusLabel {
    return switch (status) {
      _ClassTemporalStatus.inProgress => 'En curso',
      _ClassTemporalStatus.upcoming => 'Próxima',
      _ClassTemporalStatus.finished => 'Finalizada',
      _ClassTemporalStatus.scheduled => 'Programada',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final subjectColor = Color(item.subject.colorValue);

    final location = [
      item.session.building,
      item.session.room,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    final isFocused = status == _ClassTemporalStatus.inProgress;
    final isFinished = status == _ClassTemporalStatus.finished;

    return ConectaInteractiveSurface(
      onTap: onTap,
      restingScale: isFocused ? 1.008 : 1,
      restingOffset: isFocused ? const Offset(0, -1.5) : Offset.zero,
      child: Hero(
        tag: 'academic-subject-${item.subject.id}',
        transitionOnUserGestures: true,
        createRectTween: (begin, end) {
          return MaterialRectArcTween(begin: begin, end: end);
        },
        flightShuttleBuilder: (
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.94, curve: Curves.easeOutCubic),
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: ConectaCurves.emphasized,
                ),
              ),
              child: ConectaSubjectHero(
                subject: item.subject,
                color: subjectColor,
                compact: flightDirection == HeroFlightDirection.pop,
                subtitle: _statusLabel,
              ),
            ),
          );
        },
        child: ConectaSurface(
          level:
              isFocused
                  ? ConectaSurfaceLevel.focused
                  : ConectaSurfaceLevel.raised,
          accent: subjectColor,
          borderRadius: BorderRadius.circular(ConectaRadius.card),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TemporalRail(color: subjectColor, status: status),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.subject.name,
                            style: AppTextStyle.titleM.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color:
                                  isFinished ? colors.deactive : colors.active,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusPill(
                          label: _statusLabel,
                          color: subjectColor,
                          emphasized: isFocused,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: subjectColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$startLabel – $endLabel',
                          style: AppTextStyle.bodyBold.copyWith(
                            color: subjectColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (item.subject.teacherName != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        text: item.subject.teacherName!,
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: location,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text(
                          'Ver materia',
                          style: AppTextStyle.captionL.copyWith(
                            color: colors.deactive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 15,
                          color: colors.deactive,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemporalRail extends StatelessWidget {
  const _TemporalRail({required this.color, required this.status});

  final Color color;
  final _ClassTemporalStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status == _ClassTemporalStatus.inProgress;

    return Container(
      width: 7,
      height: 122,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConectaRadius.pill),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: active ? 0.45 : 0.18)],
        ),
        boxShadow:
            active
                ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
                : null,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.emphasized,
  });

  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.17 : 0.1),
        borderRadius: BorderRadius.circular(ConectaRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: emphasized ? 0.25 : 0.12),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyle.captionS.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        Icon(icon, size: 17, color: colors.deactive),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.body.copyWith(color: colors.deactive),
          ),
        ),
      ],
    );
  }
}

class _FreeTimeIndicator extends StatelessWidget {
  const _FreeTimeIndicator({required this.previous, required this.current});

  final ScheduledClass previous;
  final ScheduledClass current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final gap = current.startMinutes - previous.endMinutes;

    if (gap <= 0) {
      return const SizedBox(height: AppSpacing.md);
    }

    final hours = gap ~/ 60;
    final minutes = gap % 60;

    final parts = <String>[
      if (hours > 0) '$hours h',
      if (minutes > 0) '$minutes min',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: colors.divider.withValues(alpha: 0.55),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.timelapse_rounded, size: 14, color: colors.deactive),
                const SizedBox(width: 5),
                Text(
                  '${parts.join(' ')} libres',
                  style: AppTextStyle.captionL.copyWith(color: colors.deactive),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: colors.divider.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDailySchedule extends StatelessWidget {
  const _EmptyDailySchedule();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ConectaSurface(
      level: ConectaSurfaceLevel.raised,
      borderRadius: BorderRadius.circular(ConectaRadius.floating),
      padding: const EdgeInsets.all(AppSpacing.xlg),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.09),
            ),
            child: Icon(
              Icons.event_available_rounded,
              size: 32,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Día libre',
            style: AppTextStyle.h6.copyWith(
              color: colors.active,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No tienes sesiones de clase registradas para este día.',
            textAlign: TextAlign.center,
            style: AppTextStyle.body.copyWith(color: colors.deactive),
          ),
        ],
      ),
    );
  }
}

class _DailyScheduleError extends StatelessWidget {
  const _DailyScheduleError({required this.onRetry});

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
