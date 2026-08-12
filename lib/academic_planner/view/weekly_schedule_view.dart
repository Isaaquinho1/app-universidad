import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/scheduled_class.dart';
import 'package:conecta_itt/academic_planner/repositories/weekly_schedule_repository.dart';
import 'package:conecta_itt/academic_planner/services/weekly_schedule_image_exporter.dart';
import 'package:conecta_itt/academic_planner/view/subject_sessions_page.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
  final WeeklyScheduleImageExporter _imageExporter =
      const WeeklyScheduleImageExporter();

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

  String _buildShareText(
    BuildContext context,
    Map<int, List<ScheduledClass>> week,
  ) {
    final buffer =
        StringBuffer()
          ..writeln('Mi horario semanal — Conecta ITT')
          ..writeln();

    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      final classes = week[weekday] ?? const <ScheduledClass>[];

      if (classes.isEmpty) {
        continue;
      }

      buffer
        ..writeln(_weekdayLabels[weekday] ?? 'Día')
        ..writeln();

      for (final item in classes) {
        final location = [
          item.session.building,
          item.session.room,
        ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

        buffer
          ..writeln('• ${item.subject.name}')
          ..writeln(
            '  ${_formatMinutes(context, item.startMinutes)} – '
            '${_formatMinutes(context, item.endMinutes)}',
          );

        if (location.isNotEmpty) {
          buffer.writeln('  $location');
        }

        buffer.writeln();
      }
    }

    buffer.write('Compartido desde Conecta ITT');

    return buffer.toString();
  }

  Future<void> _shareWeek(
    BuildContext context,
    Map<int, List<ScheduledClass>> week,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    await SharePlus.instance.share(
      ShareParams(
        subject: 'Mi horario semanal — Conecta ITT',
        text: _buildShareText(context, week),
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<void> _shareWeekAsImage(
    BuildContext context,
    Map<int, List<ScheduledClass>> week,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final file = await _imageExporter.export(
        week: week,
        formatMinutes: (minutes) => _formatMinutes(context, minutes),
      );

      if (!context.mounted) {
        return;
      }

      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null ? null : box.localToGlobal(Offset.zero) & box.size;

      await SharePlus.instance.share(
        ShareParams(
          subject: 'Mi horario semanal — Conecta ITT',
          text: 'Mi horario semanal — Conecta ITT',
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: origin,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('=== ERROR 11.6B: EXPORTAR HORARIO COMO IMAGEN ===');
      debugPrint('Tipo: ${error.runtimeType}');
      debugPrint('Error: $error');
      debugPrint('StackTrace:');
      debugPrintStack(stackTrace: stackTrace);

      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No fue posible generar la imagen del horario. '
            'Error: ${error.runtimeType}',
          ),
        ),
      );
    }
  }

  Future<void> _showShareOptions(
    BuildContext context,
    Map<int, List<ScheduledClass>> week,
  ) async {
    final option = await showModalBottomSheet<_ScheduleShareOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: const Text('Compartir como texto'),
                  subtitle: const Text(
                    'Ideal para WhatsApp, Mensajes o correo.',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_ScheduleShareOption.text);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Compartir como imagen'),
                  subtitle: const Text(
                    'Genera una tarjeta PNG de tu horario semanal.',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_ScheduleShareOption.image);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || option == null) {
      return;
    }

    switch (option) {
      case _ScheduleShareOption.text:
        await _shareWeek(context, week);
      case _ScheduleShareOption.image:
        await _shareWeekAsImage(context, week);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
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
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Horario semanal',
                      style: AppTextStyle.h4.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (shareContext) {
                      return IconButton(
                        tooltip: 'Compartir horario',
                        onPressed: () => _showShareOptions(shareContext, week),
                        icon: const Icon(Icons.ios_share_rounded),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$totalClasses '
                '${totalClasses == 1 ? 'sesión' : 'sesiones'} '
                'programadas',
                style: AppTextStyle.body.copyWith(
                  color: Theme.of(context).extension<AppColors>()!.deactive,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 540,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: DateTime.daysPerWeek,
                  separatorBuilder:
                      (context, index) => const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final weekday = index + 1;
                    final classes = week[weekday] ?? const <ScheduledClass>[];

                    return _WeekdayColumn(
                      weekday: weekday,
                      label: _weekdayLabels[weekday] ?? 'Día',
                      classes: classes,
                      formatMinutes:
                          (minutes) => _formatMinutes(context, minutes),
                      onClassTap: (item) async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) =>
                                    SubjectSessionsPage(subject: item.subject),
                          ),
                        );

                        if (mounted) {
                          await _refresh();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _ScheduleShareOption { text, image }

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

    return Container(
      width: 245,
      decoration: BoxDecoration(
        color: colors.background02,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isToday
                  ? Theme.of(context).colorScheme.primary
                  : colors.deactive.withValues(alpha: 0.18),
          width: isToday ? 2 : 1,
        ),
      ),
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
                      ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12)
                      : colors.background03,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyle.bodyBold.copyWith(fontSize: 17),
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Hoy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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

                        return _WeeklyClassCard(
                          item: item,
                          startLabel: formatMinutes(item.startMinutes),
                          endLabel: formatMinutes(item.endMinutes),
                          onTap: () => onClassTap(item),
                        );
                      },
                    ),
          ),
        ],
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

    return Material(
      color: subjectColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 76,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(999),
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
                      style: AppTextStyle.bodyBold.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$startLabel – $endLabel',
                      style: AppTextStyle.body.copyWith(
                        fontSize: 12,
                        color: subjectColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 6),
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
                              style: AppTextStyle.body.copyWith(
                                fontSize: 11,
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
