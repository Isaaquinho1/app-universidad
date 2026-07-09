import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_ui/app_ui.dart';
import 'package:rtu_mirea_app/rating_system_calculator/bloc/rating_system_bloc.dart';
import 'package:rtu_mirea_app/rating_system_calculator/models/models.dart';
import 'package:rtu_mirea_app/rating_system_calculator/widgets/widgets.dart';
import 'package:rtu_mirea_app/schedule/bloc/schedule_bloc.dart';
import 'package:rtu_mirea_app/schedule/models/models.dart';
import 'package:university_app_server_api/client.dart';

class RatingSystemCalculatorPage extends StatelessWidget {
  const RatingSystemCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark.background01,
      appBar: AppBar(
        backgroundColor: AppColors.dark.background01,
        elevation: 0,
        title: const Text("Sistema de evaluación por puntos"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocProvider(create: (context) => RatingSystemBloc(), child: const RatingSystemCalculatorView()),
      ),
    );
  }
}

class RatingSystemCalculatorView extends StatefulWidget {
  const RatingSystemCalculatorView({super.key});

  @override
  State<RatingSystemCalculatorView> createState() => _RatingSystemCalculatorViewState();
}

class _RatingSystemCalculatorViewState extends State<RatingSystemCalculatorView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  (String, List<Subject>)? _getSubjectsByCurrentScheduleState(ScheduleBloc scheduleBloc) {
    final selectedSchedule = scheduleBloc.state.selectedSchedule;

    if (selectedSchedule is SelectedGroupSchedule) {
      final subjectNames = selectedSchedule.schedule.whereType<LessonSchedulePart>().map((e) => e.subject).toSet();

      final selectedGroup = selectedSchedule.group.name;

      List<DateTime> getDatesBySubjectName(String subjectName) {
        return selectedSchedule.schedule
            .whereType<LessonSchedulePart>()
            .where((e) => e.subject == subjectName)
            .map((e) => e.dates)
            .expand((element) => element)
            .toList();
      }

      return (selectedGroup, subjectNames.map((e) => Subject(name: e, dates: getDatesBySubjectName(e))).toList());
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleBloc = context.watch<ScheduleBloc>();
    final ratingSystemBloc = context.watch<RatingSystemBloc>();

    final subjects = _getSubjectsByCurrentScheduleState(scheduleBloc);

    if (subjects != null) {
      ratingSystemBloc.add(UpdateSubjectsByCurrentSchedule(group: subjects.$1, subjects: subjects.$2));
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            Container(
              decoration: ShapeDecoration(
                gradient: const LinearGradient(
                  stops: [0.1, 0.3, 0.7, 0.9],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF85FF99), Color(0xFF87BFFB), Color(0xFFBD9DFE), Color(0xFFFFB8DF)],
                  transform: GradientRotation(0.5 * 3.14),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sistema de evaluación por puntos",
                    style: AppTextStyle.titleM.copyWith(
                      color: AppColors.dark.activeLightMode,
                      fontWeight: FontWeight.w700,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "📖  Entra para conocer cómo funciona",
                          style: AppTextStyle.bodyL.copyWith(color: AppColors.dark.activeLightMode, fontSize: 16),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: "Más información",
                    onPressed: () {
                      context.go('/services/rating-system-calculator/about');
                    },
                  ),
                ],
              ),
            ).animate().slideX(duration: 400.ms, begin: -1.5, end: 0),
            const SizedBox(height: 32),
            const SubjectsListView(),
          ]),
        ),
      ],
    );
  }
}

class SubjectsListView extends StatelessWidget {
  const SubjectsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedSchedule = context.watch<ScheduleBloc>().state.selectedSchedule;

    if (selectedSchedule is SelectedGroupSchedule) {
      return BlocBuilder<RatingSystemBloc, RatingSystemState>(
        builder: (context, state) {
          return Column(
            children:
                state.subjects
                    .map(
                      (e) => SubjectCard(
                        subject: e.$2,
                        onTap: (subject) {
                          context.go('/services/rating-system-calculator/subject', extra: subject);
                        },
                      ),
                    )
                    .toList(),
          );
        },
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("No tienes seleccionado un horario de grupo", style: AppTextStyle.titleM),
            const SizedBox(height: 16),
            Text("Selecciona un horario para mostrar tus materias", style: AppTextStyle.body),
            const SizedBox(height: 24),
            TextOutlinedButton(
              content: "Seleccionar horario",
              onPressed: () {
                context.go('/schedule');
              },
            ),
          ],
        ),
      );
    }
  }
}
