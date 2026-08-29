import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/scheduled_class.dart';
import 'package:conecta_itt/academic_planner/repositories/daily_schedule_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/weekly_schedule_repository.dart';
import 'package:conecta_itt/academic_planner/services/weekly_schedule_image_exporter.dart';
import 'package:conecta_itt/academic_planner/view/subject_sessions_page.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
  final WeeklyScheduleRepository _weeklyRepository = WeeklyScheduleRepository();
  final WeeklyScheduleImageExporter _imageExporter =
      const WeeklyScheduleImageExporter();

  bool _isExportingImage = false;

  late int _selectedWeekday;
  late Future<List<ScheduledClass>> _classesFuture;

  @override
  void initState() {
    super.initState();
    _selectedWeekday = DateTime.now().weekday;
    _loadClasses();
  }

  void _loadClasses() {
    _classesFuture = _repository.getByWeekday(_selectedWeekday);
  }

  Future<void> _exportScheduleImage(BuildContext context) async {
    if (_isExportingImage) {
      return;
    }

    setState(() {
      _isExportingImage = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);

    final materialLocalizations = MaterialLocalizations.of(context);
    final alwaysUse24HourFormat = MediaQuery.alwaysUse24HourFormatOf(context);

    String formatMinutes(int minutes) {
      return materialLocalizations.formatTimeOfDay(
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        alwaysUse24HourFormat: alwaysUse24HourFormat,
      );
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin =
        renderBox == null
            ? null
            : renderBox.localToGlobal(Offset.zero) & renderBox.size;

    try {
      final week = await _weeklyRepository.getWeek();

      final totalClasses = week.values.fold<int>(
        0,
        (total, classes) => total + classes.length,
      );

      if (!mounted) {
        return;
      }

      if (totalClasses == 0) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Agrega clases antes de exportar tu horario.'),
          ),
        );
        return;
      }

      final file = await _imageExporter.export(
        week: week,
        formatMinutes: formatMinutes,
      );

      if (!mounted) {
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('=== ERROR: EXPORTAR HORARIO COMO PNG ===');
      debugPrint('Tipo: ${error.runtimeType}');
      debugPrint('Error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No fue posible generar la imagen del horario.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingImage = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(_loadClasses);
    await _classesFuture;
  }

  void _selectWeekday(int weekday) {
    if (_selectedWeekday == weekday) return;

    setState(() {
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ScheduledClass>>(
        future: _classesFuture,
        builder: (context, snapshot) {
          final classes = snapshot.data ?? const <ScheduledClass>[];

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _DaySelector(
                selectedWeekday: _selectedWeekday,
                weekdayLabels: _shortWeekdayLabels,
                onSelected: _selectWeekday,
              ),
              const SizedBox(height: AppSpacing.xlg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateLabel(),
                      style: AppTextStyle.h4.copyWith(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Exportar horario como PNG',
                    onPressed:
                        _isExportingImage
                            ? null
                            : () => _exportScheduleImage(context),
                    icon:
                        _isExportingImage
                            ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.image_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                classes.isEmpty
                    ? 'No tienes clases programadas'
                    : '${classes.length} ${classes.length == 1 ? 'clase' : 'clases'} programadas',
                style: AppTextStyle.body.copyWith(
                  color: Theme.of(context).extension<AppColors>()!.deactive,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 72),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _DailyScheduleError(onRetry: _refresh)
              else if (classes.isEmpty)
                const _EmptyDailySchedule()
              else
                for (var index = 0; index < classes.length; index++) ...[
                  if (index > 0)
                    _FreeTimeIndicator(
                      previous: classes[index - 1],
                      current: classes[index],
                    ),
                  _DailyClassCard(
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
                        MaterialPageRoute<void>(
                          builder:
                              (_) => SubjectSessionsPage(
                                subject: classes[index].subject,
                              ),
                        ),
                      );

                      if (mounted) {
                        await _refresh();
                      }
                    },
                  ),
                  if (index < classes.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
            ],
          );
        },
      ),
    );
  }
}

enum _ClassTemporalStatus { scheduled, upcoming, inProgress, finished }

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

    return Row(
      children: [
        for (final entry in weekdayLabels.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onSelected(entry.key),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        selectedWeekday == entry.key
                            ? Theme.of(context).colorScheme.primary
                            : colors.background02,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          selectedWeekday == entry.key
                              ? Colors.transparent
                              : colors.deactive.withValues(alpha: 0.16),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.value,
                    style: AppTextStyle.bodyBold.copyWith(
                      color:
                          selectedWeekday == entry.key
                              ? Colors.white
                              : colors.active,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.background02,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color:
              status == _ClassTemporalStatus.inProgress
                  ? subjectColor
                  : colors.deactive.withValues(alpha: 0.18),
          width: status == _ClassTemporalStatus.inProgress ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 104,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.subject.name,
                            style: AppTextStyle.bodyBold.copyWith(
                              fontSize: 17,
                              color:
                                  status == _ClassTemporalStatus.finished
                                      ? colors.deactive
                                      : colors.active,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: subjectColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusLabel,
                            style: AppTextStyle.body.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: subjectColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$startLabel – $endLabel',
                      style: AppTextStyle.body.copyWith(
                        color: subjectColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.subject.teacherName != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        text: item.subject.teacherName!,
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: location,
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
        const SizedBox(width: 5),
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
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '${parts.join(' ')} libres',
              style: AppTextStyle.body.copyWith(
                fontSize: 12,
                color: Theme.of(context).extension<AppColors>()!.deactive,
              ),
            ),
          ),
          const Expanded(child: Divider()),
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xlg),
      decoration: BoxDecoration(
        color: colors.background02,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.deactive.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded, size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Día libre',
            style: AppTextStyle.h4.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
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
