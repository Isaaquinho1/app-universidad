import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:app_ui/app_ui.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:rtu_mirea_app/schedule/bloc/schedule_bloc.dart';
import 'package:rtu_mirea_app/schedule/models/custom_schedule.dart';
import 'package:rtu_mirea_app/schedule/view/custom_lesson_editor_page.dart';
import 'package:rtu_mirea_app/schedule/widgets/lesson_card.dart';
import 'package:university_app_server_api/client.dart';

class CustomSchedulesPage extends StatefulWidget {
  const CustomSchedulesPage({super.key});

  @override
  State<CustomSchedulesPage> createState() => _CustomSchedulesPageState();
}

class _CustomSchedulesPageState extends State<CustomSchedulesPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis horarios')),
      body: BlocBuilder<ScheduleBloc, ScheduleState>(
        builder: (context, state) {
          if (state.customSchedules.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: colors.background02,
                          borderRadius: BorderRadius.circular(AppSpacing.lg),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _showCreateScheduleDialog(),
                                icon: const  HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 20, color: Colors.grey),
                                label: const Text('Crear horario'),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.primary,
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.lg)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            if (state.customSchedules.isNotEmpty) ...[
                              Container(height: 24, width: 1, color: colors.background03),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () => _addCustomLesson(state.customSchedules.first.id),
                                  icon: const  HugeIcon(icon: HugeIcons.strokeRoundedNotebook01, size: 20, color: Colors.grey),
                                  label: const Text('Agregar clase'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.colorful07,
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.lg)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Schedule list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    ...state.customSchedules.map(
                      (schedule) => _buildScheduleCard(
                        schedule,
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return FailureScreen(
      icon: HugeIcons.strokeRoundedCalendar01,
      title: 'Aún no tienes horarios propios',
      description: 'Crea tu propio horario agregando clases de distintos horarios disponibles',
      buttonText: 'Crear horario',
      buttonIcon: HugeIcons.strokeRoundedAdd01,
      onButtonPressed: () => _showCreateScheduleDialog(),
    );
  }

  Widget _buildScheduleCard(CustomSchedule schedule) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final updatedAt = schedule.updatedAt != null ? formatter.format(schedule.updatedAt!) : 'Fecha desconocida';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        side: BorderSide(color: colors.background03.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => _selectCustomSchedule(schedule),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.lg)),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.background03.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.lg)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: colors.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(child:  HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 24, color: colors.primary)),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(schedule.name, style: AppTextStyle.titleM.copyWith(fontWeight: FontWeight.w600)),
                        if (schedule.description != null && schedule.description!.isNotEmpty)
                          Text(
                            schedule.description!,
                            style: AppTextStyle.body.copyWith(color: colors.deactive),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showScheduleOptions(schedule)),
                ],
              ),
            ),
          ),

          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                _buildStatistic(context, '${schedule.lessons.length}', 'clases', HugeIcons.strokeRoundedNotebook01),
                const SizedBox(width: AppSpacing.xlg),
                Expanded(
                  child: Text(
                    'Actualizado: $updatedAt',
                    style: AppTextStyle.captionL.copyWith(color: colors.deactive),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: colors.background03),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
                    ),
                    onPressed: () => _showScheduleLessons(schedule),
                    icon: const  HugeIcon(icon: HugeIcons.strokeRoundedListView, size: 18, color: Colors.grey),
                    label: const Text('Lista de clases'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: AppSpacing.lg),
                    side: BorderSide(color: colors.colorful07.withOpacity(0.5)),
                    foregroundColor: colors.colorful07,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
                  ),
                  onPressed: () => _addCustomLesson(schedule.id),
                  icon: const  HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 18, color: Colors.grey),
                  label: const Text('Clase'),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: AppSpacing.lg),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
                  ),
                  onPressed: () => _selectCustomSchedule(schedule),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Abrir'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistic(BuildContext context, String value, String label, dynamic icon) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.background03.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Center(child: Icon(icon, size: 18, color: colors.deactive)),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTextStyle.titleS.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: AppTextStyle.captionL.copyWith(color: colors.deactive)),
          ],
        ),
      ],
    );
  }

  void _showCreateScheduleDialog() {
    _nameController.clear();
    _descriptionController.clear();

    BottomModalSheet.show(
      context,
      title: 'Crear horario',
      description: 'Ingresa el nombre y la descripción del nuevo horario',
      isDismissible: true,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextInput(
              controller: _nameController,
              labelText: 'Nombre del horario',
              hintText: 'Ejemplo: Mi horario',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa el nombre';
                }
                if (value.length > 50) {
                  return 'El nombre es demasiado largo';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextInput(
              controller: _descriptionController,
              labelText: 'Descripción opcional',
              hintText: 'Agrega una descripción del horario',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xlg),
            PrimaryButton(
              text: 'Crear horario',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  context.read<ScheduleBloc>().add(
                    CreateCustomSchedule(
                      name: _nameController.text.trim(),
                      description: _descriptionController.text.trim(),
                    ),
                  );

                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleOptions(CustomSchedule schedule) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(schedule);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Eliminar'),
                  textColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(schedule);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showEditDialog(CustomSchedule schedule) {
    _nameController.text = schedule.name;
    _descriptionController.text = schedule.description ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Editar horario'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextInput(
                    controller: _nameController,
                    labelText: 'Nombre del horario',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa el nombre';
                      }
                      if (value.length > 50) {
                        return 'El nombre es demasiado largo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextInput(
                    controller: _descriptionController,
                    labelText: 'Descripción opcional',
                    hintText: 'Agrega una descripción del horario',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    context.read<ScheduleBloc>().add(
                      UpdateCustomSchedule(
                        schedule: schedule.copyWith(
                          name: _nameController.text.trim(),
                          description:
                              _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
                          updatedAt: DateTime.now(),
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmation(CustomSchedule schedule) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar horario'),
            content: Text('¿Seguro que deseas eliminar el horario "${schedule.name}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  context.read<ScheduleBloc>().add(DeleteCustomSchedule(scheduleId: schedule.id));
                  Navigator.pop(context);
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  void _showScheduleLessons(CustomSchedule schedule) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final controller = ScrollController();

    final content = Column(
      children: [
        // Botón para agregar clases
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _addCustomLesson(schedule.id);
            },
            icon: const  HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.grey),
            label: const Text('Crear nueva clase'),
          ),
        ),

        Expanded(
          child:
              schedule.lessons.isEmpty
                  ? Center(
                    child: Text('No hay clases agregadas', style: AppTextStyle.body.copyWith(color: colors.deactive)),
                  )
                  : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: schedule.lessons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final lesson = schedule.lessons[index];
                      return _buildLessonListItem(schedule.id, lesson);
                    },
                  ),
        ),
      ],
    );

    BottomModalSheet.show(
      context,
      title: 'Lista de clases',
      description: 'Puedes agregar una nueva clase al horario ${schedule.name}',
      isDismissible: true,
      child: content,
    );
  }

  Widget _buildLessonListItem(String scheduleId, LessonSchedulePart lesson) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final lessonColor = LessonCard.getColorByType(lesson.lessonType);

    return Container(
      decoration: BoxDecoration(
        color: colors.background02,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: colors.background03.withOpacity(0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: lessonColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSpacing.md),
                  bottomLeft: Radius.circular(AppSpacing.md),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _editLesson(scheduleId, lesson),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.subject, style: AppTextStyle.titleS.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _buildLessonInfoChip(
                            context,
                            LessonCard.getLessonTypeName(lesson.lessonType),
                            lessonColor,
                            icon: HugeIcons.strokeRoundedNotebook01,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _buildLessonInfoChip(
                            context,
                            '${lesson.lessonBells.startTime} - ${lesson.lessonBells.endTime}',
                            colors.colorful01,
                            icon: HugeIcons.strokeRoundedClock01,
                          ),
                        ],
                      ),
                      if (lesson.classrooms.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Aula: ${lesson.classrooms.map((e) => e.name).join(", ")}',
                          style: AppTextStyle.captionL.copyWith(color: colors.deactive),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmRemoveLesson(scheduleId, lesson),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(AppSpacing.md),
                  bottomRight: Radius.circular(AppSpacing.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Icon(Icons.delete, color: colors.deactive),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonInfoChip(BuildContext context, String text, Color color, {dynamic icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppSpacing.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: AppSpacing.xs)],
          Text(text, style: AppTextStyle.captionS.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmRemoveLesson(String scheduleId, LessonSchedulePart lesson) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminación de clase'),
            content: Text('¿Seguro que deseas eliminar la clase "${lesson.subject}" del horario?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  context.read<ScheduleBloc>().add(
                    RemoveLessonFromCustomSchedule(scheduleId: scheduleId, lesson: lesson),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  void _selectCustomSchedule(CustomSchedule schedule) {
    final bloc = context.read<ScheduleBloc>();
    bloc.add(SelectCustomSchedule(scheduleId: schedule.id));
    context.go('/schedule');
  }

  void _addCustomLesson(String scheduleId) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CustomLessonEditorPage(scheduleId: scheduleId)));
  }

  void _editLesson(String scheduleId, LessonSchedulePart lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CustomLessonEditorPage(scheduleId: scheduleId, lesson: lesson)),
    );
  }
}
