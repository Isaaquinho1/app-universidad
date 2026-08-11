import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/scheduled_class.dart';
import 'package:conecta_itt/academic_planner/repositories/weekly_schedule_repository.dart';
import 'package:conecta_itt/academic_planner/view/subject_sessions_page.dart';
import 'package:conecta_itt/academic_planner/widgets/conecta_subject_hero.dart';
import 'package:flutter/material.dart';

class WeeklyScheduleView extends StatefulWidget {
  const WeeklyScheduleView({super.key});

  @override
  State<WeeklyScheduleView> createState() => _WeeklyScheduleViewState();
}

class _WeeklyScheduleViewState extends State<WeeklyScheduleView> {
  static const _weekdayLabels = <int, String>{
    DateTime.monday: 'Lunes',
    DateTime.tuesday: 'Martes',
    DateTime.wednesday: 'Miércoles',
    DateTime.thursday: 'Jueves',
    DateTime.friday: 'Viernes',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };

  final WeeklyScheduleRepository _repository = WeeklyScheduleRepository();

  late Future<Map<int, List<ScheduledClass>>> _weekFuture;

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  void _loadWeek() {
    _weekFuture = _repository.getWeek();
  }

  Future<void> _refresh() async {
    setState(_loadWeek);
    await _weekFuture;
  }

  String _formatMinutes(BuildContext context, int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ConectaAtmosphere(
      accent: colors.primary,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<int, List<ScheduledClass>>>(
          future: _weekFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _WeeklyScheduleError(onRetry: _refresh);
            }

            final week = snapshot.data ?? const {};

            final totalClasses = week.values.fold<int>(
              0,
              (total, classes) => total + classes.length,
            );

            if (totalClasses == 0) {
              return const _EmptyWeeklySchedule();
            }

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEMANA',
                        style: AppTextStyle.captionL.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu panorama',
                        style: AppTextStyle.h5.copyWith(
                          color: colors.active,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$totalClasses '
                        '${totalClasses == 1 ? 'sesión' : 'sesiones'} '
                        'programadas',
                        style: AppTextStyle.body.copyWith(
                          color: colors.deactive,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xlg),
                SizedBox(
                  height: 560,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 8,
                    ),
                    itemCount: DateTime.daysPerWeek,
                    separatorBuilder:
                        (context, index) =>
                            const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final weekday = index + 1;
                      final classes = week[weekday] ?? const <ScheduledClass>[];

                      return ConectaEntrance(
                        index: index + 1,
                        offset: const Offset(0.035, 0),
                        child: _WeekdayColumn(
                          weekday: weekday,
                          label: _weekdayLabels[weekday] ?? 'Día',
                          classes: classes,
                          formatMinutes:
                              (minutes) => _formatMinutes(context, minutes),
                          onClassTap: (item) async {
                            await Navigator.of(context).push(
                              PageRouteBuilder<void>(
                                transitionDuration:
                                    ConectaMotion.sharedTransition,
                                reverseTransitionDuration:
                                    ConectaMotion.emphasized,
                                pageBuilder: (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                ) {
                                  return SubjectSessionsPage(
                                    subject: item.subject,
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

                                  return FadeTransition(
                                    opacity: curved,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: 0.985,
                                        end: 1,
                                      ).animate(curved),
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
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeekdayColumn extends StatelessWidget {
  const _WeekdayColumn({
    required this.weekday,
    required this.label,
    required this.classes,
    required this.formatMinutes,
    required this.onClassTap,
  });

  final int weekday;
  final String label;
  final List<ScheduledClass> classes;
  final String Function(int) formatMinutes;
  final ValueChanged<ScheduledClass> onClassTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isToday = DateTime.now().weekday == weekday;

    return ConectaInteractiveSurface(
      haptics: false,
      restingScale: isToday ? 1.01 : 0.985,
      restingOffset: isToday ? const Offset(0, -3) : const Offset(0, 1.5),
      pressedScale: isToday ? 0.99 : 0.965,
      child: ConectaSurface(
        level:
            isToday ? ConectaSurfaceLevel.focused : ConectaSurfaceLevel.raised,
        accent: colors.primary,
        borderRadius: BorderRadius.circular(ConectaRadius.floating),
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: isToday ? 260 : 238,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color:
                      isToday
                          ? colors.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(ConectaRadius.floating),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.toUpperCase(),
                            style: AppTextStyle.captionL.copyWith(
                              color: isToday ? colors.primary : colors.deactive,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${classes.length} '
                            '${classes.length == 1 ? 'clase' : 'clases'}',
                            style: AppTextStyle.bodyBold.copyWith(
                              color: colors.active,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(
                            ConectaRadius.pill,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'HOY',
                          style: AppTextStyle.captionS.copyWith(
                            color: colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child:
                    classes.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_available_outlined,
                                  size: 30,
                                  color: colors.deactive,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Sin clases',
                                  style: AppTextStyle.body.copyWith(
                                    color: colors.deactive,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: classes.length,
                          separatorBuilder:
                              (context, index) =>
                                  const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final item = classes[index];

                            return ConectaEntrance(
                              index: index + 1,
                              child: _WeeklyClassCard(
                                item: item,
                                startLabel: formatMinutes(item.startMinutes),
                                endLabel: formatMinutes(item.endMinutes),
                                onTap: () => onClassTap(item),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyClassCard extends StatelessWidget {
  const _WeeklyClassCard({
    required this.item,
    required this.startLabel,
    required this.endLabel,
    required this.onTap,
  });

  final ScheduledClass item;
  final String startLabel;
  final String endLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final subjectColor = Color(item.subject.colorValue);

    final location = [
      item.session.building,
      item.session.room,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    return ConectaInteractiveSurface(
      onTap: onTap,
      pressedScale: 0.965,
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
                subtitle: '$startLabel – $endLabel',
              ),
            ),
          );
        },
        child: ConectaSurface(
          level: ConectaSurfaceLevel.base,
          accent: subjectColor,
          borderRadius: BorderRadius.circular(ConectaRadius.control),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 82,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(ConectaRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: subjectColor.withValues(alpha: 0.22),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.bodyBold.copyWith(
                        fontSize: 14,
                        color: colors.active,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$startLabel – $endLabel',
                      style: AppTextStyle.captionL.copyWith(
                        color: subjectColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: colors.deactive,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.captionS.copyWith(
                                color: colors.deactive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _EmptyWeeklySchedule extends StatelessWidget {
  const _EmptyWeeklySchedule();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xlg),
      children: [
        const SizedBox(height: 72),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xlg),
          decoration: BoxDecoration(
            color: colors.background02,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.deactive.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              const Icon(Icons.calendar_view_week_rounded, size: 52),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Tu semana está vacía',
                style: AppTextStyle.h4.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Agrega sesiones desde la sección Materias '
                'para construir tu horario semanal.',
                textAlign: TextAlign.center,
                style: AppTextStyle.body.copyWith(color: colors.deactive),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyScheduleError extends StatelessWidget {
  const _WeeklyScheduleError({required this.onRetry});

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
